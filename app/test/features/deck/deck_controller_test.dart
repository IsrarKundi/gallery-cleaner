// DeckController tests with in-memory fakes (no device, no MediaStore).
//
// Covers: permission denied / failure / limited / full, all four mark
// directions, multi-step undo, filter change starting a fresh queue,
// session resume (including marks for assets no longer present),
// meter totals (trashed MB never counted as freed), denied-mark
// rewind, tutorial flag, pagination and thumbnail preloading.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_filter.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1x1 PNG, so widget tests can render thumbnails for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

List<MediaAsset> defaultAssets() {
  MediaAsset asset(String id, int size, DateTime date, String album) {
    return MediaAsset(
      id: id,
      type: MediaAssetType.image,
      width: 10,
      height: 10,
      sizeBytes: size,
      createDate: date,
      title: '$id.jpg',
      albumName: album,
    );
  }

  return <MediaAsset>[
    asset('a1', 1000000, DateTime(2026, 10, 5), 'Camera'),
    asset('a2', 2000000, DateTime(2026, 10, 6), 'Camera'),
    asset('a3', 500000, DateTime(2026, 9, 2), 'Camera'),
    asset('a4', 3000000, DateTime(2026, 9, 3), 'Downloads'),
    asset('a5', 1500000, DateTime(2025, 10, 1), 'Downloads'),
    asset('a6', 2500000, DateTime(2025, 10, 2), 'Downloads'),
  ];
}

class FakeMedia implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  FakeMedia({
    this.permission = MediaPermission.grantedFull,
    this.failPermission = false,
    List<MediaAsset>? assets,
  }) : assets = assets ?? defaultAssets();

  final MediaPermission permission;
  final bool failPermission;
  final List<MediaAsset> assets;

  List<MediaAsset> _filtered({String? albumId, String? monthKey}) {
    Iterable<MediaAsset> result = assets;
    if (albumId == 'cam') {
      result = result.where((MediaAsset a) => a.albumName == 'Camera');
    } else if (albumId == 'dl') {
      result = result.where((MediaAsset a) => a.albumName == 'Downloads');
    }
    if (monthKey != null) {
      result = result.where((MediaAsset a) {
        final DateTime d = a.createDate;
        return '${d.year}-${d.month.toString().padLeft(2, '0')}' == monthKey;
      });
    }
    return result.toList();
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    if (failPermission) {
      return const Failure<MediaPermission>(
        AppFailure(messageKey: AppStrings.errorMediaPermission),
      );
    }
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 6),
      MediaAlbum(id: 'cam', name: 'Camera', count: 3),
      MediaAlbum(id: 'dl', name: 'Downloads', count: 3),
    ]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    final List<MediaAsset> filtered = _filtered(
      albumId: albumId,
      monthKey: monthKey,
    );
    final int start = page * pageSize;
    if (start >= filtered.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, filtered.length);
    return Success<List<MediaAsset>>(filtered.sublist(start, end));
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_png);
  }
}

class FakeTrash implements TrashService {
  FakeTrash({List<TrashEntry>? entries}) : entries = entries ?? <TrashEntry>[];

  final List<TrashEntry> entries;

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    return const Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    return const Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return Success<List<TrashEntry>>(List<TrashEntry>.of(entries));
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    return const Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }
}

class FakeLocal implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<HistoryRecord> historyRecords = <HistoryRecord>[];
  final List<TrashEntry> trash = <TrashEntry>[];
  bool tutorialSeen = false;

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    trash.addAll(entries);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return Success<List<TrashEntry>>(List<TrashEntry>.of(trash));
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    trash.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    trash.clear();
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    historyRecords.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return Success<List<HistoryRecord>>(List<HistoryRecord>.of(historyRecords));
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return Success<bool>(tutorialSeen);
  }

  final Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};
  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    for (final PhotoAnalysis a in analyses) {
      _analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(_analyses),
    );
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    tutorialSeen = seen;
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }
}

DeckController makeController({
  MediaService? media,
  TrashService? trash,
  LocalService? local,
}) {
  return DeckController(
    media: media ?? FakeMedia(),
    trash: trash ?? FakeTrash(),
    local: local ?? FakeLocal(),
  );
}

void main() {
  group('permission states', () {
    test('denied renders denied state with an empty queue', () async {
      final DeckController controller = makeController(
        media: FakeMedia(permission: MediaPermission.denied),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.denied);
      expect(controller.queue, isEmpty);
    });

    test('permission failure renders error state with the key', () async {
      final DeckController controller = makeController(
        media: FakeMedia(failPermission: true),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.error);
      expect(controller.errorKey.value, AppStrings.errorMediaPermission);
    });

    test('limited grant loads exactly the granted photos', () async {
      final DeckController controller = makeController(
        media: FakeMedia(permission: MediaPermission.grantedLimited),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.isPartialAccess, isTrue);
      expect(controller.queue.length, 6);
      expect(controller.currentAsset?.id, 'a1');
    });

    test('full grant loads the queue and derives months', () async {
      final DeckController controller = makeController();
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.isPartialAccess, isFalse);
      expect(controller.months, <String>['2026-10', '2026-09', '2025-10']);
      // Phase 2.2: albums load lazily, not at init.
      expect(controller.albums, isEmpty);
      await controller.ensureAlbums();
      expect(controller.albums.map((a) => a.name).toList(), contains('Camera'));
    });
  });

  group('marks, undo and meter', () {
    test('all four mark directions record and advance', () async {
      final DeckController controller = makeController();
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      await controller.markCurrent(DeckMark.delete);
      controller.markCurrent(DeckMark.maybe);
      controller.markCurrent(DeckMark.favourite);
      expect(controller.marks, <String, DeckMark>{
        'a1': DeckMark.keep,
        'a2': DeckMark.delete,
        'a3': DeckMark.maybe,
        'a4': DeckMark.favourite,
      });
      expect(controller.favouriteIds, <String>{'a4'});
      expect(controller.currentIndex.value, 4);
      expect(controller.currentAsset?.id, 'a5');
    });

    test('multi-step undo returns to each card in order', () async {
      final DeckController controller = makeController();
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      await controller.markCurrent(DeckMark.delete);
      controller.undo();
      expect(controller.currentAsset?.id, 'a2');
      expect(controller.marks.containsKey('a2'), isFalse);
      controller.undo();
      expect(controller.currentAsset?.id, 'a1');
      expect(controller.marks, isEmpty);
      expect(controller.canUndo, isFalse);
      controller.undo();
      expect(controller.currentAsset?.id, 'a1');
    });

    test('meter counts marked and freed separately, never trashed', () async {
      final FakeLocal local = FakeLocal()
        ..historyRecords.add(
          HistoryRecord(
            date: DateTime(2026, 10, 24),
            count: 2,
            mbTrashed: 0,
            mbFreed: 5,
          ),
        );
      final FakeTrash trash = FakeTrash(
        entries: <TrashEntry>[
          TrashEntry(
            assetId: 'x',
            typeInt: 1,
            width: 10,
            height: 10,
            sizeBytes: 4000000,
            trashedAt: DateTime(2026, 10, 20),
          ),
        ],
      );
      final DeckController controller = makeController(
        trash: trash,
        local: local,
      );
      await controller.init();
      await controller.markCurrent(DeckMark.delete);
      await controller.markCurrent(DeckMark.delete);
      final meter = controller.meter;
      expect(meter.markedBytes, 3000000);
      expect(meter.inTrashBytes, 4000000);
      expect(meter.freedMb, 5);
      expect(meter.recoverableUntil, DateTime(2026, 11, 19));
    });

    test('clearDeleteMarks rewinds denied ids back onto the deck', () async {
      final DeckController controller = makeController();
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      await controller.markCurrent(DeckMark.delete);
      controller.markCurrent(DeckMark.keep);
      controller.clearDeleteMarks(<String>['a2']);
      expect(controller.marks.containsKey('a2'), isFalse);
      expect(controller.currentAsset?.id, 'a2');
    });
  });

  group('filters, sessions and tutorial', () {
    test('filter change starts a fresh queue under a new key', () async {
      final FakeLocal local = FakeLocal();
      final DeckController controller = makeController(local: local);
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      await controller.setFilter(const DeckFilter.album('cam'));
      expect(controller.filter.value.filterKey, 'album:cam');
      expect(controller.queue.map((a) => a.id).toList(), <String>[
        'a1',
        'a2',
        'a3',
      ]);
      expect(controller.marks, isEmpty);
      expect(controller.currentAsset?.id, 'a1');
      await controller.setFilter(const DeckFilter.month('2026-09'));
      expect(controller.queue.map((a) => a.id).toList(), <String>['a3', 'a4']);
    });

    test('session resume restores index and marks', () async {
      final FakeLocal local = FakeLocal();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 1,
        marks: <String, DeckMark>{'a1': DeckMark.keep},
        favouriteIds: <String>{},
      );
      final DeckController controller = makeController(local: local);
      await controller.init();
      expect(controller.marks['a1'], DeckMark.keep);
      expect(controller.currentAsset?.id, 'a2');
    });

    test(
      'session marks for missing assets are skipped, not crashed on',
      () async {
        final FakeLocal local = FakeLocal();
        local.sessions['all'] = const DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{
            'ghost': DeckMark.delete,
            'a1': DeckMark.keep,
          },
          favouriteIds: <String>{},
        );
        final DeckController controller = makeController(local: local);
        await controller.init();
        expect(controller.status.value, DeckStatus.ready);
        expect(controller.currentAsset?.id, 'a2');
        expect(controller.meter.markedBytes, 0);
      },
    );

    test('marks persist on every mark', () async {
      final FakeLocal local = FakeLocal();
      final DeckController controller = makeController(local: local);
      await controller.init();
      await controller.markCurrent(DeckMark.delete);
      expect(local.sessions['all']?.marks['a1'], DeckMark.delete);
      expect(local.sessions['all']?.currentIndex, 1);
    });

    test('tutorial shows on first run and dismiss sets the flag', () async {
      final FakeLocal local = FakeLocal();
      final DeckController controller = makeController(local: local);
      await controller.init();
      expect(controller.showTutorial.value, isTrue);
      await controller.dismissTutorial();
      expect(controller.showTutorial.value, isFalse);
      expect(local.tutorialSeen, isTrue);
    });
  });

  group('pagination and thumbnails', () {
    test('nearing the end loads the next page in background', () async {
      final List<MediaAsset> many = List<MediaAsset>.generate(
        120,
        (int i) => MediaAsset(
          id: 'p$i',
          type: MediaAssetType.image,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          createDate: DateTime(2026, 10, 1),
          title: 'p$i.jpg',
          albumName: 'Recent',
        ),
      );
      final DeckController controller = makeController(
        media: FakeMedia(assets: many),
      );
      await controller.init();
      expect(controller.queue.length, 50);
      for (int i = 0; i < 41; i++) {
        controller.markCurrent(DeckMark.keep);
      }
      for (int i = 0; i < 50 && controller.queue.length < 100; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.queue.length, 100);
    });

    test('current card plus next thumbnails preload', () async {
      final DeckController controller = makeController();
      await controller.init();
      for (int i = 0; i < 20 && controller.thumbnails.length < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.thumbnails.containsKey('a1'), isTrue);
      expect(controller.thumbnails.containsKey('a2'), isTrue);
    });
  });
}
