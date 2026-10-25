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
// - AFTER, threshold 0 (exact hashes): hash-bucket pre-grouping.
//   One Map pass buckets assets by hash, O(n) total, and the
//   output is IDENTICAL to the old greedy run at threshold 0
//   (same-hash assets always shared the first cluster's
//   representative, and bucket order preserves scan order, so
//   groups and keeper suggestions are unchanged).
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

import '../media/media_asset.dart';
import 'photo_analysis.dart';

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

/// Exact-hash grouping, O(n): one Map pass buckets analysed assets
/// by hash (scan order preserved inside each bucket), then buckets
/// of 2+ become groups with the usual keeper suggestion. Output is
/// identical to the old greedy scan at threshold 0.
List<DuplicateGroup> groupExactHashes({
  required List<MediaAsset> assets,
  required Map<String, PhotoAnalysis> analyses,
}) {
  final Map<int, List<MediaAsset>> buckets = <int, List<MediaAsset>>{};
  for (final MediaAsset asset in assets) {
    final PhotoAnalysis? analysis = analyses[asset.id];
    if (analysis == null) {
      continue;
    }
    (buckets[analysis.hash] ??= <MediaAsset>[]).add(asset);
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
