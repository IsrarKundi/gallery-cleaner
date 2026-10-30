// Fix plan Stage 2 (ADR-017): the shared scan runs on the
// one-pass enumeration. A fake media service proves the scan
// never pages the plugin (zero getAssets / getAlbums calls);
// pages arrive in the same 50-asset chunks through the same
// pipeline; each run forces exactly one fresh pass; and two
// repository consumers starting together share one run and
// one pass (the already-running guard, end to end).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_repository_impl.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/enumerated_asset.dart';
import 'package:klara/services/media/library_enumeration_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_enumeration_gateway.dart';
import 'package:klara/services/media/media_service.dart';

class _FakeMedia implements MediaService {
  int getAssetsCalls = 0;
  int getAlbumsCalls = 0;

  @override
  Future<Result<MediaPermission>> requestPermission() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> presentLimitedSelection() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> openAppSettings() {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    getAlbumsCalls++;
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
    getAssetsCalls++;
    return const Failure<List<MediaAsset>>(
      AppFailure(messageKey: 'should-not-be-called'),
    );
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) {
    throw UnimplementedError();
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    // Every thumbnail fails: analysis skips the asset, the page
    // still delivers (the enumeration tests are about paging,
    // not scoring).
    return const Failure<Uint8List>(AppFailure(messageKey: 'no-thumbnail'));
  }
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

class _RealLocal extends LocalServiceImpl {
  _RealLocal({required Directory directory})
    : super(directoryResolver: () async => directory);
}

EnumeratedAsset _video(
  String id, {
  int width = 1920,
  int height = 1080,
  int? storeWidth,
  int? storeHeight,
}) {
  return EnumeratedAsset(
    id: id,
    type: MediaAssetType.video,
    title: '$id.mp4',
    bucketId: '10',
    bucketName: 'Camera',
    sizeBytes: 5000,
    width: width,
    height: height,
    storeWidth: storeWidth ?? width,
    storeHeight: storeHeight ?? height,
    dateAddedSec: 1700000000,
    dateTakenMs: 0,
    dateModifiedSec: 1700000000,
    isFavorite: false,
    relativePath: 'DCIM/Camera',
    fileExists: true,
  );
}

EnumeratedAsset _image(
  String id, {
  int width = 4000,
  int height = 3000,
  int? storeWidth,
  int? storeHeight,
}) {
  return EnumeratedAsset(
    id: id,
    type: MediaAssetType.image,
    title: '$id.jpg',
    bucketId: '10',
    bucketName: 'Camera',
    sizeBytes: 5000,
    width: width,
    height: height,
    storeWidth: storeWidth ?? width,
    storeHeight: storeHeight ?? height,
    dateAddedSec: 1700000000,
    dateTakenMs: 0,
    dateModifiedSec: 1700000000,
    isFavorite: false,
    relativePath: 'DCIM/Camera',
    fileExists: true,
  );
}

Future<List<PhotoAnalysis?>> _noAnalysis(
  List<AnalysisBatchInput> inputs,
) async {
  return List<PhotoAnalysis?>.filled(inputs.length, null);
}

void main() {
  late Directory temp;
  late _RealLocal local;
  late _FakeMedia media;
  late _FakeEnumerationGateway gateway;
  late LibraryEnumerationServiceImpl enumeration;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_enum_scan_');
    local = _RealLocal(directory: temp);
    media = _FakeMedia();
    gateway = _FakeEnumerationGateway();
    enumeration = LibraryEnumerationServiceImpl(gateway: gateway);
  });

  tearDown(() async {
    await local.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  LibraryScanner scanner() {
    return LibraryScanner(
      media: media,
      local: local,
      enumeration: enumeration,
      analyzeBatch: _noAnalysis,
    );
  }

  test(
    'pages are 50-asset slices of one pass; the plugin is never paged',
    () async {
      gateway.videos = <EnumeratedAsset>[
        for (int i = 1; i <= 120; i++) _video('$i'),
      ];
      final List<int> pageSizes = <int>[];
      final List<int?> totals = <int?>[];
      final LibraryScan scan = await scanner().scan(
        onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> fresh) {
          pageSizes.add(page.length);
        },
        onProgress: (int scanned, int? total) {
          totals.add(total);
        },
      );
      expect(scan.pageFailed, isFalse);
      expect(scan.cancelled, isFalse);
      expect(scan.scanned, 120);
      expect(pageSizes, <int>[50, 50, 20]);
      // The total is the pass's exact length, on every report.
      expect(totals, everyElement(120));
      // One pass behind the whole scan; no plugin paging at all.
      expect(gateway.imageCalls, 1);
      expect(gateway.videoCalls, 1);
      expect(media.getAssetsCalls, 0);
      expect(media.getAlbumsCalls, 0);
      // Merged order preserved into the scan: id descending.
      expect(scan.assets.first.id, '120');
      expect(scan.assets.last.id, '1');
    },
  );

  test('stored-dimension-zero images are not scanned; '
      'zero-dimension videos are', () async {
    gateway.images = <EnumeratedAsset>[
      _image('30'),
      // Store width 0, header-repaired to real dimensions:
      // the plugin's paged lists never served this row, so
      // the old plugin-paged scan never saw it either.
      _image('20', storeWidth: 0),
    ];
    gateway.videos = <EnumeratedAsset>[
      _video('10'),
      _video('5', width: 0, height: 0),
    ];
    final List<int?> totals = <int?>[];
    final LibraryScan scan = await scanner().scan(
      onProgress: (int scanned, int? total) {
        totals.add(total);
      },
    );
    expect(scan.pageFailed, isFalse);
    expect(scan.scanned, 3);
    expect(scan.assets.map((MediaAsset a) => a.id).toSet(), <String>{
      '30',
      '10',
      '5',
    });
    // The progress total is the list-visible set, the same
    // length the old plugin-paged scan would have counted.
    expect(totals, everyElement(3));
    expect(gateway.imageCalls, 1);
    expect(media.getAssetsCalls, 0);
  });

  test('an empty library scans clean with one empty page', () async {
    final List<int> pageSizes = <int>[];
    final LibraryScan scan = await scanner().scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> fresh) {
        pageSizes.add(page.length);
      },
    );
    expect(scan.pageFailed, isFalse);
    expect(scan.scanned, 0);
    expect(pageSizes, <int>[0]);
    expect(gateway.imageCalls, 1);
  });

  test('a failed pass is a page-0 failure: no pages, no results', () async {
    gateway.fail = true;
    int pages = 0;
    final LibraryScan scan = await scanner().scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> fresh) {
        pages++;
      },
    );
    expect(scan.pageFailed, isTrue);
    expect(scan.scanned, 0);
    expect(scan.assets, isEmpty);
    expect(pages, 0);
    expect(media.getAssetsCalls, 0);
  });

  test('each scan run forces one fresh pass', () async {
    gateway.videos = <EnumeratedAsset>[_video('1')];
    await scanner().scan();
    await scanner().scan();
    expect(gateway.imageCalls, 2);
    expect(gateway.videoCalls, 2);
  });

  test(
    'two repository consumers starting together share one run and one pass',
    () async {
      gateway.videos = <EnumeratedAsset>[_video('1'), _video('2'), _video('3')];
      final ScanRepositoryImpl repository = ScanRepositoryImpl(
        media: media,
        local: local,
        enumeration: enumeration,
      );
      final List<Future<LibraryScan>> starts = <Future<LibraryScan>>[
        repository.start(),
        repository.start(),
      ];
      final List<LibraryScan> results = await Future.wait(starts);
      expect(results[0].scanned, 3);
      expect(results[1].scanned, 3);
      // Double start = one scan = one enumeration pass.
      expect(gateway.imageCalls, 1);
      expect(gateway.videoCalls, 1);
      // A later start replays the memoised scan — still one pass.
      final LibraryScan replayed = await repository.start();
      expect(replayed.scanned, 3);
      expect(gateway.imageCalls, 1);
      expect(media.getAssetsCalls, 0);
    },
  );
}
