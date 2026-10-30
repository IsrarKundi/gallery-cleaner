// Detection tests after Stage 4: the legacy PhotoAnalysis DTO
// still parses old caches (migration surface only), and the
// live entry points are computeFingerprint / computeBlur —
// their deep behaviour is pinned in fingerprint_test.dart and
// blur_detection_test.dart.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';

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
  group('legacy PhotoAnalysis (migration surface)', () {
    test('JSON round-trips', () {
      const PhotoAnalysis original = PhotoAnalysis(
        assetId: 'a',
        hash: 12345,
        width: 100,
        height: 200,
        blurScore: 12.5,
        meanLuminance: 44.5,
        sizeBytes: 1000,
        modifiedDateMs: 1700000000000,
      );
      final PhotoAnalysis restored = PhotoAnalysis.fromJson(original.toJson());
      expect(restored.assetId, 'a');
      expect(restored.hash, 12345);
      expect(restored.blurScore, 12.5);
      expect(restored.meanLuminance, 44.5);
      expect(restored.sizeBytes, 1000);
      expect(restored.modifiedDateMs, 1700000000000);
      expect(restored.algorithmVersion, analysisAlgorithmVersion);
    });

    test('entries written before versioning load as version 0', () {
      final PhotoAnalysis parsed = PhotoAnalysis.fromJson(<String, dynamic>{
        'assetId': 'a',
        'hash': 7,
        'width': 10,
        'height': 10,
        'blurScore': 500.0,
        'meanLuminance': 128.0,
      });
      expect(parsed.algorithmVersion, 0);
      expect(parsed.sizeBytes, isNull);
      expect(parsed.modifiedDateMs, isNull);
    });
  });

  group('byte entry points', () {
    test('identical bytes give identical fingerprints', () {
      final Uint8List bytes = Uint8List.fromList(
        img.encodePng(
          _image(
            64,
            (int x, int y) => ((x ~/ 8) + (y ~/ 8)) % 2 == 0 ? 255 : 0,
          ),
        ),
      );
      final FingerprintComputation a = computeFingerprint(bytes)!;
      final FingerprintComputation b = computeFingerprint(bytes)!;
      expect(a.fingerprint.dHash, b.fingerprint.dHash);
      expect(a.fingerprint.colorHistogram, b.fingerprint.colorHistogram);
      expect(a.meanLuminance, b.meanLuminance);
    });

    test('undecodable bytes return null from both entry points', () {
      final Uint8List junk = Uint8List.fromList(<int>[1, 2, 3, 4]);
      expect(computeFingerprint(junk), isNull);
      expect(computeBlur(junk), isNull);
    });
  });
}
