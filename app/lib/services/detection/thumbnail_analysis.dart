// Decodes thumbnails into Stage 4's transient values
// (requirements §7): the two-part fingerprint (from a thumbnail
// of at most 1024 px — the scanner fetches 128 px, inside the
// cap) and the blur measures (from a 512 px thumbnail, Cleanup's
// analysis size). Service-layer code only: no decoded pixels
// ever leave this file — only the fingerprint, the blur
// measures and the mean luminance.
//
// A decode failure returns null; the caller skips that value
// for that asset instead of failing the whole scan.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'blur_detection.dart';
import 'photo_assessment.dart';

/// Thumbnail edge requested from MediaService for the
/// fingerprint. Small on purpose (Cleanup's cap is 1024 px):
/// the fingerprint needs structure and colour distribution,
/// not pixels, and a small thumbnail keeps scans cheap.
const int analysisThumbnailSize = 128;

/// Thumbnail edge requested for the blur pass (Cleanup's
/// analysis size, algorithms.md §4).
const int blurThumbnailSize = 512;

/// One asset's computed fingerprint + mean luminance.
class FingerprintComputation {
  const FingerprintComputation({
    required this.fingerprint,
    required this.meanLuminance,
  });

  final PhotoFingerprint fingerprint;
  final double meanLuminance;
}

/// Computes the two-part fingerprint (photo_assessment.dart)
/// from thumbnail [bytes], or null when the bytes do not decode.
FingerprintComputation? computeFingerprint(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    return null;
  }
  // Colour summary: per-channel histograms over the raster as
  // decoded, folded into 8 bands of 32 values, each band sum
  // divided by (width x height) / 16.
  final List<double> bands = List<double>.filled(24, 0);
  final double divisor = (decoded.width * decoded.height) / 16.0;
  double luminanceSum = 0;
  for (int y = 0; y < decoded.height; y++) {
    for (int x = 0; x < decoded.width; x++) {
      final img.Pixel pixel = decoded.getPixel(x, y);
      bands[(pixel.r.toInt() ~/ 32)] += 1;
      bands[8 + (pixel.g.toInt() ~/ 32)] += 1;
      bands[16 + (pixel.b.toInt() ~/ 32)] += 1;
      luminanceSum += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    }
  }
  for (int i = 0; i < 24; i++) {
    bands[i] = bands[i] / divisor;
  }
  // Shape: difference hash over a 9x8 grayscale raster — bit set
  // when the left pixel is brighter than its right neighbour.
  final img.Image small = img.copyResize(
    img.grayscale(decoded.clone()),
    width: 9,
    height: 8,
    interpolation: img.Interpolation.average,
  );
  int dHash = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      final num left = small.getPixel(x, y).r;
      final num right = small.getPixel(x + 1, y).r;
      if (left > right) {
        dHash |= 1 << (y * 8 + x);
      }
    }
  }
  return FingerprintComputation(
    fingerprint: PhotoFingerprint(dHash: dHash, colorHistogram: bands),
    meanLuminance: luminanceSum / (decoded.width * decoded.height),
  );
}

/// Computes the blur measures (blur_detection.dart) from the
/// 512 px thumbnail [bytes], or null when the bytes do not
/// decode.
BlurAssessment? computeBlur(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }
  return assessBlur(decoded);
}
