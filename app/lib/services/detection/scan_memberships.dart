// The persisted product of a scan (fix plan Stage 4, landing
// Stage 3's deferred split — ADR-018 Decision 5, ADR-019):
// Cleanup's three kinds of things, in wipe.'s stores —
//   1. asset-info facts (one row per asset: type, dimensions,
//      size, modified date, edited flag, screenshot marking),
//   2. group memberships (similar groups, duplicate groups,
//      the blurry / dark membership sets, and — Stage 6 —
//      similar-video groups),
//   3. the duplicate reference (per duplicate set: the main
//      photo + its duplicates).
// NO hash and NO blur score is ever persisted: fingerprints and
// scores are computed during a scan, used for its comparisons,
// and discarded (Cleanup's rule — pipeline notes). The stored
// form below has no field that could carry one, and the
// round-trip test asserts the serialised keys.
//
// Freshness: [ScanMemberships.assetInfos] are compared against
// the live enumeration by the scanner. When every fact matches
// and [ScanMemberships.algorithmVersion] is current, the saved
// memberships are reused and no photo is read again. Any
// difference discards the memberships and rescans — an old
// algorithm's groups are never mixed with a new one's.

import '../media/media_asset.dart';

/// Membership algorithm version. Bump whenever the fingerprint,
/// compare table, grouping, blur, or membership shape changes,
/// so saved memberships from an older engine are discarded and
/// rescanned instead of mixed with new ones. Version 0 means
/// "legacy / none" (rows converted from the pre-Stage 4 analysis
/// cache carry facts only, at version 0).
/// Version 2 (fix plan Stage 6): similar-video groups join the
/// persisted product — a version 1 snapshot has none, so it is
/// stale by this check alone and the first Stage 6 scan
/// recomputes the whole matching phase, videos included.
/// Version 3 (blur calibration, ADR-023): the blur line moved
/// from Cleanup's fallback 2.2 to wipe.'s owner-set 4.2 — a
/// version 2 snapshot's Blurry set was built under the old
/// line, so it is stale by this check alone and the first
/// scan under this build recomputes and restamps.
const int scanMembershipAlgorithmVersion = 3;

/// Meta key (in the stores' key/value area) holding the
/// persisted membership algorithm version.
const String kMembershipVersionKey = 'scan_membership_version';

/// The membership families a scan produces.
enum ScanGroupKind { similar, duplicate, blurry, dark, similarVideos }

/// Facts about one asset, as the enumeration reported them when
/// the scan ran (the asset-info third of the Stage 3 split).
class AssetInfo {
  const AssetInfo({
    required this.assetId,
    required this.type,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.modifiedDateMs,
    required this.isEdited,
    required this.isScreenshot,
  });

  /// Builds the facts for a live [asset]. The edited flag has no
  /// source in wipe.'s enumeration today; Cleanup's Android
  /// enumeration likewise constructs it false (algorithms.md §3),
  /// so it is false until a source exists (ADR-019).
  factory AssetInfo.fromAsset(MediaAsset asset) {
    return AssetInfo(
      assetId: asset.id,
      type: asset.type,
      width: asset.width,
      height: asset.height,
      sizeBytes: asset.sizeBytes,
      modifiedDateMs: asset.modifiedDate?.millisecondsSinceEpoch,
      isEdited: false,
      isScreenshot: asset.isScreenshot,
    );
  }

  final String assetId;
  final MediaAssetType type;
  final int width;
  final int height;

  /// File size in bytes, as enumerated (never null in the
  /// enumeration; nullable only so legacy converted rows, whose
  /// size could be unknown, round-trip honestly).
  final int? sizeBytes;

  /// Modified date, epoch milliseconds (null when unknown).
  final int? modifiedDateMs;

  /// Edited flag for the duplicate key (see [fromAsset]).
  final bool isEdited;

  /// Stage 2's file-name screenshot marking at scan time.
  final bool isScreenshot;

  /// Field-for-field equality: the scanner's reuse rule.
  bool sameFacts(AssetInfo other) {
    return assetId == other.assetId &&
        type == other.type &&
        width == other.width &&
        height == other.height &&
        sizeBytes == other.sizeBytes &&
        modifiedDateMs == other.modifiedDateMs &&
        isEdited == other.isEdited &&
        isScreenshot == other.isScreenshot;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'assetId': assetId,
      'type': type.name,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
      'modifiedDateMs': modifiedDateMs,
      'isEdited': isEdited,
      'isScreenshot': isScreenshot,
    };
  }

  factory AssetInfo.fromJson(Map<String, dynamic> json) {
    return AssetInfo(
      assetId: json['assetId'] as String,
      type: MediaAssetType.values.firstWhere(
        (MediaAssetType t) => t.name == json['type'],
        orElse: () => MediaAssetType.image,
      ),
      width: json['width'] as int,
      height: json['height'] as int,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      modifiedDateMs: (json['modifiedDateMs'] as num?)?.toInt(),
      isEdited: json['isEdited'] as bool? ?? false,
      isScreenshot: json['isScreenshot'] as bool? ?? false,
    );
  }
}

/// One persisted group: its kind, its members in stored order,
/// and (for similar and similar-video groups) the seed the
/// group grew from and (for similar + duplicate groups) the
/// suggested keeper/main. Blurry and dark are single membership
/// sets, stored as one group each with no seed/keeper;
/// similar-video groups carry a seed and no keeper (a swipe
/// deck has no keeper concept — the keeper machinery belongs
/// to the Duplicates screen, which is photo-only).
class ScanGroup {
  const ScanGroup({
    required this.kind,
    required this.memberIds,
    this.seedId,
    this.keeperId,
  });

  final ScanGroupKind kind;

  /// Member asset ids, in stored (date) order.
  final List<String> memberIds;
  final String? seedId;
  final String? keeperId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'memberIds': memberIds,
      'seedId': seedId,
      'keeperId': keeperId,
    };
  }

  factory ScanGroup.fromJson(Map<String, dynamic> json) {
    return ScanGroup(
      kind: ScanGroupKind.values.firstWhere(
        (ScanGroupKind k) => k.name == json['kind'],
        orElse: () => ScanGroupKind.similar,
      ),
      memberIds: <String>[
        for (final Object? id in json['memberIds'] as List<dynamic>? ?? [])
          id as String,
      ],
      seedId: json['seedId'] as String?,
      keeperId: json['keeperId'] as String?,
    );
  }
}

/// The duplicate reference for one set (Cleanup's
/// duplicateReference.json): which photo is the main one, and
/// which photos are its duplicates.
class DuplicateReference {
  const DuplicateReference({required this.mainId, required this.duplicateIds});

  final String mainId;
  final List<String> duplicateIds;

  /// Every member of the set, main first.
  List<String> get memberIds => <String>[mainId, ...duplicateIds];

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'mainId': mainId, 'duplicateIds': duplicateIds};
  }

  factory DuplicateReference.fromJson(Map<String, dynamic> json) {
    return DuplicateReference(
      mainId: json['mainId'] as String,
      duplicateIds: <String>[
        for (final Object? id in json['duplicateIds'] as List<dynamic>? ?? [])
          id as String,
      ],
    );
  }
}

/// One scan's full persisted product (see file doc).
class ScanMemberships {
  const ScanMemberships({
    required this.algorithmVersion,
    required this.assetInfos,
    required this.groups,
    required this.duplicateReferences,
  });

  /// The empty product (no scan has completed yet, or a legacy
  /// conversion that must be rescanned).
  static const ScanMemberships empty = ScanMemberships(
    algorithmVersion: 0,
    assetInfos: <String, AssetInfo>{},
    groups: <ScanGroup>[],
    duplicateReferences: <DuplicateReference>[],
  );

  final int algorithmVersion;

  /// Asset-info facts by asset id.
  final Map<String, AssetInfo> assetInfos;

  /// All groups, every kind.
  final List<ScanGroup> groups;

  /// The duplicate reference (one entry per duplicate set).
  final List<DuplicateReference> duplicateReferences;

  List<ScanGroup> groupsOfKind(ScanGroupKind kind) {
    return groups.where((ScanGroup g) => g.kind == kind).toList();
  }

  /// Member ids of the single set stored for [kind] (blurry /
  /// dark), or empty when the set is absent.
  Set<String> memberSetOf(ScanGroupKind kind) {
    for (final ScanGroup group in groups) {
      if (group.kind == kind) {
        return group.memberIds.toSet();
      }
    }
    return <String>{};
  }

  /// Union of the member ids of EVERY group of [kind] — the
  /// multi-group families (similar, duplicate, similarVideos),
  /// whose membership is a list of groups, not one set.
  Set<String> allMemberIdsOf(ScanGroupKind kind) {
    return <String>{
      for (final ScanGroup group in groups)
        if (group.kind == kind) ...group.memberIds,
    };
  }

  Set<String> get blurryIds => memberSetOf(ScanGroupKind.blurry);
  Set<String> get darkIds => memberSetOf(ScanGroupKind.dark);

  /// True when [current] (facts built from the live enumeration)
  /// matches this snapshot exactly AND the algorithm version is
  /// current: the saved memberships may be reused as-is.
  bool isFreshFor(Map<String, AssetInfo> current) {
    if (algorithmVersion != scanMembershipAlgorithmVersion) {
      return false;
    }
    if (current.length != assetInfos.length) {
      return false;
    }
    for (final MapEntry<String, AssetInfo> entry in current.entries) {
      final AssetInfo? saved = assetInfos[entry.key];
      if (saved == null || !saved.sameFacts(entry.value)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'algorithmVersion': algorithmVersion,
      'assetInfos': <String, dynamic>{
        for (final MapEntry<String, AssetInfo> entry in assetInfos.entries)
          entry.key: entry.value.toJson(),
      },
      'groups': <Map<String, dynamic>>[
        for (final ScanGroup group in groups) group.toJson(),
      ],
      'duplicateReferences': <Map<String, dynamic>>[
        for (final DuplicateReference ref in duplicateReferences) ref.toJson(),
      ],
    };
  }

  factory ScanMemberships.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawInfos =
        json['assetInfos'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ScanMemberships(
      algorithmVersion: (json['algorithmVersion'] as num?)?.toInt() ?? 0,
      assetInfos: <String, AssetInfo>{
        for (final MapEntry<String, dynamic> entry in rawInfos.entries)
          entry.key: AssetInfo.fromJson(
            Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>),
          ),
      },
      groups: <ScanGroup>[
        for (final Object? raw in json['groups'] as List<dynamic>? ?? [])
          ScanGroup.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          ),
      ],
      duplicateReferences: <DuplicateReference>[
        for (final Object? raw
            in json['duplicateReferences'] as List<dynamic>? ?? [])
          DuplicateReference.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          ),
      ],
    );
  }
}
