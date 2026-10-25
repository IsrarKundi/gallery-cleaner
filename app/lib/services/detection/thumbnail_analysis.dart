// Decodes a thumbnail into a [PhotoAnalysis] (requirements §7,
// Phase 2). Service-layer code only: feature code never decodes
// bytes itself, and no decoded pixels ever leave this file — only
// the hash and scores.
//
// Thumbnails arrive from MediaService (square, [thumbnailSize] px).
// They are downscaled to 64x64 for blur/darkness and 8x8 for the
// hash, so aspect is not preserved — irrelevant for these
// heuristics, which only need overall structure, detail and light.
// A decode failure returns null; the caller skips analysis for that
// asset instead of failing the whole scan.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'photo_analysis.dart';

/// Thumbnail edge requested from MediaService for analysis. Small on
/// purpose: analysis needs structure, not pixels, and a small
/// thumbnail keeps scans cheap on large libraries.
const int analysisThumbnailSize = 128;

/// Builds the analysis for one asset from its thumbnail bytes, or
/// null when the bytes do not decode (corrupt/unsupported format).
/// [width]/[height] are the asset's real dimensions from MediaAsset,
/// used for the exact-duplicate rule — not the thumbnail's size.
/// [sizeBytes]/[modifiedDateMs] are fingerprinted onto the
/// analysis (solutions 5.3) so a rescan can tell whether the
/// cached entry still describes the file.
PhotoAnalysis? analyzeThumbnail({
  required String assetId,
  required Uint8List bytes,
  required int width,
  required int height,
  int? sizeBytes,
  int? modifiedDateMs,
}) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }
  final List<double> gray64 = _grayscale(decoded, blurGridSize);
  final List<double> gray8 = _grayscale(decoded, hashGridSize);
  return PhotoAnalysis(
    assetId: assetId,
    hash: averageHash(gray8),
    width: width,
    height: height,
    blurScore: laplacianVariance(gray64, blurGridSize),
    meanLuminance: meanLuminance(gray64),
    sizeBytes: sizeBytes,
    modifiedDateMs: modifiedDateMs,
  );
}

/// Grayscale grid of side [size] from [image]: resize, then Rec. 601
/// luminance per pixel, row-major. Resizing first is what makes the
/// hash and blur scores resolution-independent.
List<double> _grayscale(img.Image image, int size) {
  final img.Image small = img.copyResize(image, width: size, height: size);
  final List<double> gray = <double>[];
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final img.Pixel pixel = small.getPixel(x, y);
      gray.add(0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
    }
  }
  return gray;
}
