// Duplicate / similar grouping (requirements §7, Phase 2).
//
// Pure functions over assets + cached analyses. Grouping never
// deletes anything: it only suggests a keeper per group, and the
// user may tap any other thumbnail to change it. Deletion still
// flows through review + native confirmation.
//
// Greedy clustering rule: assets are visited in the order given
// (the scan order, newest first). Each asset joins the FIRST group
// whose representative's hash is within [threshold] Hamming distance;
// otherwise it starts a new group as its own representative. The
// representative never changes after a group is created, so results
// are deterministic for a given order and threshold, and regrouping
// from cached hashes is a pure recompute (no thumbnail reload).
// Groups of one are dropped: a photo with no similar partner is not
// a "duplicate group". Assets with no cached analysis have no hash
// and cannot group; they are skipped, never guessed.
//
// Phase 3B performance (requirements §7, 50,000+ photos):
// - BEFORE: the greedy scan compared every asset against every
//   existing representative — O(n * g) where g is the group count,
//   degrading to O(n^2) on a library of mostly-distinct photos
//   (50k distinct photos = ~1.25 billion Hamming comparisons).
// - AFTER, threshold 0 (exact duplicates): hash-bucket
//   pre-grouping. One Map pass buckets assets by (hash, width,
//   height), O(n) total. Phase 5.2 reconciled this with
//   [PhotoAnalysis.isExactDuplicateOf] (hash AND dimensions):
//   before, buckets keyed on hash alone, so two photos sharing a
//   hash but not dimensions grouped as "exact" — they no longer
//   do at threshold 0. They can still group at threshold > 0 as
//   similar (similarity is distance alone, by definition), and
//   the keeper rule below is unchanged. This is the one
//   intentional behaviour change in 5.2, proven by the
//   threshold-0 trust-flow test (same hash, different
//   dimensions, must NOT group at 0).
// - AFTER, threshold > 0 (similar photos): the greedy scan is
//   kept, but representative comparisons per asset are capped at
//   [maxRepresentativeComparisons]. Worst case is O(n * 512)
//   instead of O(n^2). PRECISION TRADE-OFF, stated plainly: a
//   similar partner whose representative sits beyond the cap is
//   missed and the asset starts its own group (a safe split —
//   grouping only ever SUGGESTS a keeper and deletion still flows
//   through review + native confirmation, so no keeper safety or
//   "never auto-delete" rule is traded for speed). Exact-hash
//   grouping (threshold 0) is unaffected by the cap. Corollary
//   worth stating: a pair whose representative sits beyond the
//   cap loses BOTH members as a group (the second member also
//   cannot see its own representative, so both stay singletons
//   and are dropped) — the photos simply stay ungrouped in the
//   library, never wrongly merged and never deleted.
//
// Keeper suggestion rule: prefer the sharpest asset (highest blur
// score), tie-broken by largest sizeBytes, then by asset id (so ties
// are deterministic). An asset with no analysis scores below every
// analysed asset — unknown sharpness never beats measured sharpness.
// When NO asset in a group has a score, largest sizeBytes wins.
//
// Phase 5.2: grouping runs off the UI isolate ([groupAssetsOnIsolate]
// and [computeListDecksOnIsolate]). The functions are pure and
// their inputs are plain sendable data, so the isolate call is a
// direct [Isolate.run] of the same function the UI thread used to
// run — outputs are identical for identical inputs (proven by the
// determinism fixture test). A result landing after the caller
// moved on is dropped by the caller's AsyncGuard, never applied.

import 'dart:isolate';

import '../media/media_asset.dart';
import 'photo_analysis.dart';
import 'smart_decks.dart';

/// One duplicate / similar group: 2+ assets within threshold of the
/// representative hash, with a suggested keeper the user may change.
class DuplicateGroup {
  const DuplicateGroup({required this.assets, required this.keeperId});

  /// Group members in scan order.
  final List<MediaAsset> assets;

  /// Suggested keeper (see file doc), or the user's chosen keeper
  /// after [copyWithKeeper].
  final String keeperId;

  /// Members that are not the keeper: the deletion candidates.
  List<MediaAsset> get nonKeepers {
    return assets.where((MediaAsset a) => a.id != keeperId).toList();
  }

  /// Same group with a user-chosen keeper. No validation here: the
  /// controller only offers member ids, and an unknown id would
  /// simply make every member a non-keeper, which the view prevents
  /// by offering only member thumbnails.
  DuplicateGroup copyWithKeeper(String id) {
    return DuplicateGroup(assets: assets, keeperId: id);
  }
}

/// Groups [assets] by aHash distance (see file doc). [analyses] maps
/// asset id to its cached analysis; assets missing from it are
/// skipped. [threshold] is the slider value, 0-10.
///
/// Dispatch: threshold 0 takes the O(n) hash-bucket path
/// ([groupExactHashes], output identical to the greedy scan);
/// threshold > 0 takes the capped greedy path ([groupSimilar]).
List<DuplicateGroup> groupAssets({
  required List<MediaAsset> assets,
  required Map<String, PhotoAnalysis> analyses,
  required int threshold,
}) {
  if (threshold <= 0) {
    return groupExactHashes(assets: assets, analyses: analyses);
  }
  return groupSimilar(assets: assets, analyses: analyses, threshold: threshold);
}

/// Representative comparisons scanned per asset on the similar
/// path. 512 keeps a 50k library at ~25.6M worst-case Hamming
/// comparisons (bounded, and each is a few integer ops) instead of
/// an unbounded quadratic blowup; see the file doc for the split
/// trade-off this cap buys.
const int maxRepresentativeComparisons = 512;

/// Exact-duplicate grouping, O(n): one Map pass buckets analysed
/// assets by (hash, width, height) — the [PhotoAnalysis]
/// .isExactDuplicateOf rule (solutions 5.2) — with scan order
/// preserved inside each bucket, then buckets of 2+ become groups
/// with the usual keeper suggestion.
List<DuplicateGroup> groupExactHashes({
  required List<MediaAsset> assets,
  required Map<String, PhotoAnalysis> analyses,
}) {
  final Map<(int, int, int), List<MediaAsset>> buckets =
      <(int, int, int), List<MediaAsset>>{};
  for (final MediaAsset asset in assets) {
    final PhotoAnalysis? analysis = analyses[asset.id];
    if (analysis == null) {
      continue;
    }
    final (int, int, int) key = (
      analysis.hash,
      analysis.width,
      analysis.height,
    );
    (buckets[key] ??= <MediaAsset>[]).add(asset);
  }
  final List<DuplicateGroup> groups = <DuplicateGroup>[];
  for (final List<MediaAsset> members in buckets.values) {
    if (members.length < 2) {
      continue;
    }
    groups.add(
      DuplicateGroup(
        assets: members,
        keeperId: suggestKeeper(members, analyses),
      ),
    );
  }
  return groups;
}

/// Similar grouping: the greedy scan, with per-asset representative
/// comparisons capped at [maxRepresentativeComparisons]. An asset
/// whose match lies beyond the cap starts its own group (a safe
/// split, never a wrong merge — see the file doc).
List<DuplicateGroup> groupSimilar({
  required List<MediaAsset> assets,
  required Map<String, PhotoAnalysis> analyses,
  required int threshold,
}) {
  final List<_Cluster> clusters = <_Cluster>[];
  for (final MediaAsset asset in assets) {
    final PhotoAnalysis? analysis = analyses[asset.id];
    if (analysis == null) {
      continue;
    }
    _Cluster? match;
    int compared = 0;
    for (final _Cluster cluster in clusters) {
      if (compared >= maxRepresentativeComparisons) {
        break;
      }
      compared++;
      final PhotoAnalysis rep = analyses[cluster.representativeId]!;
      if (hammingDistance(analysis.hash, rep.hash) <= threshold) {
        match = cluster;
        break;
      }
    }
    if (match == null) {
      clusters.add(_Cluster(asset.id, <MediaAsset>[asset]));
    } else {
      match.members.add(asset);
    }
  }
  final List<DuplicateGroup> groups = <DuplicateGroup>[];
  for (final _Cluster cluster in clusters) {
    if (cluster.members.length < 2) {
      continue;
    }
    groups.add(
      DuplicateGroup(
        assets: cluster.members,
        keeperId: suggestKeeper(cluster.members, analyses),
      ),
    );
  }
  return groups;
}

/// Suggested keeper for [assets] (see file doc). Assumes non-empty;
/// an empty list returns '' rather than crashing.
String suggestKeeper(
  List<MediaAsset> assets,
  Map<String, PhotoAnalysis> analyses,
) {
  if (assets.isEmpty) {
    return '';
  }
  MediaAsset best = assets.first;
  for (final MediaAsset asset in assets.skip(1)) {
    if (_beatsKeeper(asset, best, analyses)) {
      best = asset;
    }
  }
  return best.id;
}

/// True when [candidate] outranks [current] as keeper: analysed
/// beats unanalysed, higher blur score beats lower, larger size
/// beats smaller. A full tie keeps the earlier asset, so the result
/// is deterministic for a given order.
bool _beatsKeeper(
  MediaAsset candidate,
  MediaAsset current,
  Map<String, PhotoAnalysis> analyses,
) {
  final PhotoAnalysis? cand = analyses[candidate.id];
  final PhotoAnalysis? curr = analyses[current.id];
  if ((cand != null) != (curr != null)) {
    return cand != null;
  }
  if (cand != null && curr != null && cand.blurScore != curr.blurScore) {
    return cand.blurScore > curr.blurScore;
  }
  return candidate.sizeBytes > current.sizeBytes;
}

class _Cluster {
  _Cluster(this.representativeId, this.members);

  final String representativeId;
  final List<MediaAsset> members;
}

/// Runs a grouping off the UI isolate. A function of this shape,
/// so callers can inject a gated runner in tests to prove
/// ready-before-grouping and stale-result drops.
typedef GroupingRunner = Future<List<DuplicateGroup>> Function(
  List<MediaAsset> assets,
  Map<String, PhotoAnalysis> analyses,
  int threshold,
);

/// Runs the hub's list-level decks (duplicates groups + burst ids)
/// off the UI isolate. Same injectable shape as [GroupingRunner]:
/// callers prove progressive landing with a gated runner.
typedef ListDecksRunner =
    Future<({List<DuplicateGroup> groups, Set<String> burstIds})> Function(
      List<MediaAsset> assets,
      Map<String, PhotoAnalysis> analyses,
      int threshold,
    );

/// The production grouping runner: the same [groupAssets] the UI
/// thread used to run, on a worker isolate. Inputs are plain
/// sendable data (ids, ints, doubles, dates), so the isolate call
/// needs no serialization layer — and outputs are identical for
/// identical inputs by construction.
Future<List<DuplicateGroup>> groupAssetsOnIsolate(
  List<MediaAsset> assets,
  Map<String, PhotoAnalysis> analyses,
  int threshold,
) {
  return Isolate.run(
    () => groupAssets(assets: assets, analyses: analyses, threshold: threshold),
  );
}

/// The production list-decks runner: grouping + burst sort in one
/// worker call, so the hub pays one isolate hop for both
/// list-level decks instead of two.
Future<({List<DuplicateGroup> groups, Set<String> burstIds})>
computeListDecksOnIsolate(
  List<MediaAsset> assets,
  Map<String, PhotoAnalysis> analyses,
  int threshold,
) {
  return Isolate.run(() {
    final List<DuplicateGroup> groups = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: threshold,
    );
    return (groups: groups, burstIds: burstAssetIds(assets));
  });
}
