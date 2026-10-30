// LEGACY persisted analysis (pre-Stage 4): the aHash + scores
// record the old engine wrote into the analyses cache.
//
// As of fix plan Stage 4 this type is READ-ONLY history: it is
// used solely to read old caches during migration
// (json_migration.dart and LocalServiceImpl's legacy reader), so
// their asset-info facts can be converted into the new
// membership store (scan_memberships.dart) while their groups —
// computed by an engine that no longer exists — are safely
// discarded and rescanned. Nothing new is ever written in this
// shape: the persisted hash is gone (ADR-019), replaced by
// persisted memberships. The live engine's values are
// PhotoAssessment / PhotoFingerprint / BlurAssessment
// (photo_assessment.dart, blur_detection.dart).

/// Algorithm version stamped on legacy analyses. Version 0 is
/// reserved for entries written before versioning existed.
const int analysisAlgorithmVersion = 1;

/// One legacy cached analysis: aHash + blur/dark scores + the
/// dimensions and fingerprint facts the hash was computed
/// against. See the file doc for why this still exists.
class PhotoAnalysis {
  const PhotoAnalysis({
    required this.assetId,
    required this.hash,
    required this.width,
    required this.height,
    required this.blurScore,
    required this.meanLuminance,
    this.sizeBytes,
    this.modifiedDateMs,
    this.algorithmVersion = analysisAlgorithmVersion,
  });

  final String assetId;

  /// 64-bit average hash (legacy engine).
  final int hash;
  final int width;
  final int height;

  /// Laplacian-variance blur score (legacy engine).
  final double blurScore;

  /// Mean grayscale luminance, 0-255.
  final double meanLuminance;

  /// Fingerprint facts from the asset at analysis time. Null
  /// means "unknown" — from an old cache entry, or from an asset
  /// that reported no such fact.
  final int? sizeBytes;
  final int? modifiedDateMs;
  final int algorithmVersion;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'assetId': assetId,
      'hash': hash,
      'width': width,
      'height': height,
      'blurScore': blurScore,
      'meanLuminance': meanLuminance,
      'sizeBytes': sizeBytes,
      'modifiedDateMs': modifiedDateMs,
      'algorithmVersion': algorithmVersion,
    };
  }

  factory PhotoAnalysis.fromJson(Map<String, dynamic> json) {
    return PhotoAnalysis(
      assetId: json['assetId'] as String,
      hash: json['hash'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      blurScore: (json['blurScore'] as num).toDouble(),
      meanLuminance: (json['meanLuminance'] as num).toDouble(),
      // Back-compat: entries written before fingerprinting carry
      // none of these fields. Missing version reads as 0.
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      modifiedDateMs: (json['modifiedDateMs'] as num?)?.toInt(),
      algorithmVersion: (json['algorithmVersion'] as num?)?.toInt() ?? 0,
    );
  }
}
