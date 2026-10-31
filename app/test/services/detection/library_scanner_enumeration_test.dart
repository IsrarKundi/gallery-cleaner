// Fix plan Stage 2 (ADR-017): the shared scan runs on the
// one-pass enumeration. A fake media service proves the scan
// never pages the plugin (zero getAssets / getAlbums calls);
// pages arrive in the same 50-asset chunks through the same
// pipeline; each run forces exactly one fresh pass; and two
// repository consumers starting together share one run and
// one pass (the already-running guard, end to end).
// ADR-026: delivery is per type — image pages land while the
// videos pass is still pending, a videos failure after images
// is a partial scan, an images failure is the page-0 shape.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/blur_detection.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';
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

  /// Per-type controls (ADR-026): fail or hold one type's pass
  /// while the other completes normally.
  bool failImages = false;
  bool failVideos = false;
  Completer<void>? imagesGate;
  Completer<void>? videosGate;

  @override
  Future<List<EnumeratedAsset>> enumerateImages() async {
    imageCalls++;
    if (fail || failImages) {
      throw StateError('native query failed');
    }
    final Completer<void>? gate = imagesGate;
    if (gate != null) {
      await gate.future;
    }
    return images;
  }

  @override
  Future<List<EnumeratedAsset>> enumerateVideos() async {
    videoCalls++;
    if (fail || failVideos) {
      throw StateError('native query failed');
    }
    final Completer<void>? gate = videosGate;
    if (gate != null) {
      await gate.future;
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

Future<List<FingerprintComputation?>> _noFingerprints(
  List<AnalysisBatchInput> inputs,
) async {
  return List<FingerprintComputation?>.filled(inputs.length, null);
}

Future<List<BlurAssessment?>> _noBlur(List<AnalysisBatchInput> inputs) async {
  return List<BlurAssessment?>.filled(inputs.length, null);
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
      fingerprintBatch: _noFingerprints,
      blurBatch: _noBlur,
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
        onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
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
    // The progress total grows as results land (ADR-026): the
    // images page reports the images count (1 list-visible),
    // the videos page the combined list-visible total (3) —
    // the same final length the old plugin-paged scan counted.
    expect(totals, <int?>[1, 3]);
    expect(gateway.imageCalls, 1);
    expect(media.getAssetsCalls, 0);
  });

  test('an empty library scans clean with one empty page', () async {
    final List<int> pageSizes = <int>[];
    final LibraryScan scan = await scanner().scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
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
      onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
        pages++;
      },
    );
    expect(scan.pageFailed, isTrue);
    expect(scan.scanned, 0);
    expect(scan.assets, isEmpty);
    expect(pages, 0);
    expect(media.getAssetsCalls, 0);
  });

  test('image pages arrive while the videos pass is still '
      'pending (ADR-026)', () async {
    gateway.images = <EnumeratedAsset>[
      for (int i = 1; i <= 60; i++) _image('$i'),
    ];
    gateway.videos = <EnumeratedAsset>[_video('100'), _video('101')];
    gateway.videosGate = Completer<void>();
    final List<List<String>> pages = <List<String>>[];
    bool scanDone = false;
    final Future<LibraryScan> scanFuture = scanner()
        .scan(
          onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
            pages.add(page.map((MediaAsset a) => a.id).toList());
          },
        )
        .whenComplete(() {
          scanDone = true;
        });
    // Wait (real time: the local store does real IO) until the
    // image pages have been delivered.
    for (int i = 0; i < 400 && pages.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Both image pages (50 + 10) landed although the videos
    // pass has not returned yet — and the scan is still running.
    expect(pages.length, 2);
    expect(pages[0].length, 50);
    expect(pages[1].length, 10);
    expect(scanDone, isFalse);
    expect(gateway.videoCalls, 1);
    gateway.videosGate!.complete();
    final LibraryScan scan = await scanFuture;
    expect(scanDone, isTrue);
    expect(scan.pageFailed, isFalse);
    expect(scan.scanned, 62);
    expect(pages.length, 3);
    expect(pages[2], <String>['101', '100']);
  });

  test('a videos pass failing after images is a partial scan; '
      'the snapshot stands (ADR-026)', () async {
    const ScanMemberships seeded = ScanMemberships(
      algorithmVersion: scanMembershipAlgorithmVersion,
      assetInfos: <String, AssetInfo>{
        'seed-1': AssetInfo(
          assetId: 'seed-1',
          type: MediaAssetType.image,
          width: 10,
          height: 10,
          sizeBytes: 5,
          modifiedDateMs: null,
          isEdited: false,
          isScreenshot: false,
        ),
      },
      groups: <ScanGroup>[],
      duplicateReferences: <DuplicateReference>[],
    );
    await local.saveScanMemberships(seeded);
    gateway.images = <EnumeratedAsset>[_image('3'), _image('2'), _image('1')];
    gateway.failVideos = true;
    final LibraryScan scan = await scanner().scan();
    // The delivered images stand as a partial result — the same
    // shape a mid-scan page failure has on the paged source.
    expect(scan.pageFailed, isTrue);
    expect(scan.cancelled, isFalse);
    expect(scan.scanned, 3);
    expect(scan.assets.map((MediaAsset a) => a.id).toList(), <String>[
      '3',
      '2',
      '1',
    ]);
    // The previous snapshot is the result's memberships, and
    // the persisted one was not overwritten.
    expect(scan.memberships.assetInfos.keys.toList(), <String>['seed-1']);
    final Result<ScanMemberships> reloaded = await local.loadScanMemberships();
    expect(
      reloaded.fold(
        onSuccess: (ScanMemberships m) => m.assetInfos.keys.toList(),
        onFailure: (_) => <String>[],
      ),
      <String>['seed-1'],
    );
  });

  test('an images pass failing is a page-0 failure even when '
      'videos are fine (ADR-026)', () async {
    gateway.failImages = true;
    gateway.videos = <EnumeratedAsset>[_video('1')];
    int pages = 0;
    final LibraryScan scan = await scanner().scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
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
