// Stage 4 fingerprint + compare-table tests (requirements §7):
// the two-part fingerprint's determinism, and EVERY band edge of
// Cleanup's compare table for both classes (algorithms.md §2.2):
// colour distance is truncated to a long before the band checks,
// the fast-accept band is checked first, then the bands in
// order — so a shared edge belongs to the first band containing
// the distance.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';

/// Fingerprint with an exact Hamming distance from the zero
/// hash: [d] low bits set.
PhotoFingerprint _print(int d, {double colour = 0}) {
  return PhotoFingerprint(
    dHash: d == 0 ? 0 : (1 << d) - 1,
    colorHistogram: <double>[colour, ...List<double>.filled(23, 0)],
  );
}

/// Pair at exact distance [d] and exact colour distance [c]:
/// the zero fingerprint vs [_print] (colour sits in band 0).
bool _similar(int d, double c, FingerprintClass assetClass) {
  final PhotoFingerprint a = _print(0);
  final PhotoFingerprint b = _print(d, colour: c);
  return areSimilar(a, b, assetClass);
}

Uint8List _patternPng(int seed) {
  final img.Image image = img.Image(width: 16, height: 16);
  for (int y = 0; y < 16; y++) {
    for (int x = 0; x < 16; x++) {
      final int v = (x * 17 + y * 31 + seed * 47) % 256;
      image.setPixelRgb(x, y, v, (v * 2) % 256, (255 - v) % 256);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('fingerprint computation', () {
    test('identical bytes give identical fingerprints', () {
      final Uint8List bytes = _patternPng(3);
      final FingerprintComputation a = computeFingerprint(bytes)!;
      final FingerprintComputation b = computeFingerprint(bytes)!;
      expect(a.fingerprint.dHash, b.fingerprint.dHash);
      expect(a.fingerprint.colorHistogram, b.fingerprint.colorHistogram);
      expect(a.fingerprint.isValid, isTrue);
    });

    test('different patterns hash differently', () {
      expect(
        computeFingerprint(_patternPng(1))!.fingerprint.dHash,
        isNot(computeFingerprint(_patternPng(2))!.fingerprint.dHash),
      );
    });

    test('colour histogram: 24 bands, each channel sums to 16', () {
      final img.Image red = img.Image(width: 16, height: 16);
      img.fill(red, color: img.ColorRgb8(255, 0, 0));
      final FingerprintComputation c = computeFingerprint(
        Uint8List.fromList(img.encodePng(red)),
      )!;
      final List<double> h = c.fingerprint.colorHistogram;
      expect(h.length, 24);
      for (int channel = 0; channel < 3; channel++) {
        final double sum = h
            .sublist(channel * 8, channel * 8 + 8)
            .fold<double>(0, (double a, double b) => a + b);
        expect(sum, closeTo(16, 1e-9), reason: 'channel $channel');
      }
      // Pure red: R in band 7 (255), G and B in band 0.
      expect(h[7], closeTo(16, 1e-9));
      expect(h[8], closeTo(16, 1e-9));
      expect(h[16], closeTo(16, 1e-9));
    });

    test('hamming distance counts differing bits', () {
      expect(hammingDistance(0, 0), 0);
      expect(hammingDistance(0, 7), 3);
      expect(hammingDistance(10, 12), 2);
      expect(hammingDistance(-1, -1), 0);
    });

    test('undecodable bytes return null', () {
      expect(computeFingerprint(Uint8List.fromList(<int>[1, 2, 3])), isNull);
    });

    test('mean luminance splits dark from bright frames', () {
      final img.Image dark = img.Image(width: 16, height: 16);
      img.fill(dark, color: img.ColorRgb8(5, 5, 5));
      final img.Image bright = img.Image(width: 16, height: 16);
      img.fill(bright, color: img.ColorRgb8(240, 240, 240));
      expect(
        computeFingerprint(Uint8List.fromList(img.encodePng(dark)))!
            .meanLuminance,
        lessThan(darkThreshold),
      );
      expect(
        computeFingerprint(Uint8List.fromList(img.encodePng(bright)))!
            .meanLuminance,
        greaterThan(darkThreshold),
      );
    });
  });

  group('validity gate', () {
    test('hash -1 is never similar, even to itself', () {
      const PhotoFingerprint bad = PhotoFingerprint(
        dHash: -1,
        colorHistogram: <double>[],
      );
      expect(areSimilar(bad, bad, FingerprintClass.photo), isFalse);
    });

    test('an empty colour matrix is never similar', () {
      const PhotoFingerprint empty = PhotoFingerprint(
        dHash: 0,
        colorHistogram: <double>[],
      );
      expect(areSimilar(empty, _print(0), FingerprintClass.photo), isFalse);
    });
  });

  group('photo compare table (d<18; fast 0-4; 4-10 C<=7; 10-18 C<=5)', () {
    test('fast-accept band ignores colour entirely', () {
      expect(_similar(0, 999, FingerprintClass.photo), isTrue);
      // d=4 is the shared edge: fast-accept is checked FIRST.
      expect(_similar(4, 999, FingerprintClass.photo), isTrue);
    });

    test('mid band edges at colour 7', () {
      expect(_similar(5, 7, FingerprintClass.photo), isTrue);
      expect(_similar(5, 8, FingerprintClass.photo), isFalse);
      // d=10 is the shared edge: the mid band contains it first.
      expect(_similar(10, 7, FingerprintClass.photo), isTrue);
      expect(_similar(10, 8, FingerprintClass.photo), isFalse);
    });

    test('high band edges at colour 5, distance capped below 18', () {
      expect(_similar(11, 5, FingerprintClass.photo), isTrue);
      expect(_similar(11, 6, FingerprintClass.photo), isFalse);
      expect(_similar(17, 5, FingerprintClass.photo), isTrue);
      expect(_similar(17, 6, FingerprintClass.photo), isFalse);
      expect(_similar(18, 0, FingerprintClass.photo), isFalse);
      expect(_similar(40, 0, FingerprintClass.photo), isFalse);
    });

    test('colour distance truncates before the band checks', () {
      expect(_similar(5, 7.99, FingerprintClass.photo), isTrue);
      expect(_similar(11, 5.99, FingerprintClass.photo), isTrue);
      expect(_similar(11, 6.0, FingerprintClass.photo), isFalse);
    });
  });

  group('screenshot compare table (d<16; fast 0-2; 2-10 C<=5; 10-16 C<=2)', () {
    test('fast-accept band ignores colour entirely', () {
      expect(_similar(0, 999, FingerprintClass.screenshot), isTrue);
      // d=2 is the shared edge: fast-accept is checked FIRST.
      expect(_similar(2, 999, FingerprintClass.screenshot), isTrue);
    });

    test('mid band edges at colour 5', () {
      expect(_similar(3, 5, FingerprintClass.screenshot), isTrue);
      expect(_similar(3, 6, FingerprintClass.screenshot), isFalse);
      // d=10 is the shared edge: the mid band contains it first.
      expect(_similar(10, 5, FingerprintClass.screenshot), isTrue);
      expect(_similar(10, 6, FingerprintClass.screenshot), isFalse);
    });

    test('high band edges at colour 2, distance capped below 16', () {
      expect(_similar(11, 2, FingerprintClass.screenshot), isTrue);
      expect(_similar(11, 3, FingerprintClass.screenshot), isFalse);
      expect(_similar(15, 2, FingerprintClass.screenshot), isTrue);
      expect(_similar(16, 0, FingerprintClass.screenshot), isFalse);
    });

    test('screenshots are stricter than photos at the same pair', () {
      // d=12, C=4: similar as photos, not as screenshots.
      expect(_similar(12, 4, FingerprintClass.photo), isTrue);
      expect(_similar(12, 4, FingerprintClass.screenshot), isFalse);
      // d=17: inside the photo cap, outside the screenshot cap.
      expect(_similar(17, 0, FingerprintClass.photo), isTrue);
      expect(_similar(17, 0, FingerprintClass.screenshot), isFalse);
    });

    test('colour distance truncates before the band checks', () {
      expect(_similar(11, 2.99, FingerprintClass.screenshot), isTrue);
      expect(_similar(3, 5.5, FingerprintClass.screenshot), isTrue);
    });
  });
}
