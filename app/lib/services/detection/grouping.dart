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
List<DuplicateGroup> groupAssets({
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
    for (final _Cluster cluster in clusters) {
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
