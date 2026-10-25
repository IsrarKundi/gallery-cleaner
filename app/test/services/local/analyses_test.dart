// Hash-cache round-trip + merge (requirements §7, Phase 2A):
// saving analyses merges into the cache file without dropping
// existing entries, and loading returns them by asset id.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service_impl.dart';

void main() {
  group('LocalServiceImpl analyses cache', () {
    test('save merges and load returns by id', () async {
      final Directory dir = await Directory.systemTemp.createTemp();
      final LocalServiceImpl service = LocalServiceImpl(
        directoryResolver: () async => dir,
      );
      const PhotoAnalysis first = PhotoAnalysis(
        assetId: 'a',
        hash: 11,
        width: 10,
        height: 10,
        blurScore: 12,
        meanLuminance: 44,
      );
      const PhotoAnalysis second = PhotoAnalysis(
        assetId: 'b',
        hash: 22,
        width: 20,
        height: 20,
        blurScore: 500,
        meanLuminance: 200,
      );
      expect(
        (await service.saveAnalyses(<PhotoAnalysis>[first])).isSuccess,
        isTrue,
      );
      expect(
        (await service.saveAnalyses(<PhotoAnalysis>[second])).isSuccess,
        isTrue,
      );
      final Result<Map<String, PhotoAnalysis>> loaded = await service
          .loadAnalyses();
      expect(loaded.isSuccess, isTrue);
      final Map<String, PhotoAnalysis> map = loaded.fold(
        onSuccess: (Map<String, PhotoAnalysis> value) => value,
        onFailure: (_) => throw StateError('expected success'),
      );
      expect(map.length, 2);
      expect(map['a']!.hash, 11);
      expect(map['b']!.blurScore, 500);
      // Overwriting one id keeps the other.
      const PhotoAnalysis updated = PhotoAnalysis(
        assetId: 'a',
        hash: 99,
        width: 10,
        height: 10,
        blurScore: 1,
        meanLuminance: 1,
      );
      await service.saveAnalyses(<PhotoAnalysis>[updated]);
      final Map<String, PhotoAnalysis> reloaded = (await service.loadAnalyses())
          .fold(
            onSuccess: (Map<String, PhotoAnalysis> value) => value,
            onFailure: (_) => throw StateError('expected success'),
          );
      expect(reloaded['a']!.hash, 99);
      expect(reloaded['b']!.hash, 22);
      await dir.delete(recursive: true);
    });

    test('empty cache loads as an empty map', () async {
      final Directory dir = await Directory.systemTemp.createTemp();
      final LocalServiceImpl service = LocalServiceImpl(
        directoryResolver: () async => dir,
      );
      final Result<Map<String, PhotoAnalysis>> loaded = await service
          .loadAnalyses();
      expect(loaded.isSuccess, isTrue);
      expect(
        loaded.fold(
          onSuccess: (Map<String, PhotoAnalysis> value) => value,
          onFailure: (_) => throw StateError('expected success'),
        ),
        isEmpty,
      );
      await dir.delete(recursive: true);
    });
  });
}
