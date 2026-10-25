// On-device photo analysis: perceptual hash, blur score and darkness
// score (requirements §7, Phase 2: blurry/dark detection, duplicate /
// similar grouping). Pure Dart: no platform imports, no network, no
// photo content stored — only a 64-bit hash and two scores per asset.
//
// THESE ARE THUMBNAIL HEURISTICS, NOT EXACT MEASUREMENTS. Every score
// is computed from a small downscaled thumbnail (see
// thumbnail_analysis.dart), so a "blurry" flag means "looks blurry at
// thumbnail resolution" and a "dark" flag means "dark on average".
// They are good enough to surface candidates for the user to judge;
// they never decide a deletion on their own — grouping only suggests
// a keeper and marks still flow through review + native confirmation.
//
// Definitions (frozen for Phase 2A):
// - aHash: the thumbnail is reduced to an 8x8 grayscale grid; each
//   cell becomes one bit (1 when its luminance is at or above the
//   grid mean, else 0). The 64 bits are one int, row-major.
// - Duplicates: same aHash (Hamming distance 0) AND same dimensions
//   (width x height from MediaAsset). Similarity grouping below uses
//   distance alone; the dimension rule is what makes a pair an exact
//   duplicate rather than merely similar.
// - Similar: aHash Hamming distance at or under the slider threshold
//   (Duplicates screen, range 0-10, default 5).
// - Blur score: variance of the 3x3 Laplacian over a 64x64 grayscale
//   thumbnail. Lower = blurrier. Threshold 100.0, calibrated on
//   synthetic images: a uniform frame scores 0 (flags blurry — a
//   blank frame has no detail to judge), a smooth photo with one hard
//   edge scores ~300 (passes), a sharp checkerboard scores ~93,000.
//   Real photos vary with content, so the threshold favours not
//   flagging sharp smooth photos; a heavily blurred high-contrast
//   pattern can still score above it. Documented, not hidden.
// - Dark: mean luminance (0-255) under 40.0. A night photo with a
//   bright subject can pass; a mostly-black frame flags.

import '../media/media_asset.dart';

/// Laplacian-variance score at or below which a photo counts blurry.
const double blurThreshold = 100.0;

/// Mean luminance below which a photo counts dark (0-255 scale).
const double darkThreshold = 40.0;

/// Side of the square grayscale grid the aHash is computed from.
const int hashGridSize = 8;

/// Side of the square grayscale grid the blur score is computed from.
const int blurGridSize = 64;

/// Algorithm version stamped on every analysis (solutions 5.3).
/// Bump it whenever the hash/blur/dark computation changes, so
/// old-version cache entries are re-analysed instead of mixed
/// with new-version ones. Version 0 is reserved for entries
/// written before versioning existed (see [PhotoAnalysis.fromJson]).
const int analysisAlgorithmVersion = 1;

/// One asset's cached analysis: hash + scores + the dimensions the
/// hash was computed against. Stored by LocalService (hash cache) so
/// regrouping and re-scans never re-download thumbnails.
///
/// Phase 5.3 fingerprint: [sizeBytes], [modifiedDateMs] and
/// [algorithmVersion] together say whether a cached entry still
/// describes the asset (see [isAnalysisFresh]). All three are
/// optional for construction — tests and old cache entries omit
/// them — but a missing version reads back as 0 (stale), and a
/// missing size/modified date reads back as null (stale unless
/// the asset also lacks that fact).
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

  /// 64-bit average hash (see file doc).
  final int hash;
  final int width;
  final int height;

  /// Laplacian variance on the 64x64 thumbnail (lower = blurrier).
  final double blurScore;

  /// Mean grayscale luminance, 0-255.
  final double meanLuminance;

  /// Fingerprint facts from the asset at analysis time (5.3).
  /// Null means "unknown" — from an old cache entry, or from an
  /// asset that reported no such fact.
  final int? sizeBytes;
  final int? modifiedDateMs;
  final int algorithmVersion;

  bool get isBlurry => blurScore <= blurThreshold;
  bool get isDark => meanLuminance < darkThreshold;

  /// True when [other] is an exact duplicate of this asset: same
  /// hash AND same dimensions (not merely a similar photo).
  bool isExactDuplicateOf(PhotoAnalysis other) {
    return hash == other.hash && width == other.width && height == other.height;
  }

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
      // Back-compat: entries written before 5.3 carry none of
      // these fields. Missing version reads as 0, so the entry
      // is stale by version mismatch and is re-analysed, never
      // mixed with current-version entries.
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      modifiedDateMs: (json['modifiedDateMs'] as num?)?.toInt(),
      algorithmVersion: (json['algorithmVersion'] as num?)?.toInt() ?? 0,
    );
  }
}

/// True when a cached [analysis] still describes [asset] (solutions
/// 5.3): same algorithm version AND same width, height, size and
/// modified date. A modified-date component matches when BOTH
/// sides lack it (an asset that reports no modified date), and
/// mismatches when exactly one side lacks it — an unknown is not
/// silently treated as unchanged. The scanner uses this instead
/// of a bare id lookup, so an edited photo is re-analysed on
/// rescan instead of keeping its pre-edit hash.
bool isAnalysisFresh(PhotoAnalysis analysis, MediaAsset asset) {
  if (analysis.algorithmVersion != analysisAlgorithmVersion) {
    return false;
  }
  if (analysis.width != asset.width || analysis.height != asset.height) {
    return false;
  }
  if (analysis.sizeBytes != asset.sizeBytes) {
    return false;
  }
  final int? assetModifiedMs = asset.modifiedDate?.millisecondsSinceEpoch;
  if (analysis.modifiedDateMs != assetModifiedMs) {
    return false;
  }
  return true;
}

/// Average hash from an 8x8 row-major grayscale grid (64 values,
/// 0-255). Bit = 1 when the cell is at or above the grid mean.
int averageHash(List<double> gray8x8) {
  assert(gray8x8.length == hashGridSize * hashGridSize);
  double sum = 0;
  for (final double value in gray8x8) {
    sum += value;
  }
  final double mean = sum / gray8x8.length;
  int hash = 0;
  for (int i = 0; i < gray8x8.length; i++) {
    if (gray8x8[i] >= mean) {
      hash |= 1 << i;
    }
  }
  return hash;
}

/// Number of differing bits between two hashes (0-64).
int hammingDistance(int a, int b) {
  int xor = a ^ b;
  int count = 0;
  while (xor != 0) {
    xor &= xor - 1;
    count++;
  }
  return count;
}

/// Mean luminance of a grayscale grid.
double meanLuminance(List<double> gray) {
  double sum = 0;
  for (final double value in gray) {
    sum += value;
  }
  return gray.isEmpty ? 0 : sum / gray.length;
}

/// Laplacian variance over a square grayscale grid of side [size]:
/// for each interior cell, 4*centre - neighbours, then the variance
/// of those values. Lower = blurrier (flat regions score near 0).
double laplacianVariance(List<double> gray, int size) {
  assert(gray.length == size * size);
  final List<double> laps = <double>[];
  for (int y = 1; y < size - 1; y++) {
    for (int x = 1; x < size - 1; x++) {
      laps.add(
        4 * gray[y * size + x] -
            gray[(y - 1) * size + x] -
            gray[(y + 1) * size + x] -
            gray[y * size + x - 1] -
            gray[y * size + x + 1],
      );
    }
  }
  if (laps.isEmpty) {
    return 0;
  }
  final double mean = meanLuminance(laps);
  double squared = 0;
  for (final double value in laps) {
    final double diff = value - mean;
    squared += diff * diff;
  }
  return squared / laps.length;
}
