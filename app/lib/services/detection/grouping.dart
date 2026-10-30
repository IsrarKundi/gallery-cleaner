// Duplicate / similar grouping (fix plan Stage 4, requirements
// §7): Cleanup's recovered rules (notes/algorithms.md §1-§2),
// replacing the aHash + similarity-slider engine.
//
// - Similar: seed clustering. Assets are sorted by date; the
//   first remaining asset is the SEED; an asset joins only if
//   [areSimilar] holds against the SEED itself (never against
//   another member — no transitivity); the next ungrouped asset
//   becomes the next seed; groups of 1 are dropped. Photos and
//   screenshots are grouped separately (their compare tables
//   differ), and only assets with a valid fingerprint take part.
// - Exact duplicates: Cleanup's key — same type (photo /
//   screenshot class), same width x height, same dHash, same
//   edited flag, same file size. All equal, or not a duplicate.
//   Buckets of 1 are dropped.
// - Keeper suggestion: the existing rule, fed by the new blur
//   measure — sharpest first (LOWEST Cleanup blur score: the new
//   score grows with blur, the opposite direction of the old
//   Laplacian variance), tie-broken by largest sizeBytes, then
//   by group order (earliest first). An asset with no blur score
//   ranks below every scored asset: unknown sharpness never
//   beats measured sharpness. Grouping only ever SUGGESTS a
//   keeper; deletion still flows through review + native
//   confirmation.
//
// These are pure functions over one scan's transient assessments
// (photo_assessment.dart); the persisted form of their output is
// ScanMemberships (scan_memberships.dart).

import 'dart:isolate';

import '../media/media_asset.dart';
import 'photo_assessment.dart';
import 'scan_memberships.dart';

/// One duplicate / similar group: 2+ assets, with a suggested
/// keeper the user may change.
class DuplicateGroup {
  const DuplicateGroup({required this.assets, required this.keeperId});

  /// Group members in date order (seed first for similar groups).
  final List<MediaAsset> assets;

  /// Suggested keeper (see file doc), or the user's chosen keeper
  /// after [copyWithKeeper].
  final String keeperId;

  /// Members that are not the keeper: the deletion candidates.
  List<MediaAsset> get nonKeepers {
    return assets.where((MediaAsset a) => a.id != keeperId).toList();
  }

  /// Same group with a user-chosen keeper. No validation here:
  /// the controller only offers member ids, and an unknown id
  /// would simply make every member a non-keeper, which the view
  /// prevents by offering only member thumbnails.
  DuplicateGroup copyWithKeeper(String id) {
    return DuplicateGroup(assets: assets, keeperId: id);
  }
}

/// Date order for grouping: createDate ascending, asset id as
/// the deterministic tie-break.
int _byDate(MediaAsset a, MediaAsset b) {
  final int byDate = a.createDate.compareTo(b.createDate);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

/// Similar grouping, Cleanup's seed rule (see file doc). Photos
/// and screenshots are clustered separately, each in date order.
List<DuplicateGroup> groupSimilarCleanup({
  required List<MediaAsset> assets,
  required Map<String, PhotoAssessment> assessments,
}) {
  final List<DuplicateGroup> out = <DuplicateGroup>[];
  for (final FingerprintClass assetClass in FingerprintClass.values) {
    final List<MediaAsset> pool =
        assets
            .where(
              (MediaAsset a) =>
                  a.type == MediaAssetType.image &&
                  fingerprintClassOf(a) == assetClass &&
                  (assessments[a.id]?.fingerprint?.isValid ?? false),
            )
            .toList()
          ..sort(_byDate);
    final List<MediaAsset> remaining = List<MediaAsset>.of(pool);
    while (remaining.isNotEmpty) {
      final MediaAsset seed = remaining.first;
      final PhotoFingerprint seedPrint = assessments[seed.id]!.fingerprint!;
      final List<MediaAsset> members = <MediaAsset>[seed];
      remaining.removeAt(0);
      remaining.removeWhere((MediaAsset candidate) {
        final PhotoFingerprint print = assessments[candidate.id]!.fingerprint!;
        if (areSimilar(seedPrint, print, assetClass)) {
          members.add(candidate);
          return true;
        }
        return false;
      });
      // Members were collected in date order (the pool is sorted
      // and removeWhere preserves order), seed first.
      if (members.length >= 2) {
        out.add(
          DuplicateGroup(
            assets: members,
            keeperId: suggestKeeper(members, assessments),
          ),
        );
      }
    }
  }
  return out;
}

/// Exact-duplicate grouping, Cleanup's key (see file doc).
/// Returns the groups (for display) and the duplicate reference
/// (the persisted main + duplicates per set). A group's main is
/// its suggested keeper — the existing keeper logic names it;
/// [suggestKeeper]'s final tie-break (group order) makes it the
/// seed (earliest by date) whenever scores and sizes tie.
({List<DuplicateGroup> groups, List<DuplicateReference> references})
groupExactDuplicates({
  required List<MediaAsset> assets,
  required Map<String, PhotoAssessment> assessments,
  required Map<String, AssetInfo> assetInfos,
}) {
  final Map<(FingerprintClass, int, int, int, bool, int?), List<MediaAsset>>
  buckets = <(FingerprintClass, int, int, int, bool, int?), List<MediaAsset>>{};
  final List<MediaAsset> sorted =
      assets.where((MediaAsset a) => a.type == MediaAssetType.image).toList()
        ..sort(_byDate);
  for (final MediaAsset asset in sorted) {
    final PhotoFingerprint? print = assessments[asset.id]?.fingerprint;
    final AssetInfo? info = assetInfos[asset.id];
    if (print == null || !print.isValid || info == null) {
      continue;
    }
    final (FingerprintClass, int, int, int, bool, int?) key = (
      fingerprintClassOf(asset),
      info.width,
      info.height,
      print.dHash,
      info.isEdited,
      info.sizeBytes,
    );
    (buckets[key] ??= <MediaAsset>[]).add(asset);
  }
  final List<DuplicateGroup> groups = <DuplicateGroup>[];
  final List<DuplicateReference> references = <DuplicateReference>[];
  for (final List<MediaAsset> members in buckets.values) {
    if (members.length < 2) {
      continue;
    }
    final String keeperId = suggestKeeper(members, assessments);
    groups.add(DuplicateGroup(assets: members, keeperId: keeperId));
    references.add(
      DuplicateReference(
        mainId: keeperId,
        duplicateIds: <String>[
          for (final MediaAsset member in members)
            if (member.id != keeperId) member.id,
        ],
      ),
    );
  }
  return (groups: groups, references: references);
}

/// Suggested keeper for [assets] (see file doc). Assumes
/// non-empty; an empty list returns '' rather than crashing.
String suggestKeeper(
  List<MediaAsset> assets,
  Map<String, PhotoAssessment> assessments,
) {
  if (assets.isEmpty) {
    return '';
  }
  MediaAsset best = assets.first;
  for (final MediaAsset asset in assets.skip(1)) {
    if (_beatsKeeper(asset, best, assessments)) {
      best = asset;
    }
  }
  return best.id;
}

/// True when [candidate] outranks [current] as keeper: scored
/// beats unscored, lower blur score (sharper under the new
/// measure) beats higher, larger size beats smaller. A full tie
/// keeps the earlier asset, so the result is deterministic.
bool _beatsKeeper(
  MediaAsset candidate,
  MediaAsset current,
  Map<String, PhotoAssessment> assessments,
) {
  final double? candScore = assessments[candidate.id]?.blur?.score;
  final double? currScore = assessments[current.id]?.blur?.score;
  if ((candScore != null) != (currScore != null)) {
    return candScore != null;
  }
  if (candScore != null && currScore != null && candScore != currScore) {
    return candScore < currScore;
  }
  return candidate.sizeBytes > current.sizeBytes;
}

/// Builds the full persisted product of one scan from its
/// transient assessments: asset-info facts, similar + duplicate
/// groups, the duplicate reference, and the blurry / dark
/// membership sets. Pure — the scanner runs it on a worker
/// isolate (see [buildScanMembershipsOnIsolate]).
ScanMemberships buildScanMemberships({
  required List<MediaAsset> assets,
  required Map<String, PhotoAssessment> assessments,
}) {
  final Map<String, AssetInfo> infos = <String, AssetInfo>{
    for (final MediaAsset asset in assets) asset.id: AssetInfo.fromAsset(asset),
  };
  final List<DuplicateGroup> similar = groupSimilarCleanup(
    assets: assets,
    assessments: assessments,
  );
  final ({List<DuplicateGroup> groups, List<DuplicateReference> references})
  exact = groupExactDuplicates(
    assets: assets,
    assessments: assessments,
    assetInfos: infos,
  );
  final List<ScanGroup> groups = <ScanGroup>[
    for (final DuplicateGroup group in similar)
      ScanGroup(
        kind: ScanGroupKind.similar,
        memberIds: <String>[for (final MediaAsset a in group.assets) a.id],
        seedId: group.assets.first.id,
        keeperId: group.keeperId,
      ),
    for (final DuplicateGroup group in exact.groups)
      ScanGroup(
        kind: ScanGroupKind.duplicate,
        memberIds: <String>[for (final MediaAsset a in group.assets) a.id],
        keeperId: group.keeperId,
      ),
    if (assets.any(
      (MediaAsset a) =>
          a.type == MediaAssetType.image &&
          (assessments[a.id]?.isBlurry ?? false),
    ))
      ScanGroup(
        kind: ScanGroupKind.blurry,
        memberIds: <String>[
          for (final MediaAsset a in assets)
            if (a.type == MediaAssetType.image &&
                (assessments[a.id]?.isBlurry ?? false))
              a.id,
        ],
      ),
    if (assets.any(
      (MediaAsset a) =>
          a.type == MediaAssetType.image &&
          (assessments[a.id]?.isDark ?? false),
    ))
      ScanGroup(
        kind: ScanGroupKind.dark,
        memberIds: <String>[
          for (final MediaAsset a in assets)
            if (a.type == MediaAssetType.image &&
                (assessments[a.id]?.isDark ?? false))
              a.id,
        ],
      ),
  ];
  return ScanMemberships(
    algorithmVersion: scanMembershipAlgorithmVersion,
    assetInfos: infos,
    groups: groups,
    duplicateReferences: exact.references,
  );
}

/// The production membership builder: [buildScanMemberships] on
/// a worker isolate, so grouping a large library never runs on
/// the UI thread. Inputs are plain sendable data.
Future<ScanMemberships> buildScanMembershipsOnIsolate(
  List<MediaAsset> assets,
  Map<String, PhotoAssessment> assessments,
) {
  return Isolate.run(
    () => buildScanMemberships(assets: assets, assessments: assessments),
  );
}

/// A function of this shape, so callers can inject a gated
/// runner in tests to prove stale-result drops.
typedef MembershipsRunner = Future<ScanMemberships> Function(
  List<MediaAsset> assets,
  Map<String, PhotoAssessment> assessments,
);

/// Display groups of one [kind] from persisted [memberships],
/// resolving member ids against [assetsById]. Members that no
/// longer resolve are dropped; a group left with fewer than 2
/// members is dropped (it is not a group anymore).
List<DuplicateGroup> groupsFromMemberships(
  Map<String, MediaAsset> assetsById,
  ScanMemberships memberships,
  ScanGroupKind kind,
) {
  final List<DuplicateGroup> out = <DuplicateGroup>[];
  for (final ScanGroup group in memberships.groupsOfKind(kind)) {
    final List<MediaAsset> members = <MediaAsset>[
      for (final String id in group.memberIds)
        if (assetsById[id] != null) assetsById[id]!,
    ];
    if (members.length < 2) {
      continue;
    }
    final String keeperId =
        group.keeperId != null && assetsById.containsKey(group.keeperId)
        ? group.keeperId!
        : members.first.id;
    out.add(DuplicateGroup(assets: members, keeperId: keeperId));
  }
  return out;
}
