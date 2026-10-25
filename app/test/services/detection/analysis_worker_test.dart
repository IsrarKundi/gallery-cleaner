// Solutions 5.1: analysis batch worker — correctness against the
// UI-thread oracle, per-asset degradation, and the isolate path
// producing identical outputs. No device, no MediaStore: bytes
// are synthetic PNGs generated in-test.

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/photo_analysis.dart';
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
    width: 100,
    height: 100,
    sizeBytes: bytes.length,
  );
}

void main() {
  test('isolate batch equals the UI-thread oracle, asset for asset', () async {
    final List<Uint8List> bytes = <Uint8List>[
      _patternPng(1),
      _patternPng(2),
      _patternPng(3),
    ];
    final List<AnalysisBatchInput> inputs = <AnalysisBatchInput>[
      for (int i = 0; i < bytes.length; i++) _input('a$i', bytes[i]),
    ];
    final List<PhotoAnalysis?> fromIsolate = await analyzeBatchOnIsolate(
      inputs,
    );
    // The oracle: the same function the UI thread used to run.
    final List<PhotoAnalysis?> oracle = <PhotoAnalysis?>[
      for (int i = 0; i < bytes.length; i++)
        analyzeThumbnail(
          assetId: 'a$i',
          bytes: bytes[i],
          width: 100,
          height: 100,
        ),
    ];
    expect(fromIsolate.length, 3);
    for (int i = 0; i < 3; i++) {
      expect(fromIsolate[i], isNotNull);
      expect(fromIsolate[i]!.hash, oracle[i]!.hash);
      expect(fromIsolate[i]!.blurScore, oracle[i]!.blurScore);
      expect(fromIsolate[i]!.meanLuminance, oracle[i]!.meanLuminance);
    }
  });

  test('one corrupt entry degrades to null, the rest still compute', () async {
    final List<AnalysisBatchInput> inputs = <AnalysisBatchInput>[
      _input('good-1', _patternPng(1)),
      _input('bad', Uint8List.fromList(<int>[0, 1, 2, 3, 4])),
      _input('good-2', _patternPng(2)),
    ];
    final List<PhotoAnalysis?> results = await analyzeBatchOnIsolate(inputs);
    expect(results[0], isNotNull);
    expect(results[1], isNull);
    expect(results[2], isNotNull);
    // The sync fallback path degrades identically.
    final List<AnalysisBatchInput> syncInputs = <AnalysisBatchInput>[
      _input('good-1', _patternPng(1)),
      _input('bad', Uint8List.fromList(<int>[0, 1, 2, 3, 4])),
      _input('good-2', _patternPng(2)),
    ];
    final List<PhotoAnalysis?> syncResults = analyzeBatchSync(syncInputs);
    expect(syncResults[0], isNotNull);
    expect(syncResults[1], isNull);
    expect(syncResults[2], isNotNull);
    expect(syncResults[0]!.hash, results[0]!.hash);
    expect(syncResults[2]!.hash, results[2]!.hash);
  });

  test('empty batch is an empty result, not an isolate error', () async {
    expect(await analyzeBatchOnIsolate(<AnalysisBatchInput>[]), isEmpty);
  });
}
