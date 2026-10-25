// Solutions 5.1: the scanner's isolate batch path — bounded
// parallel fetch, isolate analysis with UI-thread fallback, and
// the degraded flag. Fakes only; no device, no MediaStore.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';

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

MediaAsset _asset(String id, {MediaAssetType type = MediaAssetType.image}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime.utc(2026, 1, 1),
    title: id,
    albumName: 'all',
  );
}

class _FakeMedia implements MediaService {
  _FakeMedia({required this.pages});

  final List<List<MediaAsset>> pages;

  int getThumbnailCalls = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  /// Thumbnail fetch delay, to make fetch concurrency observable.
  Duration thumbDelay = Duration.zero;

  /// Ids whose thumbnail fetch fails.
  final Set<String> failingThumbs = <String>{};

  /// Ids whose thumbnail bytes are corrupt (decode to null).
  final Set<String> corruptThumbs = <String>{};

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
    if (page < pages.length) {
      return Success<List<MediaAsset>>(pages[page]);
    }
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
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
    getThumbnailCalls++;
    inFlight++;
    if (inFlight > maxInFlight) {
      maxInFlight = inFlight;
    }
    try {
      if (thumbDelay != Duration.zero) {
        await Future<void>.delayed(thumbDelay);
      }
      if (failingThumbs.contains(assetId)) {
        return const Failure<Uint8List>(
          AppFailure(messageKey: 'errorMediaLoad'),
        );
      }
      if (corruptThumbs.contains(assetId)) {
        return Success<Uint8List>(Uint8List.fromList(<int>[0, 1, 2, 3]));
      }
      final int seed = int.tryParse(assetId.replaceAll('a', '')) ?? 0;
      return Success<Uint8List>(_patternPng(seed));
    } finally {
      inFlight--;
    }
  }
}

class _CountingLocal extends LocalServiceImpl {
  _CountingLocal({required Directory directory})
    : super(directoryResolver: () async => directory);

  int saveAnalysesCalls = 0;

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) {
    saveAnalysesCalls++;
    return super.saveAnalyses(analyses);
  }
}

void main() {
  late Directory temp;
  late _CountingLocal local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_scanner51_test_');
    local = _CountingLocal(directory: temp);
  });

  tearDown(() async {
    await local.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('default batch runner is the worker isolate', () {
    final LibraryScanner scanner = LibraryScanner(
      media: _FakeMedia(pages: const <List<MediaAsset>>[]),
      local: local,
    );
    expect(scanner.analyzeBatch, same(analyzeBatchOnIsolate));
  });

  test('scan analyses every uncached image via the isolate batch', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('a2'), _asset('a3')],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final List<List<MediaAsset>> seenPages = <List<MediaAsset>>[];
    final LibraryScan result = await scanner.scan(
      onPage: (List<MediaAsset> page, _) => seenPages.add(page),
    );
    expect(result.cancelled, isFalse);
    expect(result.degraded, isFalse);
    expect(result.analyses.length, 3);
    expect(media.getThumbnailCalls, 3);
    expect(local.saveAnalysesCalls, 1);
    expect(seenPages.length, 1);
    // Oracle check: the stored hash is the one the thumbnail yields.
    for (final String id in <String>['a1', 'a2', 'a3']) {
      final int seed = int.parse(id.substring(1));
      final PhotoAnalysis? oracle = analyzeThumbnail(
        assetId: id,
        bytes: _patternPng(seed),
        width: 100,
        height: 100,
      );
      expect(result.analyses[id]!.hash, oracle!.hash);
    }
  });

  test('cached assets pay no thumbnail fetch', () async {
    await local.saveAnalyses(<PhotoAnalysis>[
      PhotoAnalysis(
        assetId: 'a1',
        hash: 42,
        width: 100,
        height: 100,
        blurScore: 1,
        meanLuminance: 2,
        // Phase 5.3: the seeded entry must carry the fingerprint
        // of _asset('a1') (size 1000, no modified date) or the
        // scanner rightly treats it as stale and re-analyses.
        sizeBytes: 1000,
      ),
    ]);
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('a2')],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan();
    expect(media.getThumbnailCalls, 1);
    expect(result.analyses['a1']!.hash, 42);
    expect(result.analyses['a2'], isNotNull);
  });

  test('videos are never fetched for analysis', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('v1', type: MediaAssetType.video)],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan();
    expect(media.getThumbnailCalls, 1);
    expect(result.analyses.containsKey('v1'), isFalse);
  });

  test(
    'thumbnail fetch is bounded-parallel, not serial or unbounded',
    () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[for (int i = 0; i < 20; i++) _asset('a$i')],
        ],
      );
      media.thumbDelay = const Duration(milliseconds: 5);
      final LibraryScanner scanner = LibraryScanner(media: media, local: local);
      final LibraryScan result = await scanner.scan();
      expect(result.analyses.length, 20);
      expect(media.maxInFlight, LibraryScanner.fetchConcurrency);
    },
  );

  test('failed and corrupt thumbnails skip only their own asset', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('a2'), _asset('a3')],
      ],
    );
    media.failingThumbs.add('a1');
    media.corruptThumbs.add('a2');
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan();
    expect(result.analyses.containsKey('a1'), isFalse);
    expect(result.analyses.containsKey('a2'), isFalse);
    expect(result.analyses.containsKey('a3'), isTrue);
    expect(result.pageFailed, isFalse);
  });

  test(
    'spawn failure degrades to the UI thread with identical results',
    () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[_asset('a1'), _asset('a2')],
        ],
      );
      int degradedCalls = 0;
      final LibraryScanner scanner = LibraryScanner(
        media: media,
        local: local,
        analyzeBatch: (_) async {
          throw StateError('no isolate');
        },
      );
      final LibraryScan result = await scanner.scan(
        onDegraded: () => degradedCalls++,
      );
      expect(result.degraded, isTrue);
      expect(degradedCalls, 1);
      expect(result.analyses.length, 2);
      final PhotoAnalysis? oracle = analyzeThumbnail(
        assetId: 'a1',
        bytes: _patternPng(1),
        width: 100,
        height: 100,
      );
      expect(result.analyses['a1']!.hash, oracle!.hash);
    },
  );

  test('cancelled scan reports no pages and no checkpoint save', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1')],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final List<List<MediaAsset>> seenPages = <List<MediaAsset>>[];
    final LibraryScan result = await scanner.scan(
      isCancelled: () => true,
      onPage: (List<MediaAsset> page, _) => seenPages.add(page),
    );
    expect(result.cancelled, isTrue);
    expect(seenPages, isEmpty);
    expect(local.saveAnalysesCalls, 0);
  });

  test('pages arrive in page order', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[for (int i = 0; i < 50; i++) _asset('p0-$i')],
        <MediaAsset>[_asset('p1-0')],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final List<int> pageSizes = <int>[];
    await scanner.scan(
      onPage: (List<MediaAsset> page, _) => pageSizes.add(page.length),
    );
    expect(pageSizes, <int>[50, 1]);
  });
}
