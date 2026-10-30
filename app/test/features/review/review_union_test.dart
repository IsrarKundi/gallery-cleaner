import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/controller/review_union.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _asset(String id, {int size = 1048576}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 100,
    height: 100,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class _Media implements MediaService {
  final Map<String, MediaAsset> assetsById = <String, MediaAsset>{};

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

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
  }) async => Success<List<MediaAsset>>(assetsById.values.toList());

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    final List<MediaAsset> result = <MediaAsset>[];
    for (final String id in ids) {
      if (assetsById.containsKey(id)) {
        result.add(assetsById[id]!);
      }
    }
    return Success<List<MediaAsset>>(result);
  }
}

class _Local implements LocalService {
  // Stage 4: memberships default to "none stored" in this fake.
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async =>
      const Success<int>(0);

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      Success<DeckSession?>(sessions[filterKey]);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      Success<List<DeckSession>>(sessions.values.toList());

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      const Success<Map<String, DateTime>>(<String, DateTime>{});

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async =>
      const Success<double>(1024);

  @override
  Future<Result<void>> saveGoalTargetMb(double targetMb) async =>
      const Success<void>(null);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      const Success<List<DateTime>>(<DateTime>[]);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      Success<List<HistoryRecord>>(history);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
}

class _Trash implements TrashService {
  final List<String> deletedIds = <String>[];
  DeleteOutcome nextOutcome = const DeleteOutcome(
    deletedIds: <String>[],
    deniedIds: <String>[],
    failedIds: <String>[],
  );

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async =>
      Success<TrashOutcome>(
        TrashOutcome(
          trashedIds: ids,
          deniedIds: const <String>[],
          failedIds: const <String>[],
        ),
      );

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async =>
      Success<RestoreOutcome>(
        RestoreOutcome(
          restoredIds: ids,
          deniedIds: const <String>[],
          failedIds: const <String>[],
        ),
      );

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async =>
      const Success<EmptyTrashOutcome>(
        EmptyTrashOutcome(
          removedIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    deletedIds.addAll(ids);
    if (nextOutcome.deletedIds.isEmpty &&
        nextOutcome.deniedIds.isEmpty &&
        nextOutcome.failedIds.isEmpty) {
      return Success<DeleteOutcome>(
        DeleteOutcome(
          deletedIds: ids,
          deniedIds: const <String>[],
          failedIds: const <String>[],
        ),
      );
    }
    return Success<DeleteOutcome>(nextOutcome);
  }
}

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('buildReviewUnion', () {
    test('builds union of Clean deck deletes and smart deck deletes in stable order', () async {
      final _Media media = _Media();
      final _Local local = _Local();

      final MediaAsset c1 = _asset('c1');
      final MediaAsset c2 = _asset('c2');
      final MediaAsset s1 = _asset('s1');
      final MediaAsset s2 = _asset('s2');
      final MediaAsset b1 = _asset('b1');
      media.assetsById['c1'] = c1;
      media.assetsById['c2'] = c2;
      media.assetsById['s1'] = s1;
      media.assetsById['s2'] = s2;
      media.assetsById['b1'] = b1;

      // Clean deck session
      await local.saveSession(
        DeckSession(
          filterKey: 'all',
          currentIndex: 2,
          marks: <String, DeckMark>{
            'c1': DeckMark.delete,
            'c2': DeckMark.delete,
          },
          favouriteIds: const <String>{},
        ),
      );

      // Smart deck: screenshots (newest swipe s2 is last)
      await local.saveSession(
        DeckSession(
          filterKey: 'smart:screenshots',
          currentIndex: 2,
          marks: <String, DeckMark>{
            's1': DeckMark.delete,
            's2': DeckMark.delete,
          },
          favouriteIds: const <String>{},
        ),
      );

      // Smart deck: bursts
      await local.saveSession(
        DeckSession(
          filterKey: 'smart:bursts',
          currentIndex: 1,
          marks: <String, DeckMark>{'b1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final ReviewLaunch union = await buildReviewUnion(
        local: local,
        media: media,
      );

      // Clean deck first (c1, c2), then smart decks sorted alphabetically:
      // smart:bursts (b1), then smart:screenshots (s1, s2)
      expect(union.assets.map((MediaAsset a) => a.id).toList(), <String>[
        'c1',
        'c2',
        'b1',
        's1',
        's2',
      ]);
      expect(union.originSessionKeys['c1'], 'all');
      expect(union.originSessionKeys['c2'], 'all');
      expect(union.originSessionKeys['b1'], 'smart:bursts');
      expect(union.originSessionKeys['s1'], 'smart:screenshots');
      expect(union.originSessionKeys['s2'], 'smart:screenshots');
    });

    test('numbers and order remain stable across repeated visits without new actions', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      media.assetsById['c1'] = _asset('c1');
      media.assetsById['s1'] = _asset('s1');

      await local.saveSession(
        DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{'c1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );
      await local.saveSession(
        DeckSession(
          filterKey: 'smart:screenshots',
          currentIndex: 1,
          marks: <String, DeckMark>{'s1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final ReviewLaunch first = await buildReviewUnion(
        local: local,
        media: media,
      );
      final ReviewLaunch second = await buildReviewUnion(
        local: local,
        media: media,
      );

      expect(first.assets.map((a) => a.id), second.assets.map((a) => a.id));
      expect(first.originSessionKeys, second.originSessionKeys);
    });

    test('includes live SmartDeckController in union when alive', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      final MediaAsset s1 = _asset('s1');
      final MediaAsset s2 = _asset('s2');
      media.assetsById['s1'] = s1;
      media.assetsById['s2'] = s2;

      final SmartDeckController smartDeck = SmartDeckController(
        media: media,
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[s1, s2],
        ),
      );
      Get.put<SmartDeckController>(smartDeck);
      smartDeck.ready.value = true;
      smartDeck.thumbnails[s1.id] = Uint8List(1);
      smartDeck.thumbnails[s2.id] = Uint8List(1);
      smartDeck.markCurrent(DeckMark.delete);
      smartDeck.markCurrent(DeckMark.delete);

      final ReviewLaunch union = await buildReviewUnion(
        local: local,
        media: media,
        liveSmartDeck: smartDeck,
      );

      expect(union.assets.map((a) => a.id).toList(), <String>['s1', 's2']);
      expect(union.originSessionKeys['s1'], 'smart:screenshots');
      expect(union.originSessionKeys['s2'], 'smart:screenshots');
    });
  });

  group('Per-origin sync from Review', () {
    test('unmarking smart deck asset updates smart deck session and live controller only', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      final _Trash trash = _Trash();

      final MediaAsset c1 = _asset('c1');
      final MediaAsset s1 = _asset('s1');
      media.assetsById['c1'] = c1;
      media.assetsById['s1'] = s1;

      await local.saveSession(
        DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{'c1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final SmartDeckController smartDeck = SmartDeckController(
        media: media,
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[s1],
        ),
      );
      Get.put<SmartDeckController>(smartDeck);
      smartDeck.ready.value = true;
      smartDeck.thumbnails[s1.id] = Uint8List(1);
      smartDeck.markCurrent(DeckMark.delete);

      final ReviewController review = ReviewController(
        media: media,
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[c1, s1],
        initialOriginSessionKeys: <String, String>{
          'c1': 'all',
          's1': 'smart:screenshots',
        },
        filterKeyOverride: 'union',
      );

      // Unmark smart deck asset s1
      await review.unmark(s1);

      // Smart deck controller marks cleared
      expect(smartDeck.marks.containsKey('s1'), isFalse);
      // Smart deck session in LocalService cleared
      final DeckSession? smartSession = (await local.loadSession(
        'smart:screenshots',
      )).fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(smartSession?.marks.containsKey('s1'), isFalse);

      // Clean deck session NOT touched
      final DeckSession? cleanSession = (await local.loadSession('all'))
          .fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(cleanSession?.marks['c1'], DeckMark.delete);
    });

    test('unmarking works when smart deck controller is disposed (persisted session on disk)', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      final _Trash trash = _Trash();
      final MediaAsset s1 = _asset('s1');
      media.assetsById['s1'] = s1;

      await local.saveSession(
        DeckSession(
          filterKey: 'smart:screenshots',
          currentIndex: 1,
          marks: <String, DeckMark>{'s1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final ReviewController review = ReviewController(
        media: media,
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[s1],
        initialOriginSessionKeys: <String, String>{'s1': 'smart:screenshots'},
        filterKeyOverride: 'union',
      );

      await review.unmark(s1);

      final DeckSession? smartSession = (await local.loadSession(
        'smart:screenshots',
      )).fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(smartSession?.marks.containsKey('s1'), isFalse);
    });

    test('keepAll updates each origin session and live controller', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      final _Trash trash = _Trash();

      final MediaAsset c1 = _asset('c1');
      final MediaAsset s1 = _asset('s1');
      media.assetsById['c1'] = c1;
      media.assetsById['s1'] = s1;

      await local.saveSession(
        DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{'c1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final SmartDeckController smartDeck = SmartDeckController(
        media: media,
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[s1],
        ),
      );
      Get.put<SmartDeckController>(smartDeck);
      smartDeck.ready.value = true;
      smartDeck.thumbnails[s1.id] = Uint8List(1);
      smartDeck.markCurrent(DeckMark.delete);

      final ReviewController review = ReviewController(
        media: media,
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[c1, s1],
        initialOriginSessionKeys: <String, String>{
          'c1': 'all',
          's1': 'smart:screenshots',
        },
        filterKeyOverride: 'union',
      );

      await review.keepAll();

      expect(smartDeck.marks['s1'], DeckMark.keep);

      final DeckSession? cleanSession = (await local.loadSession('all'))
          .fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(cleanSession?.marks['c1'], DeckMark.keep);

      final DeckSession? smartSession = (await local.loadSession(
        'smart:screenshots',
      )).fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(smartSession?.marks['s1'], DeckMark.keep);
    });

    test(
      'permanent delete removes marks from both sessions and calls controllers',
      () async {
        final _Media media = _Media();
        final _Local local = _Local();
        final _Trash trash = _Trash();

        final MediaAsset c1 = _asset('c1', size: 2 * 1048576);
        final MediaAsset s1 = _asset('s1', size: 3 * 1048576);
        media.assetsById['c1'] = c1;
        media.assetsById['s1'] = s1;

        await local.saveSession(
          DeckSession(
            filterKey: 'all',
            currentIndex: 1,
            marks: <String, DeckMark>{'c1': DeckMark.delete},
            favouriteIds: const <String>{},
          ),
        );

        final SmartDeckController smartDeck = SmartDeckController(
          media: media,
          local: local,
          initialLaunch: SmartDeckLaunch(
            deckId: SmartDeckId.screenshots,
            assets: <MediaAsset>[s1],
          ),
        );
        Get.put<SmartDeckController>(smartDeck);
        smartDeck.ready.value = true;
        smartDeck.thumbnails[s1.id] = Uint8List(1);
        smartDeck.markCurrent(DeckMark.delete);

        final ReviewController review = ReviewController(
          media: media,
          trash: trash,
          local: local,
          initialAssets: <MediaAsset>[c1, s1],
          initialOriginSessionKeys: <String, String>{
            'c1': 'all',
            's1': 'smart:screenshots',
          },
          filterKeyOverride: 'union',
        );

        final ReviewDeleteOutcome? outcome = await review.deleteSelected();

        expect(outcome, ReviewDeleteOutcome.deleted);
        expect(trash.deletedIds, <String>['c1', 's1']);

        // Live smart controller updated
        expect(smartDeck.marks.containsKey('s1'), isFalse);
        expect(smartDeck.queue.any((a) => a.id == 's1'), isFalse);

        // Both sessions on disk cleared
        final DeckSession? cleanSession = (await local.loadSession('all'))
            .fold(onSuccess: (s) => s, onFailure: (_) => null);
        expect(cleanSession?.marks.containsKey('c1'), isFalse);

        final DeckSession? smartSession = (await local.loadSession(
          'smart:screenshots',
        )).fold(onSuccess: (s) => s, onFailure: (_) => null);
        expect(smartSession?.marks.containsKey('s1'), isFalse);

        // History recorded freed MB (5 MB)
        expect(local.history.length, 1);
        expect(local.history.first.mbFreed, 5.0);
        expect(local.history.first.mbTrashed, 0.0);
      },
    );

    test('denied permanent delete clears delete marks from both sessions and calls controllers', () async {
      final _Media media = _Media();
      final _Local local = _Local();
      final _Trash trash = _Trash();

      final MediaAsset c1 = _asset('c1');
      final MediaAsset s1 = _asset('s1');
      media.assetsById['c1'] = c1;
      media.assetsById['s1'] = s1;

      await local.saveSession(
        DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{'c1': DeckMark.delete},
          favouriteIds: const <String>{},
        ),
      );

      final SmartDeckController smartDeck = SmartDeckController(
        media: media,
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[s1],
        ),
      );
      Get.put<SmartDeckController>(smartDeck);
      smartDeck.ready.value = true;
      smartDeck.thumbnails[s1.id] = Uint8List(1);
      smartDeck.markCurrent(DeckMark.delete);

      trash.nextOutcome = const DeleteOutcome(
        deletedIds: <String>[],
        deniedIds: <String>['c1', 's1'],
        failedIds: <String>[],
      );

      final ReviewController review = ReviewController(
        media: media,
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[c1, s1],
        initialOriginSessionKeys: <String, String>{
          'c1': 'all',
          's1': 'smart:screenshots',
        },
        filterKeyOverride: 'union',
      );

      final ReviewDeleteOutcome? outcome = await review.deleteSelected();

      expect(outcome, ReviewDeleteOutcome.denied);
      expect(review.deniedIds, <String>['c1', 's1']);

      // Live smart controller cleared delete mark
      expect(smartDeck.marks.containsKey('s1'), isFalse);

      // Both sessions cleared
      final DeckSession? cleanSession = (await local.loadSession('all'))
          .fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(cleanSession?.marks.containsKey('c1'), isFalse);

      final DeckSession? smartSession = (await local.loadSession(
        'smart:screenshots',
      )).fold(onSuccess: (s) => s, onFailure: (_) => null);
      expect(smartSession?.marks.containsKey('s1'), isFalse);
    });
  });

  group('Smart deck own go-to-review', () {
    test('SmartDeckController.deleteMarkedAssets preserves newest-swipe-last order', () {
      final _Media media = _Media();
      final _Local local = _Local();
      final MediaAsset s1 = _asset('s1');
      final MediaAsset s2 = _asset('s2');
      final MediaAsset s3 = _asset('s3');
      media.assetsById['s1'] = s1;
      media.assetsById['s2'] = s2;
      media.assetsById['s3'] = s3;

      final SmartDeckController controller = SmartDeckController(
        media: media,
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[s1, s2, s3],
        ),
      );
      controller.ready.value = true;
      controller.thumbnails[s1.id] = Uint8List(1);
      controller.thumbnails[s2.id] = Uint8List(1);
      controller.thumbnails[s3.id] = Uint8List(1);

      // Swipe s1 delete, then s2 keep, then s3 delete
      controller.markCurrent(DeckMark.delete);
      controller.markCurrent(DeckMark.keep);
      controller.markCurrent(DeckMark.delete);

      expect(controller.deleteMarkedAssets.map((a) => a.id).toList(), <String>[
        's1',
        's3',
      ]);
    });
  });
}
