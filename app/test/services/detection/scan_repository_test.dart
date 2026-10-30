// Phase 4.2: shared scan repository — one scan for hub +
// Duplicates, cancellation, pause/resume, checkpoints, memoisation
// (solutions 4.2). Fakes only; no device, no MediaStore.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/detection/scan_repository.dart';
import 'package:klara/services/detection/scan_repository_impl.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';

Uint8List _tinyPng() {
  return Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
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

  /// Page index -> page assets. A short last page ends the scan.
  final List<List<MediaAsset>> pages;

  int getAssetsCalls = 0;
  int getThumbnailCalls = 0;

  /// Optional gates: getAssets(page) waits for gates[page].
  final Map<int, Completer<void>> gates = <int, Completer<void>>{};

  /// Optional hook run on every thumbnail fetch (cancel tests).
  void Function()? onThumbnail;

  /// Pages that fail instead of returning assets.
  final Set<int> failingPages = <int>{};

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
    getAssetsCalls++;
    final Completer<void>? gate = gates[page];
    if (gate != null) {
      await gate.future;
    }
    if (failingPages.contains(page)) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: 'errorMediaLoad'),
      );
    }
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
    onThumbnail?.call();
    return Success<Uint8List>(_tinyPng());
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
    temp = await Directory.systemTemp.createTemp('klara_scan_test_');
    local = _CountingLocal(directory: temp);
  });

  tearDown(() async {
    await local.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  List<MediaAsset> pageOf(String prefix, int count) {
    return <MediaAsset>[for (int i = 0; i < count; i++) _asset('$prefix$i')];
  }

  group('4.2 shared scan', () {
    test('hub then Duplicates pays exactly one scan', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          pageOf('a', 50),
          pageOf('b', 50),
          pageOf('c', 10),
        ],
      );
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      final List<List<MediaAsset>> firstPages = <List<MediaAsset>>[];
      repo.subscribe(
        onPage: (List<MediaAsset> page, _) => firstPages.add(page),
      );
      final LibraryScan first = await repo.start();
      expect(first.assets.length, 110);
      expect(media.getAssetsCalls, 3);
      // Stage 4: two thumbnail passes per image (fingerprint at
      // 128 px + blur at 512 px) = 2 x 110 fetches.
      expect(media.getThumbnailCalls, 220);

      final List<List<MediaAsset>> secondPages = <List<MediaAsset>>[];
      repo.subscribe(
        onPage: (List<MediaAsset> page, _) => secondPages.add(page),
      );
      final LibraryScan second = await repo.start();
      expect(identical(second, first), isTrue);
      expect(media.getAssetsCalls, 3);
      expect(media.getThumbnailCalls, 220);
      expect(secondPages.length, 3);
    });

    test('concurrent starts join one run (no duplicate fetch)', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 10)],
      );
      media.gates[1] = Completer<void>();
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      final Future<LibraryScan> first = repo.start();
      final Future<LibraryScan> second = repo.start();
      expect(identical(second, first), isTrue);
      media.gates[1]!.complete();
      final LibraryScan done = await first;
      expect(done.assets.length, 60);
      expect(await second, done);
      expect(media.getAssetsCalls, 2);
    });

    test(
      'cancel from onPage fetches nothing further, writes nothing',
      () async {
        final _FakeMedia media = _FakeMedia(
          pages: <List<MediaAsset>>[
            pageOf('a', 50),
            pageOf('b', 50),
            pageOf('c', 10),
          ],
        );
        final ScanRepository repo = ScanRepositoryImpl(
          media: media,
          local: local,
        );
        repo.subscribe(
          onPage: (List<MediaAsset> page, _) => repo.cancelCurrent(),
        );
        final LibraryScan result = await repo.start();
        expect(result.cancelled, isTrue);
        expect(media.getAssetsCalls, 1);
        expect(local.saveMembershipsCalls, 0);
      },
    );

    test('cancel during analysis discards the run, writes nothing', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 50)],
      );
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      bool armed = false;
      media.onThumbnail = () {
        // Stage 4: pages are metadata-only; thumbnails are read
        // in the analysis phase AFTER enumeration. Cancelling
        // there discards the whole run's analysis (the outcome
        // is cancelled and ignored by subscribers) and persists
        // no memberships.
        if (!armed) {
          armed = true;
          repo.cancelCurrent();
        }
      };
      final List<List<MediaAsset>> delivered = <List<MediaAsset>>[];
      repo.subscribe(onPage: (List<MediaAsset> page, _) => delivered.add(page));
      final LibraryScan result = await repo.start();
      expect(result.cancelled, isTrue);
      // Two content pages plus the terminating empty page: the
      // scanner has always delivered that final empty page when
      // the library size is an exact page multiple (the empty
      // -library case delivers exactly one).
      expect(delivered.length, 3);
      expect(result.assets.length, 100);
      expect(local.saveMembershipsCalls, 0);
    });

    test('leave-and-return neither restarts nor duplicates', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 10)],
      );
      media.gates[1] = Completer<void>();
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      final List<List<MediaAsset>> firstPages = <List<MediaAsset>>[];
      final ScanSubscription firstSub = repo.subscribe(
        onPage: (List<MediaAsset> page, _) => firstPages.add(page),
      );
      final Future<LibraryScan> run = repo.start();
      // Page 0 delivered; page 1 gated. Leave: detach only.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(firstPages.length, 1);
      firstSub.cancel();
      final List<List<MediaAsset>> secondPages = <List<MediaAsset>>[];
      repo.subscribe(
        onPage: (List<MediaAsset> page, _) => secondPages.add(page),
      );
      expect(secondPages.length, 1);
      expect(secondPages.first.first.id, 'a0');
      media.gates[1]!.complete();
      final LibraryScan done = await run;
      expect(done.assets.length, 60);
      expect(secondPages.length, 2);
      expect(firstPages.length, 1);
      expect(media.getAssetsCalls, 2);
    });

    test(
      'restart during a scan cancels cleanly, no interleaved writes',
      () async {
        final _FakeMedia media = _FakeMedia(
          pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 10)],
        );
        media.gates[1] = Completer<void>();
        final ScanRepository repo = ScanRepositoryImpl(
          media: media,
          local: local,
        );
        final Future<LibraryScan> oldRun = repo.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final Future<LibraryScan> freshRun = repo.restart();
        media.gates[1]!.complete();
        final LibraryScan oldResult = await oldRun;
        expect(oldResult.cancelled, isTrue);
        final LibraryScan freshResult = await freshRun;
        expect(freshResult.cancelled, isFalse);
        expect(freshResult.assets.length, 60);
        // Only the fresh run's membership write landed.
        expect(local.saveMembershipsCalls, 1);
      },
    );

    test('pause stalls at the page boundary; resume continues', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 10)],
      );
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      repo.subscribe(
        onPage: (List<MediaAsset> page, _) {
          if (page.first.id == 'a0') {
            repo.pause();
          }
        },
      );
      bool done = false;
      final Future<LibraryScan> run = repo.start().then((LibraryScan result) {
        done = true;
        return result;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(done, isFalse);
      repo.resume();
      final LibraryScan result = await run;
      expect(done, isTrue);
      expect(result.assets.length, 60);
      expect(media.getAssetsCalls, 2);
    });

    test('one membership write lands per completed scan (Stage 4)', () async {
      final List<List<MediaAsset>> pages = <List<MediaAsset>>[];
      for (int p = 0; p < 44; p++) {
        final List<MediaAsset> page = <MediaAsset>[
          _asset('img$p'),
          for (int i = 0; i < 49; i++)
            _asset('vid$p-$i', type: MediaAssetType.video),
        ];
        pages.add(page);
      }
      pages.add(<MediaAsset>[
        for (int i = 0; i < 10; i++)
          _asset('tail$i', type: MediaAssetType.video),
      ]);
      final _FakeMedia media = _FakeMedia(pages: pages);
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      final LibraryScan result = await repo.start();
      expect(result.assets.length, 44 * 50 + 10);
      expect(result.assessments.length, 44);
      // Stage 4: no per-page checkpoints — the membership
      // snapshot is written once, when the scan completes.
      expect(local.saveMembershipsCalls, 1);
    });

    test('onPage fresh maps are empty; assessments ride the result', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[_asset('x0'), _asset('x1'), _asset('new0')],
        ],
      );
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      final List<Map<String, PhotoAssessment>> freshPages =
          <Map<String, PhotoAssessment>>[];
      repo.subscribe(
        onPage: (List<MediaAsset> _, Map<String, PhotoAssessment> fresh) {
          freshPages.add(fresh);
        },
      );
      final LibraryScan result = await repo.start();
      expect(freshPages.length, 1);
      // Stage 4: enumeration pages carry no analysis at all —
      // matching happens after the last page, in the scan.
      expect(freshPages.first, isEmpty);
      expect(result.assessments.keys.toSet(), <String>{'x0', 'x1', 'new0'});
    });

    test('memoised scan replays until dirty; failures never memoise', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[pageOf('a', 50), pageOf('b', 10)],
      );
      final ScanRepository repo = ScanRepositoryImpl(
        media: media,
        local: local,
      );
      await repo.start();
      expect(media.getAssetsCalls, 2);
      await repo.start();
      expect(media.getAssetsCalls, 2);
      repo.markDirty();
      await repo.start();
      expect(media.getAssetsCalls, 4);

      media.failingPages.add(1);
      repo.markDirty();
      final LibraryScan failed = await repo.start();
      expect(failed.pageFailed, isTrue);
      expect(failed.assets.length, 50);
      final int callsAfterFailure = media.getAssetsCalls;
      await repo.start();
      expect(media.getAssetsCalls, greaterThan(callsAfterFailure));
    });
  });
}
