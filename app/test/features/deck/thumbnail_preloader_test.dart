// Phase 4.4: the preloader pauses on background — no new
// fetches start, in-flight deck fetches cancel — and resumes
// cleanly on foreground.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/model/thumbnail_preloader.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service.dart';

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 1),
    title: id,
    albumName: 'All',
  );
}

class _CountingThumbnails implements ThumbnailService {
  int prefetchCalls = 0;
  List<String> lastPrefetched = <String>[];
  int cancelOutsideCalls = 0;
  Set<ThumbnailKey> lastCancelWanted = <ThumbnailKey>{};

  @override
  RxMap<String, Uint8List> thumbnailsFor(int size, {int quality = 85}) =>
      <String, Uint8List>{}.obs;

  @override
  RxSet<String> failedFor(int size, {int quality = 85}) => <String>{}.obs;

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));

  @override
  void requestThumbnail(String assetId, int size, {int quality = 85}) {}

  @override
  void prefetch(List<String> ids, int size, {int quality = 85}) {
    prefetchCalls++;
    lastPrefetched = ids;
  }

  @override
  void cancelOutside(Set<ThumbnailKey> wanted) {
    cancelOutsideCalls++;
    lastCancelWanted = wanted;
  }

  @override
  void retry(String assetId, int size, {int quality = 85}) {}

  @override
  void clear() {}
}

class _NullMedia implements MediaService {
  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async =>
      const Success<List<MediaAlbum>>(<MediaAlbum>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async => const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));
}

void main() {
  test('preload window is current + next 3 while unpaused', () {
    final _CountingThumbnails service = _CountingThumbnails();
    final ThumbnailPreloader preloader = ThumbnailPreloader(
      media: _NullMedia(),
      service: service,
    );
    final List<MediaAsset> queue = <MediaAsset>[
      for (int i = 0; i < 10; i++) _asset('a$i'),
    ];
    preloader.preloadAround(queue, 2);
    expect(service.prefetchCalls, 1);
    expect(service.lastPrefetched, <String>['a2', 'a3', 'a4', 'a5']);
  });

  test('pause cancels in-flight fetches and blocks new ones', () {
    final _CountingThumbnails service = _CountingThumbnails();
    final ThumbnailPreloader preloader = ThumbnailPreloader(
      media: _NullMedia(),
      service: service,
    );
    final List<MediaAsset> queue = <MediaAsset>[
      for (int i = 0; i < 5; i++) _asset('a$i'),
    ];
    preloader.setPaused(true);
    expect(preloader.isPaused, isTrue);
    expect(service.cancelOutsideCalls, 1);
    expect(service.lastCancelWanted, isEmpty);
    preloader.preloadAround(queue, 0);
    expect(service.prefetchCalls, 0);

    // Pausing twice does not cancel twice.
    preloader.setPaused(true);
    expect(service.cancelOutsideCalls, 1);

    preloader.setPaused(false);
    expect(preloader.isPaused, isFalse);
    preloader.preloadAround(queue, 0);
    expect(service.prefetchCalls, 1);
    expect(service.lastPrefetched, <String>['a0', 'a1', 'a2', 'a3']);
  });
}
