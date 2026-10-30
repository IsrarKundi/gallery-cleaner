// Stage 4 batch workers: the isolate runners must equal the
// sync oracle asset for asset (fingerprints AND blur), and one
// corrupt entry degrades to null for that asset only. No
// device, no MediaStore: bytes are synthetic PNGs.

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/blur_detection.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';

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

AnalysisBatchInput _input(String id, Uint8List bytes) {
  return AnalysisBatchInput(
    assetId: id,
    bytes: TransferableTypedData.fromList(<Uint8List>[bytes]),
  );
}

List<AnalysisBatchInput> _inputs(List<Uint8List> all) {
  return <AnalysisBatchInput>[
    for (int i = 0; i < all.length; i++) _input('a$i', all[i]),
  ];
}

void main() {
  test('fingerprint isolate batch equals the sync oracle', () async {
    final List<Uint8List> bytes = <Uint8List>[
      _patternPng(1),
      _patternPng(2),
      _patternPng(3),
    ];
    final List<FingerprintComputation?> fromIsolate =
        await fingerprintBatchOnIsolate(_inputs(bytes));
    final List<FingerprintComputation?> oracle = <FingerprintComputation?>[
      for (final Uint8List b in bytes) computeFingerprint(b),
    ];
    expect(fromIsolate.length, 3);
    for (int i = 0; i < 3; i++) {
      expect(fromIsolate[i], isNotNull);
      expect(fromIsolate[i]!.fingerprint.dHash, oracle[i]!.fingerprint.dHash);
      expect(
        fromIsolate[i]!.fingerprint.colorHistogram,
        oracle[i]!.fingerprint.colorHistogram,
      );
      expect(fromIsolate[i]!.meanLuminance, oracle[i]!.meanLuminance);
    }
  });

  test('blur isolate batch equals the sync oracle', () async {
    final List<Uint8List> bytes = <Uint8List>[_patternPng(1), _patternPng(2)];
    final List<BlurAssessment?> fromIsolate = await blurBatchOnIsolate(
      _inputs(bytes),
    );
    for (int i = 0; i < 2; i++) {
      expect(fromIsolate[i]?.score, computeBlur(bytes[i])?.score);
      expect(fromIsolate[i]?.reblur, computeBlur(bytes[i])?.reblur);
    }
  });

  test('one corrupt entry degrades to null, the rest still compute', () async {
    final List<Uint8List> bytes = <Uint8List>[
      _patternPng(1),
      Uint8List.fromList(<int>[0, 1, 2, 3, 4]),
      _patternPng(2),
    ];
    final List<FingerprintComputation?> results =
        await fingerprintBatchOnIsolate(_inputs(bytes));
    expect(results[0], isNotNull);
    expect(results[1], isNull);
    expect(results[2], isNotNull);
    // The sync fallback path degrades identically.
    final List<FingerprintComputation?> syncResults = fingerprintBatchSync(
      _inputs(bytes),
    );
    expect(syncResults[0], isNotNull);
    expect(syncResults[1], isNull);
    expect(syncResults[2], isNotNull);
    expect(syncResults[0]!.fingerprint.dHash, results[0]!.fingerprint.dHash);
  });

  test('empty batches are empty results, not isolate errors', () async {
    expect(await fingerprintBatchOnIsolate(<AnalysisBatchInput>[]), isEmpty);
    expect(await blurBatchOnIsolate(<AnalysisBatchInput>[]), isEmpty);
  });
}
