// Detection engine tests (requirements §7, Phase 2A): hash
// behaviour, blur/dark scoring on synthetic images, thumbnail
// decoding, and the exact-duplicate rule.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';

List<double> _grid(int Function(int x, int y) value) {
  final List<double> grid = <double>[];
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      grid.add(value(x, y).toDouble());
    }
  }
  return grid;
}

img.Image _image(int size, int Function(int x, int y) value) {
  final img.Image image = img.Image(width: size, height: size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int v = value(x, y);
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

void main() {
  group('averageHash', () {
    test('identical grids hash identically', () {
      final List<double> a = _grid((int x, int y) => x * 32);
      final List<double> b = _grid((int x, int y) => x * 32);
      expect(averageHash(a), averageHash(b));
    });

    test('clearly different grids hash differently', () {
      final List<double> dark = _grid((_, _) => 0);
      final List<double> halfBright = _grid((int x, _) => x < 4 ? 0 : 255);
      expect(averageHash(dark), isNot(averageHash(halfBright)));
    });

    test('hamming distance counts differing bits', () {
      expect(hammingDistance(0, 0), 0);
      expect(hammingDistance(0, 7), 3);
      expect(hammingDistance(10, 12), 2);
    });
  });

  group('blur and dark scores', () {
    test('uniform grid scores zero blur and flags blurry', () {
      final List<double> gray = List<double>.filled(64 * 64, 128);
      expect(laplacianVariance(gray, 64), 0);
      expect(
        const PhotoAnalysis(
          assetId: 'u',
          hash: 0,
          width: 10,
          height: 10,
          blurScore: 0,
          meanLuminance: 128,
        ).isBlurry,
        isTrue,
      );
    });

    test('sharp checkerboard scores far above the blur threshold', () {
      final List<double> gray = <double>[];
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
          gray.add((((x ~/ 8) + (y ~/ 8)) % 2 == 0) ? 255 : 0);
        }
      }
      expect(laplacianVariance(gray, 64), greaterThan(blurThreshold));
    });

    test('dark threshold splits black from bright frames', () {
      const PhotoAnalysis dark = PhotoAnalysis(
        assetId: 'd',
        hash: 0,
        width: 10,
        height: 10,
        blurScore: 0,
        meanLuminance: 12,
      );
      const PhotoAnalysis bright = PhotoAnalysis(
        assetId: 'b',
        hash: 0,
        width: 10,
        height: 10,
        blurScore: 500,
        meanLuminance: 200,
      );
      expect(dark.isDark, isTrue);
      expect(bright.isDark, isFalse);
    });
  });

  group('exact duplicates', () {
    test('same hash and dimensions are exact duplicates', () {
      const PhotoAnalysis a = PhotoAnalysis(
        assetId: 'a',
        hash: 42,
        width: 100,
        height: 200,
        blurScore: 10,
        meanLuminance: 50,
      );
      const PhotoAnalysis b = PhotoAnalysis(
        assetId: 'b',
        hash: 42,
        width: 100,
        height: 200,
        blurScore: 20,
        meanLuminance: 60,
      );
      expect(a.isExactDuplicateOf(b), isTrue);
    });

    test('same hash but different dimensions are only similar', () {
      const PhotoAnalysis a = PhotoAnalysis(
        assetId: 'a',
        hash: 42,
        width: 100,
        height: 200,
        blurScore: 10,
        meanLuminance: 50,
      );
      const PhotoAnalysis b = PhotoAnalysis(
        assetId: 'b',
        hash: 42,
        width: 50,
        height: 100,
        blurScore: 20,
        meanLuminance: 60,
      );
      expect(a.isExactDuplicateOf(b), isFalse);
    });
  });

  group('analyzeThumbnail', () {
    test('identical bytes give identical analyses', () {
      final Uint8List bytes = Uint8List.fromList(
        img.encodePng(
          _image(
            64,
            (int x, int y) => ((x ~/ 8) + (y ~/ 8)) % 2 == 0 ? 255 : 0,
          ),
        ),
      );
      final PhotoAnalysis? a = analyzeThumbnail(
        assetId: 'a',
        bytes: bytes,
        width: 64,
        height: 64,
      );
      final PhotoAnalysis? b = analyzeThumbnail(
        assetId: 'b',
        bytes: bytes,
        width: 64,
        height: 64,
      );
      expect(a, isNotNull);
      expect(a!.hash, b!.hash);
      expect(a.blurScore, b.blurScore);
      expect(a.meanLuminance, b.meanLuminance);
    });

    test('a dark frame analyses as dark, a bright one does not', () {
      final Uint8List darkBytes = Uint8List.fromList(
        img.encodePng(_image(64, (_, _) => 5)),
      );
      final Uint8List brightBytes = Uint8List.fromList(
        img.encodePng(_image(64, (_, _) => 240)),
      );
      final PhotoAnalysis? dark = analyzeThumbnail(
        assetId: 'd',
        bytes: darkBytes,
        width: 64,
        height: 64,
      );
      final PhotoAnalysis? bright = analyzeThumbnail(
        assetId: 'b',
        bytes: brightBytes,
        width: 64,
        height: 64,
      );
      expect(dark!.isDark, isTrue);
      expect(bright!.isDark, isFalse);
    });

    test('undecodable bytes return null instead of throwing', () {
      expect(
        analyzeThumbnail(
          assetId: 'x',
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          width: 10,
          height: 10,
        ),
        isNull,
      );
    });

    test('analysis JSON round-trips', () {
      const PhotoAnalysis original = PhotoAnalysis(
        assetId: 'a',
        hash: 12345,
        width: 100,
        height: 200,
        blurScore: 12.5,
        meanLuminance: 44.5,
      );
      final PhotoAnalysis restored = PhotoAnalysis.fromJson(original.toJson());
      expect(restored.assetId, 'a');
      expect(restored.hash, 12345);
      expect(restored.blurScore, 12.5);
      expect(restored.meanLuminance, 44.5);
    });
  });
}
