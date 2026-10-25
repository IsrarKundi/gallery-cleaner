// Phase 2.3 tests: the shared thumbnail service contract.
//
// A counting fake media service proves the guarantees: one media
// call per (id, size) at most, synchronous in-flight dedup, one
// automatic retry, failed re-entry only, and dropped cancellations.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service_impl.dart';

class _CountingMedia implements MediaService {
  final List<ThumbnailKey> calls = <ThumbnailKey>[];

  /// Per-id script: results popped per call (empty = default success).
  final Map<String, List<Result<Uint8List>>> script =
      <String, List<Result<Uint8List>>>{};

  /// Optional slow path: ids whose fetch waits on this completer.
  final Map<String, Completer<Result<Uint8List>>> delayed =
      <String, Completer<Result<Uint8List>>>{};

  int callsFor(String id, int size) {
    return calls.where((ThumbnailKey k) => k.id == id && k.size == size).length;
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) {
    calls.add((id: assetId, size: size, quality: quality));
    final Completer<Result<Uint8List>>? pending = delayed[assetId];
    if (pending != null) {
      return pending.future;
    }
    final List<Result<Uint8List>>? queued = script[assetId];
    if (queued != null && queued.isNotEmpty) {
      return Future<Result<Uint8List>>.value(queued.removeAt(0));
    }
    return Future<Result<Uint8List>>.value(
      Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3])),
    );
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

Result<Uint8List> _failure() {
  return const Failure<Uint8List>(
    AppFailure(messageKey: AppStrings.errorMediaLoad),
  );
}

void main() {
  group('ThumbnailService', () {
    test('byte-cache hit costs zero media calls', () async {
      final _CountingMedia media = _CountingMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final Result<Uint8List> first = await service.getThumbnail('a', 512);
      final Result<Uint8List> second = await service.getThumbnail('a', 512);
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
      expect(media.callsFor('a', 512), 1);
      expect(service.thumbnailsFor(512).containsKey('a'), isTrue);
    });

    test('concurrent duplicate requests share one fetch', () async {
      final _CountingMedia media = _CountingMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final Future<Result<Uint8List>> one = service.getThumbnail('a', 512);
      final Future<Result<Uint8List>> two = service.getThumbnail('a', 512);
      expect((await one).isSuccess, isTrue);
      expect((await two).isSuccess, isTrue);
      expect(media.callsFor('a', 512), 1);
    });

    test('a hub build issues each (id, size) exactly once', () async {
      final _CountingMedia media = _CountingMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      for (final String id in <String>['a', 'b', 'c']) {
        service.requestThumbnail(id, 128);
        service.requestThumbnail(id, 256);
        // Rebuilds re-request: all must be deduped no-ops.
        service.requestThumbnail(id, 128);
        service.requestThumbnail(id, 256);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.calls.length, 6);
      expect(media.calls.toSet().length, 6);
    });

    test('a swipe burst issues no duplicate fetches', () async {
      final _CountingMedia media = _CountingMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      service.prefetch(<String>['a', 'b', 'c', 'd'], 512);
      service.prefetch(<String>['b', 'c', 'd', 'e'], 512);
      service.prefetch(<String>['c', 'd', 'e', 'f'], 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.calls.length, 6);
      for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) {
        expect(media.callsFor(id, 512), 1);
      }
    });

    test('one automatic retry rescues a transient failure', () async {
      final _CountingMedia media = _CountingMedia();
      media.script['x'] = <Result<Uint8List>>[
        _failure(),
        Success<Uint8List>(Uint8List.fromList(<int>[7])),
      ];
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final Result<Uint8List> result = await service.getThumbnail('x', 512);
      expect(result.isSuccess, isTrue);
      expect(media.callsFor('x', 512), 2);
      expect(service.failedFor(512).contains('x'), isFalse);
    });

    test('persistent failure marks failed; widget path never storms', () async {
      final _CountingMedia media = _CountingMedia();
      media.script['y'] = <Result<Uint8List>>[
        _failure(),
        _failure(),
        _failure(),
        _failure(),
      ];
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final Result<Uint8List> result = await service.getThumbnail('y', 512);
      expect(result.isFailure, isTrue);
      expect(media.callsFor('y', 512), 2);
      expect(service.failedFor(512).contains('y'), isTrue);
      // Widget rebuilds must not refetch a failed id.
      service.requestThumbnail('y', 512);
      service.requestThumbnail('y', 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.callsFor('y', 512), 2);
      // A controller request retries: two more calls (retry + retry).
      expect((await service.getThumbnail('y', 512)).isFailure, isTrue);
      expect(media.callsFor('y', 512), 4);
    });

    test('prefetch retries a failed id only on window re-entry', () async {
      final _CountingMedia media = _CountingMedia();
      media.script['c'] = <Result<Uint8List>>[
        _failure(),
        _failure(),
        _failure(),
        _failure(),
      ];
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      service.prefetch(<String>['a', 'b', 'c'], 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.callsFor('c', 512), 2);
      expect(service.failedFor(512).contains('c'), isTrue);
      // Unchanged window: no refetch.
      service.prefetch(<String>['a', 'b', 'c'], 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.callsFor('c', 512), 2);
      // Leaves, then re-enters: one more fetch attempt (with retry).
      service.prefetch(<String>['a', 'b'], 512);
      service.prefetch(<String>['a', 'b', 'c'], 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.callsFor('c', 512), 4);
    });

    test('explicit retry clears the failed mark for a refetch', () async {
      final _CountingMedia media = _CountingMedia();
      media.script['z'] = <Result<Uint8List>>[_failure(), _failure()];
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      expect((await service.getThumbnail('z', 512)).isFailure, isTrue);
      expect(service.failedFor(512).contains('z'), isTrue);
      service.retry('z', 512);
      expect(service.failedFor(512).contains('z'), isFalse);
      // The next widget request refetches (media now defaults to success).
      service.requestThumbnail('z', 512);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(media.callsFor('z', 512), 3);
      expect(service.thumbnailsFor(512).containsKey('z'), isTrue);
    });

    test('cancelled flights drop their bytes and their failure mark', () async {
      final _CountingMedia media = _CountingMedia();
      media.delayed['s'] = Completer<Result<Uint8List>>();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final Future<Result<Uint8List>> waiter = service.getThumbnail('s', 512);
      service.cancelOutside(<ThumbnailKey>{});
      media.delayed['s']!.complete(
        Success<Uint8List>(Uint8List.fromList(<int>[9])),
      );
      expect((await waiter).isFailure, isTrue);
      expect(service.thumbnailsFor(512).containsKey('s'), isFalse);
      expect(service.failedFor(512).contains('s'), isFalse);
    });

    test('the LRU bound evicts the oldest entry', () async {
      final _CountingMedia media = _CountingMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      for (int i = 0; i < 513; i++) {
        await service.getThumbnail('e$i', 512);
      }
      expect(service.thumbnailsFor(512).containsKey('e0'), isFalse);
      expect(service.thumbnailsFor(512).containsKey('e512'), isTrue);
      expect(service.thumbnailsFor(512).length, 512);
    });
  });
}
