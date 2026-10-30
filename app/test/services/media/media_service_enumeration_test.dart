// Fix plan Stage 2 (ADR-017): MediaServiceImpl served by the
// one-pass enumeration. A counting plugin fake stands behind
// the legacy path so these tests prove the enumeration path
// makes ZERO plugin calls — no path lists, no paged queries,
// and above all no per-asset fileSize calls — while pages,
// filters and id lookups return exactly what the plugin path
// returned. The fallback tests prove a failed pass (or an
// album the pass does not know) still serves through the
// legacy path, unchanged.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/media/enumerated_asset.dart';
import 'package:klara/services/media/library_enumeration_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_enumeration_gateway.dart';
import 'package:klara/services/media/media_plugin_gateway.dart';
import 'package:klara/services/media/media_service_impl.dart';
import 'package:photo_manager/photo_manager.dart';

class _FakePluginGateway implements MediaPluginGateway {
  int pathListCalls = 0;
  int countCalls = 0;
  int pagedCalls = 0;
  int sizeCalls = 0;
  int entityCalls = 0;

  PermissionState permission = PermissionState.authorized;

  List<AssetPathEntity> paths = <AssetPathEntity>[];
  Map<String, List<AssetEntity>> pages = <String, List<AssetEntity>>{};
  Map<String, int> sizes = <String, int>{};

  @override
  Future<PermissionState> requestPermission() async => permission;

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
    return 0;
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
    return null;
  }

  @override
  Future<Uint8List?> getThumbnailBytes(
    AssetEntity entity,
    int size,
    int quality,
  ) async => null;
}

class _FakeEnumerationGateway implements MediaEnumerationGateway {
  int imageCalls = 0;
  int videoCalls = 0;
  List<EnumeratedAsset> images = <EnumeratedAsset>[];
  List<EnumeratedAsset> videos = <EnumeratedAsset>[];
  bool fail = false;

  @override
  Future<List<EnumeratedAsset>> enumerateImages() async {
    imageCalls++;
    if (fail) {
      throw StateError('native query failed');
    }
    return images;
  }

  @override
  Future<List<EnumeratedAsset>> enumerateVideos() async {
    videoCalls++;
    if (fail) {
      throw StateError('native query failed');
    }
    return videos;
  }
}

EnumeratedAsset _row(
  String id, {
  MediaAssetType type = MediaAssetType.image,
  String title = '',
  String bucketId = '10',
  String bucketName = 'Camera',
  int sizeBytes = 0,
  int width = 100,
  int height = 100,
  int? storeWidth,
  int? storeHeight,
  int dateAddedSec = 1700000000,
  int dateTakenMs = 0,
  String? relativePath = 'DCIM/Camera',
  bool fileExists = true,
}) {
  return EnumeratedAsset(
    id: id,
    type: type,
    title: title.isEmpty ? '$id.jpg' : title,
    bucketId: bucketId,
    bucketName: bucketName,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    storeWidth: storeWidth ?? width,
    storeHeight: storeHeight ?? height,
    dateAddedSec: dateAddedSec,
    dateTakenMs: dateTakenMs,
    dateModifiedSec: 1700000000,
    isFavorite: false,
    relativePath: relativePath,
    fileExists: fileExists,
  );
}

AssetEntity _entity(String id) {
  return AssetEntity(
    id: id,
    typeInt: 1,
    width: 100,
    height: 100,
    title: '$id.jpg',
    createDateSecond: 1700000000,
    relativePath: 'DCIM/Camera',
  );
}

void main() {
  late _FakePluginGateway plugin;
  late _FakeEnumerationGateway enumerationGateway;
  late MediaServiceImpl service;

  setUp(() {
    plugin = _FakePluginGateway();
    plugin.paths = <AssetPathEntity>[
      AssetPathEntity(id: 'all', name: 'Recent', isAll: true),
      AssetPathEntity(id: 'cam', name: 'Camera'),
    ];
    enumerationGateway = _FakeEnumerationGateway();
    service = MediaServiceImpl(
      gateway: plugin,
      enumeration: LibraryEnumerationServiceImpl(gateway: enumerationGateway),
    );
  });

  void expectNoPluginCalls() {
    expect(plugin.pathListCalls, 0);
    expect(plugin.pagedCalls, 0);
    expect(plugin.sizeCalls, 0);
    expect(plugin.entityCalls, 0);
  }

  group('pages from the pass', () {
    test('sizes arrive with the pass — zero size calls', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        for (int i = 1; i <= 5; i++) _row('$i', sizeBytes: i * 100),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets(
        pageSize: 50,
      );
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      // Merged order is MediaStore id descending.
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>[
        '5',
        '4',
        '3',
        '2',
        '1',
      ]);
      expect(assets.map((MediaAsset a) => a.sizeBytes).toList(), <int>[
        500,
        400,
        300,
        200,
        100,
      ]);
      expectNoPluginCalls();
      expect(enumerationGateway.imageCalls, 1);
      expect(enumerationGateway.videoCalls, 1);
    });

    test('later pages slice the same memoised pass', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        for (int i = 1; i <= 5; i++) _row('$i'),
      ];
      final Result<List<MediaAsset>> page1 = await service.getAssets(
        page: 1,
        pageSize: 2,
      );
      final List<MediaAsset> assets =
          (page1 as Success<List<MediaAsset>>).value;
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>['3', '2']);
      final Result<List<MediaAsset>> page3 = await service.getAssets(
        page: 3,
        pageSize: 2,
      );
      expect((page3 as Success<List<MediaAsset>>).value, isEmpty);
      // Still exactly one pass behind all three reads.
      expect(enumerationGateway.imageCalls, 1);
      expect(enumerationGateway.videoCalls, 1);
      expectNoPluginCalls();
    });

    test('gone files are skipped, as the plugin skipped them', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('2'),
        _row('1', fileExists: false),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets();
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>['2']);
    });

    test('type filter returns only the covered kind', () async {
      enumerationGateway.images = <EnumeratedAsset>[_row('1'), _row('3')];
      enumerationGateway.videos = <EnumeratedAsset>[
        _row('2', type: MediaAssetType.video),
      ];
      final Result<List<MediaAsset>> videos = await service.getAssets(
        type: MediaFilterType.video,
      );
      expect(
        (videos as Success<List<MediaAsset>>).value
            .map((MediaAsset a) => a.id)
            .toList(),
        <String>['2'],
      );
      final Result<List<MediaAsset>> images = await service.getAssets(
        type: MediaFilterType.image,
      );
      expect(
        (images as Success<List<MediaAsset>>).value
            .map((MediaAsset a) => a.id)
            .toList(),
        <String>['3', '1'],
      );
      expectNoPluginCalls();
    });
  });

  group('album and month filters from the pass', () {
    test('album filter matches bucket id; names resolve per album', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('1', bucketId: '10', relativePath: null),
        _row('2', bucketId: '20', bucketName: 'Shots', relativePath: null),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets(
        albumId: '20',
      );
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>['2']);
      // No relative path: the fallback is the album's own name,
      // as the plugin path resolved it via the queried path.
      expect(assets.single.albumName, 'Shots');
      expectNoPluginCalls();
    });

    test('whole-library fallback name is the all album name', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('1', relativePath: null),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets();
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.single.albumName, 'Recent');
    });

    test('the whole-library album id means no bucket filter', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('1', bucketId: '10'),
        _row('2', bucketId: '20', bucketName: 'Shots'),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets(
        albumId: 'isAll',
      );
      expect((result as Success<List<MediaAsset>>).value.length, 2);
      expectNoPluginCalls();
    });

    test('month filter compares DATE_ADDED, both ends inclusive', () async {
      // Month 2023-11 (UTC): [1698796800, 1701388800] in seconds;
      // the plugin condition was >= min AND <= max.
      final int start = DateTime(2023, 11).millisecondsSinceEpoch ~/ 1000;
      final int end = DateTime(2023, 12).millisecondsSinceEpoch ~/ 1000;
      enumerationGateway.images = <EnumeratedAsset>[
        _row('before', dateAddedSec: start - 1),
        _row('atStart', dateAddedSec: start),
        _row('atEnd', dateAddedSec: end),
        _row('after', dateAddedSec: end + 1),
      ];
      // Non-numeric ids sort as id 0 in the merge; assert by set.
      final Result<List<MediaAsset>> result = await service.getAssets(
        monthKey: '2023-11',
      );
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.map((MediaAsset a) => a.id).toSet(), <String>{
        'atStart',
        'atEnd',
      });
      expectNoPluginCalls();
    });

    test('invalid month key fails before any pass or plugin call', () async {
      final Result<List<MediaAsset>> result = await service.getAssets(
        monthKey: 'not-a-month',
      );
      expect(result.isFailure, isTrue);
      expect(enumerationGateway.imageCalls, 0);
      expectNoPluginCalls();
    });
  });

  group('getAssetsByIds from the pass', () {
    test('resolves exact ids with sizes, skipping gone ids', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('1', sizeBytes: 11, dateTakenMs: 1700000000 * 1000),
        _row('2', sizeBytes: 22, dateTakenMs: 1700100000 * 1000),
      ];
      final Result<List<MediaAsset>> result = await service.getAssetsByIds(
        <String>['gone', '1', '2'],
      );
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      // Newest first by createDate, as the plugin path sorted.
      expect(assets.map((MediaAsset a) => a.id).toList(), <String>['2', '1']);
      expect(assets.map((MediaAsset a) => a.sizeBytes).toList(), <int>[22, 11]);
      expectNoPluginCalls();
    });
  });

  group('plugin list dimension rule (ADR-017 §4)', () {
    test('stored-dimension-zero images never enter a page', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('normal'),
        // Header-repaired: a store column carries the zero, the
        // header gave real dimensions. The plugin's SQL size
        // condition still never listed such a row.
        _row('repaired', width: 4000, height: 3000, storeWidth: 0),
        _row('flat', width: 4000, height: 3000, storeHeight: 0),
        // 0-dimension SVG-style row: repair skipped, all zero.
        _row('svg', width: 0, height: 0, storeWidth: 0, storeHeight: 0),
      ];
      final Result<List<MediaAsset>> all = await service.getAssets();
      expect(
        (all as Success<List<MediaAsset>>).value
            .map((MediaAsset a) => a.id)
            .toList(),
        <String>['normal'],
      );
      final Result<List<MediaAsset>> images = await service.getAssets(
        type: MediaFilterType.image,
      );
      expect(
        (images as Success<List<MediaAsset>>).value
            .map((MediaAsset a) => a.id)
            .toList(),
        <String>['normal'],
      );
      expectNoPluginCalls();
    });

    test('a stored-dimension-zero video is still listed', () async {
      enumerationGateway.videos = <EnumeratedAsset>[
        _row(
          'v',
          type: MediaAssetType.video,
          width: 0,
          height: 0,
          storeWidth: 0,
          storeHeight: 0,
        ),
      ];
      final Result<List<MediaAsset>> result = await service.getAssets(
        type: MediaFilterType.video,
      );
      expect(
        (result as Success<List<MediaAsset>>).value
            .map((MediaAsset a) => a.id)
            .toList(),
        <String>['v'],
      );
      expectNoPluginCalls();
    });

    test('a stored-dimension-zero image still resolves by id, with '
        'its repaired dimensions', () async {
      enumerationGateway.images = <EnumeratedAsset>[
        _row('repaired', width: 4000, height: 3000, storeWidth: 0),
      ];
      final Result<List<MediaAsset>> result = await service.getAssetsByIds(
        <String>['repaired'],
      );
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.single.id, 'repaired');
      // The plugin's unfiltered per-id path carried the
      // repaired (EXIF/header) dimensions; so does this one.
      expect(assets.single.width, 4000);
      expect(assets.single.height, 3000);
      expectNoPluginCalls();
    });
  });

  group('fallback to the legacy plugin path', () {
    test('a failed pass serves the page through the plugin', () async {
      enumerationGateway.fail = true;
      plugin.pages = <String, List<AssetEntity>>{
        'all': <AssetEntity>[_entity('a1')],
      };
      plugin.sizes = <String, int>{'a1': 42};
      final Result<List<MediaAsset>> result = await service.getAssets();
      expect(result.isSuccess, isTrue);
      final List<MediaAsset> assets =
          (result as Success<List<MediaAsset>>).value;
      expect(assets.single.id, 'a1');
      expect(assets.single.sizeBytes, 42);
      // The plugin path ran (page + size); the pass was tried once.
      expect(plugin.pagedCalls, 1);
      expect(plugin.sizeCalls, 1);
      expect(enumerationGateway.imageCalls, 1);
    });

    test('an album unknown to the pass defers to the plugin', () async {
      enumerationGateway.images = <EnumeratedAsset>[_row('1')];
      final Result<List<MediaAsset>> result = await service.getAssets(
        albumId: 'nope',
      );
      // The plugin path is authoritative for the unknown album
      // and fails it, exactly as before the enumeration existed.
      expect(result.isFailure, isTrue);
      expect(plugin.pathListCalls, 1);
      expect(plugin.sizeCalls, 0);
    });

    test('a permission change invalidates the memoised pass', () async {
      enumerationGateway.images = <EnumeratedAsset>[_row('1')];
      await service.requestPermission();
      await service.getAssets();
      expect(enumerationGateway.imageCalls, 1);
      // Same grant again: the memo survives.
      await service.requestPermission();
      await service.getAssets();
      expect(enumerationGateway.imageCalls, 1);
      // A grant change (full → limited) must not reuse a pass
      // enumerated under the old grant: the next read re-passes.
      plugin.permission = PermissionState.limited;
      await service.requestPermission();
      await service.getAssets();
      expect(enumerationGateway.imageCalls, 2);
      expect(enumerationGateway.videoCalls, 2);
    });
  });
}
