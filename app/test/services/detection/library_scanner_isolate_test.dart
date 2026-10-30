// Stage 4 scanner paths: the two worker passes (fingerprint +
// blur) with UI-thread fallback and the degraded flag,
// bounded-parallel fetch, per-asset skipping, and the rule
// that only a complete scan writes memberships. Fakes only;
// no device, no MediaStore.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/scan_memberships.dart';
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

  int saveMembershipsCalls = 0;

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) {
    saveMembershipsCalls++;
    return super.saveScanMemberships(memberships);
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

  test('default batch runners are the worker isolates', () {
    final LibraryScanner scanner = LibraryScanner(
      media: _FakeMedia(pages: const <List<MediaAsset>>[]),
      local: local,
    );
    expect(scanner.fingerprintBatch, same(fingerprintBatchOnIsolate));
    expect(scanner.blurBatch, same(blurBatchOnIsolate));
    expect(scanner.membershipsRunner, same(buildScanMembershipsOnIsolate));
  });

  test('scan computes every image via the two isolate passes', () async {
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
    expect(result.assessments.length, 3);
    // Fingerprint pass + blur pass: 2 fetches per image.
    expect(media.getThumbnailCalls, 6);
    expect(local.saveMembershipsCalls, 1);
    expect(seenPages.length, 1);
    // Oracle check: the fingerprint is the one the bytes yield.
    for (final String id in <String>['a1', 'a2', 'a3']) {
      final int seed = int.parse(id.substring(1));
      final FingerprintComputation? oracle = computeFingerprint(
        _patternPng(seed),
      );
      expect(
        result.assessments[id]!.fingerprint!.dHash,
        oracle!.fingerprint.dHash,
      );
    }
    expect(result.memberships.algorithmVersion, scanMembershipAlgorithmVersion);
  });

  test('videos are never fetched for analysis', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('v1', type: MediaAssetType.video)],
      ],
    );
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan();
    expect(media.getThumbnailCalls, 2);
    expect(result.assessments.containsKey('v1'), isFalse);
    // …but the video's facts are part of the membership product.
    expect(result.memberships.assetInfos.containsKey('v1'), isTrue);
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
      expect(result.assessments.length, 20);
      expect(media.maxInFlight, LibraryScanner.fetchConcurrency);
    },
  );

  test('failed and corrupt thumbnails skip only their own values', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('a2'), _asset('a3')],
      ],
    );
    media.failingThumbs.add('a1');
    media.corruptThumbs.add('a2');
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan();
    expect(result.assessments['a1']!.fingerprint, isNull);
    expect(result.assessments['a2']!.fingerprint, isNull);
    expect(result.assessments['a3']!.fingerprint, isNotNull);
    expect(result.pageFailed, isFalse);
  });

  test('worker spawn failure degrades to the UI thread with '
      'identical results', () async {
    final _FakeMedia media = _FakeMedia(
      pages: <List<MediaAsset>>[
        <MediaAsset>[_asset('a1'), _asset('a2')],
      ],
    );
    int degradedCalls = 0;
    final LibraryScanner scanner = LibraryScanner(
      media: media,
      local: local,
      fingerprintBatch: (_) async {
        throw StateError('no isolate');
      },
    );
    final LibraryScan result = await scanner.scan(
      onDegraded: () => degradedCalls++,
    );
    expect(result.degraded, isTrue);
    expect(degradedCalls, 1);
    expect(result.assessments.length, 2);
    final FingerprintComputation? oracle = computeFingerprint(_patternPng(1));
    expect(
      result.assessments['a1']!.fingerprint!.dHash,
      oracle!.fingerprint.dHash,
    );
  });

  test('cancelled scan reports no pages and no membership save', () async {
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
    expect(local.saveMembershipsCalls, 0);
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
