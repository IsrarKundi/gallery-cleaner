// Blur detection (fix plan Stage 4, requirements §7): our own
// Dart implementation of the three gradient-domain measures the
// Cleanup teardown recovered BY NAME (notes/algorithms.md §4 —
// reblur, edgeWidth, coherence). Cleanup computes them in native
// code; the exact native formulas are UNKNOWN (the teardown had
// no AArch64 disassembler), so the definitions below are the
// classic measures those names denote, written here and open to
// inspection — they are wipe.'s definitions, not a claim about
// Cleanup's internals.
//
// The SCORE is the teardown's formula with the plan's fallback
// weights (Cleanup's live values are server-side, UNKNOWN):
//   score = 2.3 * reblur + 1.0 * edgeWidth + 0.75 * coherence
// The LINE is wipe.'s own: Stage 4 shipped Cleanup's fallback
// 2.2, whose sample validation flagged sharp photos too; the
// owner set the line at 4.2 on 30 Oct 2026 (ADR-023).
//   blurry  <=>  score >= 4.2
// Missing measures count as 0, and when BOTH reblur and edgeWidth
// are unavailable the photo is NOT flagged (the teardown's null
// rule). A photo is read at a small size for this pass: the
// caller fetches a 512 px thumbnail (Cleanup's analysis size).
//
// Measure definitions (all on the grayscale raster, forward
// differences gx = I[x+1]-I[x], gy = I[y+1]-I[y], magnitude
// m = sqrt(gx*gx + gy*gy); an "edge pixel" is a pixel whose
// magnitude reaches [edgeThresholdFraction] of the raster's peak
// magnitude, floored at [edgeThresholdFloor]):
// - edgeWidth: the mean length of runs of edge pixels, scanned
//   by rows and by columns and averaged (runs are capped at
//   [maxEdgeRun] so a smooth ramp cannot dominate). A perfect
//   step edge is 1 px wide; blur spreads it over more pixels.
// - reblur: the image is blurred once more (Gaussian, radius
//   [reblurRadius]) and gradients are recomputed; reblur is the
//   mean, over edge pixels, of magnitude-after / magnitude-
//   before. An already-blurred edge survives re-blurring better
//   (ratio near 1) than a sharp edge (ratio well under 1).
// - coherence: the mean, over edge pixels, of the structure-
//   tensor coherence sqrt((Sxx-Syy)^2 + 4*Sxy^2) / (Sxx+Syy)
//   over a 5x5 window — how aligned the local gradients are.

import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Cleanup's fallback weights (plan Stage 4; their live values
/// are server-side and UNKNOWN — see file doc).
const double blurReblurWeight = 2.3;
const double blurCoherenceWeight = 0.75;

/// The blur line: wipe.'s own, set by the owner at 4.2
/// (ADR-023). Stage 4 shipped Cleanup's fallback 2.2, which
/// flagged the sharp validation samples too (2.62–3.78); 4.2
/// separates them from radius ≥ 2 blur on those samples
/// (min 4.54) and accepts missing very light (radius-1) blur.
const double blurScoreThreshold = 4.2;

/// Edge pixels: magnitude at least this fraction of the peak.
const double edgeThresholdFraction = 0.2;

/// Edge pixels: magnitude at least this absolute floor (0-255
/// gradient scale), so a flat raster has no edges at all. Kept
/// at one gray level on purpose: a genuinely blurred photo's
/// gradients are weak everywhere, and a high floor would leave
/// it with no measurable edges — Cleanup's null case is the
/// flat frame, not the soft one.
const double edgeThresholdFloor = 1.0;

/// Radius of the extra Gaussian blur behind the reblur measure.
const int reblurRadius = 2;

/// Edge runs longer than this are capped (smooth ramps).
const int maxEdgeRun = 32;

/// Edge pixels sampled for the reblur / coherence means (evenly
/// spaced), so a 512 px texture-heavy photo stays cheap.
const int maxEdgeSamples = 4096;

/// The three measures + the combined decision for one photo.
/// A null measure is "unavailable" (Cleanup's sentinel): it
/// counts as 0 in the score, except that reblur AND edgeWidth
/// both null means not blurry at all.
class BlurAssessment {
  const BlurAssessment({this.reblur, this.edgeWidth, this.coherence});

  final double? reblur;
  final double? edgeWidth;
  final double? coherence;

  /// The combined score, or null when it cannot be formed
  /// (reblur and edgeWidth both unavailable).
  double? get score {
    if (reblur == null && edgeWidth == null) {
      return null;
    }
    return blurReblurWeight * (reblur ?? 0) +
        (edgeWidth ?? 0) +
        blurCoherenceWeight * (coherence ?? 0);
  }

  bool get isBlurry {
    final double? value = score;
    return value != null && value >= blurScoreThreshold;
  }
}

/// Computes the blur measures for a decoded image. The image is
/// first reduced to fit within [analysisSize] px (aspect kept),
/// matching Cleanup's 512 analysis size; callers pass the 512 px
/// thumbnail decode, so this resize is normally a no-op or a
/// small correction. Pure and isolate-safe.
BlurAssessment assessBlur(img.Image decoded, {int analysisSize = 512}) {
  img.Image image = decoded;
  if (image.width > analysisSize || image.height > analysisSize) {
    if (image.width >= image.height) {
      image = img.copyResize(
        image,
        width: analysisSize,
        interpolation: img.Interpolation.average,
      );
    } else {
      image = img.copyResize(
        image,
        height: analysisSize,
        interpolation: img.Interpolation.average,
      );
    }
  }
  final int w = image.width;
  final int h = image.height;
  if (w < 3 || h < 3) {
    return const BlurAssessment();
  }
  final List<double> gray = _grayscale(image, w, h);
  final _Gradients gradients = _Gradients.compute(gray, w, h);
  final List<int> edges = gradients.edgePixels();
  if (edges.isEmpty) {
    // No edges: reblur and edgeWidth are unavailable, so the
    // teardown's null rule applies — not flagged.
    return const BlurAssessment();
  }
  final double edgeWidth = gradients.meanEdgeRunLength();
  // The re-blurred raster: gradients recomputed after one known
  // extra blur, compared at the SAME edge pixels.
  final img.Image blurred = img.gaussianBlur(
    img.grayscale(image.clone()),
    radius: reblurRadius,
  );
  final List<double> blurredGray = _grayscale(blurred, w, h);
  final _Gradients blurredGradients = _Gradients.compute(blurredGray, w, h);
  final List<int> samples = _sampleEdges(edges);
  double ratioSum = 0;
  int ratioCount = 0;
  double coherenceSum = 0;
  int coherenceCount = 0;
  for (final int index in samples) {
    final double before = gradients.magnitudes[index];
    if (before > 0) {
      ratioSum += blurredGradients.magnitudes[index] / before;
      ratioCount++;
    }
    final double? coherence = gradients.coherenceAt(index, w, h);
    if (coherence != null) {
      coherenceSum += coherence;
      coherenceCount++;
    }
  }
  return BlurAssessment(
    reblur: ratioCount == 0 ? null : ratioSum / ratioCount,
    edgeWidth: edgeWidth,
    coherence: coherenceCount == 0 ? null : coherenceSum / coherenceCount,
  );
}

/// Evenly spaced sample of [edges], at most [maxEdgeSamples].
List<int> _sampleEdges(List<int> edges) {
  if (edges.length <= maxEdgeSamples) {
    return edges;
  }
  final List<int> out = <int>[];
  final double step = edges.length / maxEdgeSamples;
  for (int i = 0; i < maxEdgeSamples; i++) {
    out.add(edges[(i * step).floor()]);
  }
  return out;
}

/// Rec. 601 luminance per pixel, row-major.
List<double> _grayscale(img.Image image, int w, int h) {
  final List<double> gray = List<double>.filled(w * h, 0);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final img.Pixel pixel = image.getPixel(x, y);
      gray[y * w + x] = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    }
  }
  return gray;
}

/// Forward-difference gradient field over a grayscale raster.
class _Gradients {
  _Gradients._(this.gx, this.gy, this.magnitudes, this.peak, this.w, this.h);

  factory _Gradients.compute(List<double> gray, int w, int h) {
    final List<double> gx = List<double>.filled(w * h, 0);
    final List<double> gy = List<double>.filled(w * h, 0);
    final List<double> magnitudes = List<double>.filled(w * h, 0);
    double peak = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = y * w + x;
        final double dx = x + 1 < w ? gray[i + 1] - gray[i] : 0;
        final double dy = y + 1 < h ? gray[i + w] - gray[i] : 0;
        gx[i] = dx;
        gy[i] = dy;
        final double m = math.sqrt(dx * dx + dy * dy);
        magnitudes[i] = m;
        if (m > peak) {
          peak = m;
        }
      }
    }
    return _Gradients._(gx, gy, magnitudes, peak, w, h);
  }

  final List<double> gx;
  final List<double> gy;
  final List<double> magnitudes;
  final double peak;
  final int w;
  final int h;

  double get threshold =>
      math.max(edgeThresholdFloor, edgeThresholdFraction * peak);

  /// Indices of edge pixels (magnitude at or over [threshold]).
  List<int> edgePixels() {
    final double t = threshold;
    if (peak <= 0) {
      return const <int>[];
    }
    final List<int> out = <int>[];
    for (int i = 0; i < magnitudes.length; i++) {
      if (magnitudes[i] >= t) {
        out.add(i);
      }
    }
    return out;
  }

  /// Mean run length of edge pixels, rows and columns averaged.
  /// The caller guarantees at least one edge pixel exists.
  double meanEdgeRunLength() {
    final double t = threshold;
    int runTotal = 0;
    int runCount = 0;
    void scanLine(int length, int Function(int) at) {
      int run = 0;
      for (int i = 0; i < length; i++) {
        if (magnitudes[at(i)] >= t) {
          run++;
        } else if (run > 0) {
          runTotal += math.min(run, maxEdgeRun);
          runCount++;
          run = 0;
        }
      }
      if (run > 0) {
        runTotal += math.min(run, maxEdgeRun);
        runCount++;
      }
    }

    for (int y = 0; y < h; y++) {
      scanLine(w, (int x) => y * w + x);
    }
    for (int x = 0; x < w; x++) {
      scanLine(h, (int y) => y * w + x);
    }
    return runCount == 0 ? 0 : runTotal / runCount;
  }

  /// Structure-tensor coherence in the 5x5 window around the
  /// pixel at [index], or null when the window has no gradient
  /// energy at all.
  double? coherenceAt(int index, int w, int h) {
    final int cx = index % w;
    final int cy = index ~/ w;
    double sxx = 0;
    double syy = 0;
    double sxy = 0;
    for (int y = math.max(0, cy - 2); y <= math.min(h - 1, cy + 2); y++) {
      for (int x = math.max(0, cx - 2); x <= math.min(w - 1, cx + 2); x++) {
        final int i = y * w + x;
        sxx += gx[i] * gx[i];
        syy += gy[i] * gy[i];
        sxy += gx[i] * gy[i];
      }
    }
    final double energy = sxx + syy;
    if (energy <= 0) {
      return null;
    }
    final double a = sxx - syy;
    return math.sqrt(a * a + 4 * sxy * sxy) / energy;
  }
}
