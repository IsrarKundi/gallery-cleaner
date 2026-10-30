// Two-part photo fingerprint + similarity predicate (fix plan
// Stage 4, requirements §7): our own Dart code implementing the
// Cleanup teardown's recovered recipe (notes/algorithms.md §2).
//
// A fingerprint is TRANSIENT: it is computed from a thumbnail of
// at most 1024 px when a comparison needs it and is never
// persisted (Stage 3's split persists memberships, not hashes —
// see scan_memberships.dart and ADR-019).
//
// Recipe, exactly as recovered:
// - Shape: a 64-bit difference hash. The image is reduced to a
//   9x8 grayscale raster; each of the 8 horizontal neighbour
//   comparisons per row is one bit (1 when the left pixel is
//   brighter than its right neighbour). The teardown infers the
//   9x8 geometry from Cleanup's video-frame path; the bit-sign
//   convention lives in their native code and is not observable,
//   so wipe. fixes this convention — it only has to be
//   self-consistent, because fingerprints are compared only
//   against fingerprints from the same build.
// - Colour: per-channel (R, G, B) histograms over 256 bins folded
//   into 8 intensity bands of 32 values -> 24 numbers, each band
//   sum divided by (width x height) / 16. Colour distance is the
//   sum of absolute differences of the 24 numbers, truncated to
//   an integer before the band checks (the teardown's predicate
//   truncates the distance to a long).
// - Validity: a fingerprint whose dHash is -1 (all bits set) is
//   invalid, mirroring Cleanup's hash != -1 rule; such an asset
//   never groups.

import '../media/media_asset.dart';
import 'blur_detection.dart';

/// Which comparison family an asset belongs to. Cleanup compares
/// only within one media type; wipe.'s stills split into normal
/// photos and screenshots (Stage 2's file-name marking), which
/// use different threshold tables.
enum FingerprintClass { photo, screenshot }

/// The class of [asset] for fingerprint comparison: screenshots
/// (by Stage 2's name marking) form their own family; every other
/// image is a normal photo. Videos never enter still comparison.
FingerprintClass fingerprintClassOf(MediaAsset asset) {
  return asset.isScreenshot
      ? FingerprintClass.screenshot
      : FingerprintClass.photo;
}

/// One asset's two-part fingerprint (see file doc).
class PhotoFingerprint {
  const PhotoFingerprint({required this.dHash, required this.colorHistogram});

  /// 64-bit difference hash.
  final int dHash;

  /// 24 numbers: R bands 0-7, then G bands 0-7, then B bands 0-7,
  /// each divided by (width x height) / 16 of the source raster.
  final List<double> colorHistogram;

  /// Cleanup's validity rule: hash -1 means "no fingerprint".
  bool get isValid => dHash != -1 && colorHistogram.length == 24;
}

/// Number of differing bits between two 64-bit hashes (0-64).
int hammingDistance(int a, int b) {
  int xor = a ^ b;
  int count = 0;
  while (xor != 0) {
    xor &= xor - 1;
    count++;
  }
  return count;
}

/// Raw colour distance between two fingerprints: the sum of the
/// absolute differences of all 24 colour numbers (NOT truncated —
/// [areSimilar] applies the teardown's truncation).
double colorDistance(PhotoFingerprint a, PhotoFingerprint b) {
  double sum = 0;
  for (int i = 0; i < 24; i++) {
    sum += (a.colorHistogram[i] - b.colorHistogram[i]).abs();
  }
  return sum;
}

/// Cleanup's similarity predicate (algorithms.md §2.2), exact
/// band edges. Both fingerprints must be valid and of the same
/// [FingerprintClass] (the caller partitions by class; the class
/// is still taken as a parameter so the tables cannot be mixed
/// up at a call site).
///
/// Band resolution mirrors the recovered code: the fast-accept
/// band is checked first, then the colour bands in list order —
/// so a distance exactly on a shared edge (d = 4 or d = 10 for
/// photos, d = 10 for screenshots) resolves through the FIRST
/// band containing it.
bool areSimilar(
  PhotoFingerprint a,
  PhotoFingerprint b,
  FingerprintClass assetClass,
) {
  if (!a.isValid || !b.isValid) {
    return false;
  }
  final int d = hammingDistance(a.dHash, b.dHash);
  // The colour distance is truncated toward zero before the band
  // checks (the teardown's predicate truncates to a long).
  final int c = colorDistance(a, b).truncate();
  if (assetClass == FingerprintClass.screenshot) {
    if (d >= 16) {
      return false;
    }
    if (d <= 2) {
      return true; // fast accept, colour never consulted
    }
    if (d <= 10) {
      return c <= 5;
    }
    return c <= 2;
  }
  if (d >= 18) {
    return false;
  }
  if (d <= 4) {
    return true; // fast accept, colour never consulted
  }
  if (d <= 10) {
    return c <= 7;
  }
  return c <= 5;
}

/// One asset's transient Stage 4 assessment: the fingerprint and
/// blur result computed for one scan, plus the mean luminance the
/// Dark deck has always used. Nothing here is persisted; the
/// persisted product of a scan is its memberships
/// (scan_memberships.dart).
class PhotoAssessment {
  const PhotoAssessment({
    required this.assetId,
    this.fingerprint,
    this.blur,
    this.meanLuminance,
  });

  final String assetId;

  /// Null when the thumbnail did not decode (or was a video).
  final PhotoFingerprint? fingerprint;

  /// Null when the blur pass could not read the photo.
  final BlurAssessment? blur;

  /// Mean luminance 0-255 from the fingerprint raster, or null
  /// when no fingerprint was computed.
  final double? meanLuminance;

  bool get isBlurry => blur?.isBlurry ?? false;

  bool get isDark => meanLuminance != null && meanLuminance! < darkThreshold;
}

/// Mean luminance below which a photo counts dark (0-255 scale).
/// Unchanged from the pre-Stage 4 engine: the Dark deck's rule
/// was never part of the Cleanup evidence, so it is not retuned.
const double darkThreshold = 40.0;
