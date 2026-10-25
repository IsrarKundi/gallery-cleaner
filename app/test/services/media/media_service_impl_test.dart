// Phase 2.1 tests: the media-service query pattern.
//
// A counting fake gateway stands in for photo_manager, so these tests
// prove the caching guarantees without a platform channel:
// one path-list call per (type, month, albums) key, one count per
// path, one `fromId` per entity, and populated sizes in order.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_plugin_gateway.dart';
import 'package:klara/services/media/media_service_impl.dart';
import 'package:photo_manager/photo_manager.dart';

class _FakeGateway implements MediaPluginGateway {
  int pathListCalls = 0;
  int countCalls = 0;
  int pagedCalls = 0;
  int sizeCalls = 0;
  int entityCalls = 0;
  int thumbnailCalls = 0;

  PermissionState permission = PermissionState.authorized;

  List<AssetPathEntity> paths = <AssetPathEntity>[];
  Map<String, int> counts = <String, int>{};
  Map<String, List<AssetEntity>> pages = <String, List<AssetEntity>>{};
  Map<String, int> sizes = <String, int>{};
  Map<String, AssetEntity> entities = <String, AssetEntity>{};
  Map<String, Uint8List> thumbnails = <String, Uint8List>{};

  @override
  Future<PermissionState> requestPermission() async {
    return permission;
  }

  @override
  Future<void> presentLimited() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<AssetPathEntity>> getPathList({
    required RequestType type,
    FilterOptionGroup? filterOption,
  }) async {
    pathListCalls++;
    return paths;
  }

  @override
  Future<int> getCount(AssetPathEntity path) async {
    countCalls++;
    return counts[path.id] ?? 0;
  }

  @override
  Future<List<AssetEntity>> getPaged(
    AssetPathEntity path,
    int page,
    int size,
  ) async {
    pagedCalls++;
    final List<AssetEntity> all = pages[path.id] ?? <AssetEntity>[];
    final int start = page * size;
    if (start >= all.length) {
      return <AssetEntity>[];
    }
    return all.sublist(start, math.min(start + size, all.length));
  }

  @override
  Future<int> getFileSize(AssetEntity entity) async {
    sizeCalls++;
    return sizes[entity.id] ?? 0;
  }

  @override
  Future<AssetEntity?> getEntity(String id) async {
    entityCalls++;
    return entities[id];
  }

  @override
  Future<Uint8List?> getThumbnailBytes(
    AssetEntity entity,
    int size,
    int quality,
  ) async {
    thumbnailCalls++;
    return thumbnails[entity.id];
  }
}

AssetEntity _entity(String id, {int createDateSecond = 1700000000}) {
  return AssetEntity(
    id: id,
    typeInt: 1,
    width: 100,
    height: 100,
    title: '$id.jpg',
    createDateSecond: createDateSecond,
    relativePath: 'DCIM/Camera',
  );
}

void main() {
  late _FakeGateway gateway;
  late MediaServiceImpl service;

  setUp(() {
    gateway = _FakeGateway();
    gateway.paths = <AssetPathEntity>[
      AssetPathEntity(id: 'all', name: 'All', isAll: true),
      AssetPathEntity(id: 'cam', name: 'Camera'),
    ];
    gateway.counts = <String, int>{'all': 60, 'cam': 40};
    service = MediaServiceImpl(gateway: gateway);
  });

  group('path-list caching', () {
    test('getAssets calls the path list once per (type, month) key', () async {
      gateway.pages = <String, List<AssetEntity>>{
        'all': <AssetEntity>[_entity('a1'), _entity('a2')],
      };
      gateway.sizes = <String, int>{'a1': 10, 'a2': 20};

      final Result<List<MediaAsset>> first = await service.getAssets();
      final Result<List<MediaAsset>> second = await service.getAssets();
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
      expect(gateway.pathListCalls, 1);

      // A different month key is a different query shape: one more call.
      final Result<List<MediaAsset>> other = await service.getAssets(
        monthKey: '2026-10',
      );
      expect(other.isSuccess, isTrue);
      expect(gateway.pathListCalls, 2);
    });

    test('album change reuses the same path list', () async {
      gateway.pages = <String, List<AssetEntity>>{
        'all': <AssetEntity>[_entity('a1')],
        'cam': <AssetEntity>[_entity('c1')],
      };
      await service.getAssets();
      await service.getAssets(albumId: 'cam');
      expect(gateway.pathListCalls, 1);
    });
  });

  group('album counts', () {
    test('getAlbums counts each path once, then serves the cache', () async {
      final Result<List<MediaAlbum>> first = await service.getAlbums();
      final Result<List<MediaAlbum>> second = await service.getAlbums();
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
      expect(gateway.pathListCalls, 1);
      expect(gateway.countCalls, 2);
      final List<MediaAlbum> albums =
          (first as Success<List<MediaAlbum>>).value;
      expect(albums.map((MediaAlbum a) => a.count).toList(), <int>[60, 40]);
    });
  });

  group('file sizes', () {
    test('a 40-asset page returns every size, in order', () async {
      final List<AssetEntity> page = List<AssetEntity>.generate(
        40,
        (int i) => _entity('p$i'),
      );
      gateway.pages = <String, List<AssetEntity>>{'all': page};
      gateway.sizes = <String, int>{
        for (int i = 0; i < 40; i++) 'p$i': (i + 1) * 100,
      };
      final Result<List<MediaAsset>> result = await service.getAssets(
        pageSize: 50,
      );
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.length, 40);
      expect(
        assets.map((MediaAsset a) => a.sizeBytes).toList(),
        List<int>.generate(40, (int i) => (i + 1) * 100),
      );
      expect(gateway.sizeCalls, 40);
    });
  });

  group('permission-change invalidation', () {
    test('same permission keeps the cache, a change clears it', () async {
      await service.requestPermission();
      await service.getAlbums();
      expect(gateway.pathListCalls, 1);

      await service.requestPermission();
      await service.getAlbums();
      expect(gateway.pathListCalls, 1);

      gateway.permission = PermissionState.limited;
      await service.requestPermission();
      await service.getAlbums();
      expect(gateway.pathListCalls, 2);
      expect(gateway.countCalls, 4);
    });
  });

  group('entity cache', () {
    test('getThumbnail resolves fromId once, then serves the cache', () async {
      gateway.entities = <String, AssetEntity>{'x': _entity('x')};
      gateway.thumbnails = <String, Uint8List>{
        'x': Uint8List.fromList(<int>[1, 2, 3]),
      };
      expect((await service.getThumbnail('x', 512)).isSuccess, isTrue);
      expect((await service.getThumbnail('x', 512)).isSuccess, isTrue);
      expect(gateway.entityCalls, 1);
      expect(gateway.thumbnailCalls, 2);
    });

    test('getAssets populates the entity cache for thumbnails', () async {
      gateway.pages = <String, List<AssetEntity>>{
        'all': <AssetEntity>[_entity('a1')],
      };
      gateway.thumbnails = <String, Uint8List>{
        'a1': Uint8List.fromList(<int>[9]),
      };
      await service.getAssets();
      expect((await service.getThumbnail('a1', 512)).isSuccess, isTrue);
      expect(gateway.entityCalls, 0);
    });
  });

  group('getAssetsByIds (Phase 2.4)', () {
    test('resolves exact ids newest first, skipping gone + audio', () async {
      gateway.entities = <String, AssetEntity>{
        'old': _entity('old', createDateSecond: 1700000000),
        'new': _entity('new', createDateSecond: 1700100000),
        'aud': AssetEntity(
          id: 'aud',
          typeInt: 3,
          width: 100,
          height: 100,
          title: 'aud.mp3',
          createDateSecond: 1700200000,
          relativePath: 'Music',
        ),
      };
      gateway.sizes = <String, int>{'old': 11, 'new': 22, 'aud': 33};
      final Result<List<MediaAsset>> result = await service.getAssetsByIds(
        <String>['gone', 'old', 'aud', 'new'],
      );
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>[
        'new',
        'old',
      ]);
      expect(assets.map((MediaAsset a) => a.sizeBytes).toList(), <int>[22, 11]);
      // One fromId per miss; the audio id still resolved (then skipped).
      expect(gateway.entityCalls, 4);
    });

    test('entity-cache hit costs zero fromId calls', () async {
      gateway.pages = <String, List<AssetEntity>>{
        'all': <AssetEntity>[_entity('a1')],
      };
      gateway.entities = <String, AssetEntity>{'a1': _entity('a1')};
      await service.getAssets();
      gateway.entityCalls = 0;
      final Result<List<MediaAsset>> result = await service.getAssetsByIds(
        <String>['a1'],
      );
      expect(result.isSuccess, isTrue);
      expect(gateway.entityCalls, 0);
    });
  });

  group('preserved failures', () {
    test('invalid month key still fails, never widens to all dates', () async {
      final Result<List<MediaAsset>> result = await service.getAssets(
        monthKey: 'not-a-month',
      );
      expect(result.isFailure, isTrue);
      expect(gateway.pathListCalls, 0);
    });

    test('unknown album id still fails', () async {
      final Result<List<MediaAsset>> result = await service.getAssets(
        albumId: 'nope',
      );
      expect(result.isFailure, isTrue);
    });
  });
}
