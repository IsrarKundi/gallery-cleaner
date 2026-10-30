// Deck Stage 5 tests (fix plan Stage 5, ADR-020): resume lands
// on the exact photo the user left — even when the decided run
// crosses a page boundary; marks count as review-ask swipes and
// session end flags the swipe ask; a completed Clean-deck trash
// batch publishes its finish summary and counts as a delete
// batch.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/finish/model/finish_summary.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/review_ask/review_ask_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

List<MediaAsset> _assets(int count) {
  return <MediaAsset>[
    for (int i = 0; i < count; i++) _asset('p$i', 1000 * (i + 1)),
  ];
}

class _Media extends Fake implements MediaService {
  _Media(this.assets);

  final List<MediaAsset> assets;

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
  }) async {
    final int start = page * pageSize;
    if (start >= assets.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, assets.length);
    return Success<List<MediaAsset>>(assets.sublist(start, end));
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_png);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return Success<List<MediaAsset>>(
      assets.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
  }
}

class _Trash extends Fake implements TrashService {
  final List<TrashEntry> entries = <TrashEntry>[];
  static final DateTime trashedAt = DateTime(2026, 10, 30, 12);

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    for (final String id in ids) {
      entries.add(
        TrashEntry(
          assetId: id,
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 0,
          trashedAt: trashedAt,
        ),
      );
    }
    return Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: List<String>.of(ids),
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      Success<List<TrashEntry>>(List<TrashEntry>.of(entries));
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};

  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

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
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
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
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);
}

class _Ask extends Fake implements ReviewAskService {
  int swipes = 0;
  final List<({int count, int bytes})> batches = <({int count, int bytes})>[];

  @override
  Future<void> recordSwipe() async {
    swipes++;
  }

  @override
  Future<void> recordDeleteBatch({
    required int count,
    required int bytes,
  }) async {
    batches.add((count: count, bytes: bytes));
  }

  @override
  Future<int> fallbackAmountBytes() async => 0;
}

Future<void> _settleThumbnails(DeckController controller) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (true) {
    final String? id = controller.currentAsset?.id;
    if (id == null || controller.thumbnails.containsKey(id)) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the current thumbnail');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

DeckSession _sessionWithMarks(int count) {
  return DeckSession(
    filterKey: 'all',
    currentIndex: count,
    marks: <String, DeckMark>{
      for (int i = 0; i < count; i++) 'p$i': DeckMark.keep,
    },
    favouriteIds: const <String>{},
  );
}

void main() {
  group('resume (ADR-020 decision 4)', () {
    test('reopening lands on the exact photo left, across a page '
        'boundary', () async {
      final _Local local = _Local();
      local.sessions['all'] = _sessionWithMarks(55);
      final DeckController controller = DeckController(
        media: _Media(_assets(60)),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      // Both pages were loaded to reach the left-off photo.
      expect(controller.queue.length, 60);
      expect(controller.currentIndex.value, 55);
      expect(controller.currentAsset?.id, 'p55');
      expect(controller.isFinished, isFalse);
    });

    test('reopening a fully decided deck shows the finished state, '
        'not a phantom card', () async {
      final _Local local = _Local();
      local.sessions['all'] = _sessionWithMarks(60);
      final DeckController controller = DeckController(
        media: _Media(_assets(60)),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      expect(controller.isFinished, isTrue);
      expect(controller.currentAsset, isNull);
    });

    test('resume within the first page needs no extra page', () async {
      final _Local local = _Local();
      local.sessions['all'] = _sessionWithMarks(30);
      final DeckController controller = DeckController(
        media: _Media(_assets(60)),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      expect(controller.queue.length, 50);
      expect(controller.currentIndex.value, 30);
      expect(controller.currentAsset?.id, 'p30');
    });
  });

  group('swipe counting and the session-end flag', () {
    test('every recorded mark counts; finishing flags the ask', () async {
      final _Ask ask = _Ask();
      final DeckController controller = DeckController(
        media: _Media(_assets(3)),
        trash: _Trash(),
        local: _Local(),
        reviewAsk: ask,
      );
      await controller.init();
      await _settleThumbnails(controller);
      await controller.markCurrent(DeckMark.keep);
      await _settleThumbnails(controller);
      await controller.markCurrent(DeckMark.maybe);
      expect(controller.swipeAskPending.value, isFalse);
      await _settleThumbnails(controller);
      await controller.markCurrent(DeckMark.favourite);
      expect(ask.swipes, 3);
      expect(controller.isFinished, isTrue);
      expect(controller.swipeAskPending.value, isTrue);
    });

    test('smart deck marks count and flag the same way', () async {
      final _Ask ask = _Ask();
      final SmartDeckController controller = SmartDeckController(
        media: _Media(_assets(2)),
        local: _Local(),
        initialLaunch: SmartDeckLaunch(
          assets: _assets(2),
          customSessionKey: 'smart:test',
        ),
        reviewAsk: ask,
      );
      controller.onInit();
      await pumpEventQueue();
      // Settle thumbnails for the current card.
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
      while (!controller.thumbnails.containsKey(
        controller.currentAsset?.id ?? '',
      )) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for the smart deck thumbnail');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      controller.markCurrent(DeckMark.keep);
      while (!controller.thumbnails.containsKey(
        controller.currentAsset?.id ?? '',
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      controller.markCurrent(DeckMark.keep);
      expect(ask.swipes, 2);
      expect(controller.isFinished, isTrue);
      expect(controller.swipeAskPending.value, isTrue);
    });
  });

  group('trash batch completion (ADR-020 decision 1)', () {
    test('a completed flush publishes the finish summary and '
        'counts the batch', () async {
      final _Ask ask = _Ask();
      final _Trash trash = _Trash();
      final DeckController controller = DeckController(
        media: _Media(_assets(3)),
        trash: trash,
        local: _Local(),
        reviewAsk: ask,
      );
      await controller.init();
      await _settleThumbnails(controller);
      // Delete-swipe p0, then swipe on: the second mark commits
      // p0 to the batch (ADR-013).
      await controller.markCurrent(DeckMark.delete);
      await _settleThumbnails(controller);
      await controller.markCurrent(DeckMark.keep);
      await controller.flushAwaitingTrash();
      final FinishSummary? summary = controller.lastFinishSummary.value;
      expect(summary, isNotNull);
      expect(summary!.deletedCount, 1);
      expect(summary.sizeBytes, 1000);
      expect(summary.spaceState, FinishSpaceState.inTrash);
      expect(
        summary.recoverableUntil,
        _Trash.trashedAt.add(const Duration(days: 30)),
      );
      expect(ask.batches, <({int count, int bytes})>[(count: 1, bytes: 1000)]);
    });
  });
}
