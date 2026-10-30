// Stage 4 blur measures on synthetic images (requirements §7):
// flat colour (Cleanup's no-measures rule), sharp edges and
// blurred edges must order as expected under the fallback score
// 2.3*reblur + 1.0*edgeWidth + 0.75*coherence, blurry at >= 4.2
// (wipe.'s owner-set line, ADR-023).
// The three native measure formulas are Cleanup-side UNKNOWN
// (algorithms.md §4) — these tests pin OUR implementation's
// behaviour, not Cleanup's numbers.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/blur_detection.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';

img.Image _flat(int size, int v) {
  final img.Image image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(v, v, v));
  return image;
}

img.Image _step(int size) {
  final img.Image image = img.Image(width: size, height: size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int v = x < size ~/ 2 ? 0 : 255;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

img.Image _texture(int size, {int block = 4}) {
  final img.Image image = img.Image(width: size, height: size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int v = ((x ~/ block) + (y ~/ block)) % 2 == 0 ? 230 : 25;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

void main() {
  group('assessBlur', () {
    test('flat colour has no measures and is never flagged', () {
      final BlurAssessment a = assessBlur(_flat(64, 128));
      expect(a.reblur, isNull);
      expect(a.edgeWidth, isNull);
      expect(a.coherence, isNull);
      expect(a.score, isNull);
      expect(a.isBlurry, isFalse);
    });

    test('blurred edges score strictly above sharp edges', () {
      final BlurAssessment sharp = assessBlur(_step(128));
      final BlurAssessment blurred = assessBlur(
        img.gaussianBlur(_step(128), radius: 6),
      );
      expect(sharp.score, isNotNull);
      expect(blurred.score, isNotNull);
      expect(blurred.score!, greaterThan(sharp.score!));
      // Each measure moves the expected way on its own.
      expect(blurred.edgeWidth!, greaterThan(sharp.edgeWidth!));
      expect(blurred.reblur!, greaterThan(sharp.reblur!));
    });

    test('a heavily blurred texture is flagged blurry', () {
      // Photo-scale blocks: at the old fixture's 4 px blocks a
      // radius-8 blur flattens the texture to near-uniform
      // (score 2.30 — the measures' extreme-blur flattening,
      // close to the flat-frame null case), so it cannot stand
      // for a blurred photo under the 4.2 line (ADR-023). At
      // 16 px blocks the same radius-8 blur leaves wide soft
      // edges and scores 22.1.
      final BlurAssessment blurred = assessBlur(
        img.gaussianBlur(_texture(128, block: 16), radius: 8),
      );
      expect(blurred.score, greaterThan(blurScoreThreshold));
      expect(blurred.isBlurry, isTrue);
    });

    test('score composes with the Cleanup fallback weights', () {
      const BlurAssessment a = BlurAssessment(
        reblur: 0.5,
        edgeWidth: 2,
        coherence: 0.4,
      );
      expect(a.score, closeTo(2.3 * 0.5 + 2 + 0.75 * 0.4, 1e-9));
    });

    test('missing values count as 0 unless both leads are null', () {
      const BlurAssessment partial = BlurAssessment(edgeWidth: 3);
      expect(partial.score, closeTo(3, 1e-9));
      const BlurAssessment none = BlurAssessment(coherence: 0.9);
      // Both reblur and edgeWidth null: no score at all
      // (Cleanup's rule), however high the coherence.
      expect(none.score, isNull);
      expect(none.isBlurry, isFalse);
    });

    test('the blur threshold is wipe.\'s owner-set 4.2 (ADR-023)', () {
      expect(blurScoreThreshold, 4.2);
      const BlurAssessment at = BlurAssessment(edgeWidth: blurScoreThreshold);
      expect(at.isBlurry, isTrue);
      const BlurAssessment under = BlurAssessment(
        edgeWidth: blurScoreThreshold - 0.01,
      );
      expect(under.isBlurry, isFalse);
    });
  });

  group('computeBlur (bytes entry point)', () {
    test('undecodable bytes return null', () {
      expect(computeBlur(Uint8List.fromList(<int>[9, 9, 9])), isNull);
    });

    test('a sharp PNG computes the same as the decoded image', () {
      final Uint8List bytes = Uint8List.fromList(img.encodePng(_step(64)));
      final BlurAssessment? viaBytes = computeBlur(bytes);
      final BlurAssessment direct = assessBlur(_step(64));
      expect(viaBytes, isNotNull);
      expect(viaBytes!.score, direct.score);
    });
  });
}
