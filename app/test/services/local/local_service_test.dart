import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';

void main() {
  late Directory temp;
  late LocalServiceImpl service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_local_test_');
    service = LocalServiceImpl(directoryResolver: () async => temp);
  });

  tearDown(() async {
    // Dispose first: coalescing timers must not fire after the
    // temp directory is gone (they would recreate it on flush).
    await service.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  group('LocalServiceImpl sessions', () {
    test('save then load returns an equal session', () async {
      const DeckSession session = DeckSession(
        filterKey: 'all',
        currentIndex: 7,
        marks: <String, DeckMark>{
          'a': DeckMark.keep,
          'b': DeckMark.delete,
          'c': DeckMark.maybe,
          'd': DeckMark.favourite,
        },
        favouriteIds: <String>{'d'},
      );
      final Result<void> saved = await service.saveSession(session);
      expect(saved.isSuccess, isTrue);

      final Result<DeckSession?> loaded = await service.loadSession('all');
      expect(loaded.isSuccess, isTrue);
      final DeckSession? back = loaded.fold(
        onSuccess: (DeckSession? value) => value,
        onFailure: (_) => null,
      );
      expect(back, isNotNull);
      expect(back?.filterKey, 'all');
      expect(back?.currentIndex, 7);
      expect(back?.marks, session.marks);
      expect(back?.favouriteIds, <String>{'d'});
    });

    test('unknown filter key loads as null, not failure', () async {
      final Result<DeckSession?> loaded = await service.loadSession('nope');
      expect(loaded.isSuccess, isTrue);
      expect(
        loaded.fold(
          onSuccess: (DeckSession? value) => value,
          onFailure: (_) => null,
        ),
        isNull,
      );
    });

    test('saving a second key does not clobber the first', () async {
      await service.saveSession(
        const DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{},
          favouriteIds: <String>{},
        ),
      );
      await service.saveSession(
        const DeckSession(
          filterKey: 'month:2026-10',
          currentIndex: 3,
          marks: <String, DeckMark>{},
          favouriteIds: <String>{},
        ),
      );
      final Result<DeckSession?> first = await service.loadSession('all');
      expect(
        first.fold(
          onSuccess: (DeckSession? value) => value?.currentIndex,
          onFailure: (_) => -1,
        ),
        1,
      );
    });
  });

  group('LocalServiceImpl trash record', () {
    test('record then load returns newest first; remove drops ids', () async {
      final DateTime early = DateTime(2026, 10, 24, 9);
      final DateTime late = DateTime(2026, 10, 25, 9);
      await service.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: '1',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 100,
          trashedAt: early,
        ),
        TrashEntry(
          assetId: '2',
          typeInt: 2,
          width: 20,
          height: 20,
          sizeBytes: 200,
          trashedAt: late,
        ),
      ]);
      final Result<List<TrashEntry>> loaded = await service.loadTrashEntries();
      final List<TrashEntry> entries = loaded.fold(
        onSuccess: (List<TrashEntry> value) => value,
        onFailure: (_) => <TrashEntry>[],
      );
      expect(entries.map((TrashEntry e) => e.assetId).toList(), <String>[
        '2',
        '1',
      ]);

      await service.removeTrashEntries(<String>['2']);
      final Result<List<TrashEntry>> after = await service.loadTrashEntries();
      expect(
        after.fold(
          onSuccess: (List<TrashEntry> value) => value.length,
          onFailure: (_) => -1,
        ),
        1,
      );

      await service.clearTrashEntries();
      final Result<List<TrashEntry>> cleared = await service.loadTrashEntries();
      expect(
        cleared.fold(
          onSuccess: (List<TrashEntry> value) => value,
          onFailure: (_) => <TrashEntry>[],
        ),
        isEmpty,
      );
    });
  });

  group('LocalServiceImpl history', () {
    test('append then read back, newest first', () async {
      await service.appendHistory(
        HistoryRecord(
          date: DateTime(2026, 10, 24),
          count: 5,
          mbTrashed: 12.5,
          mbFreed: 0,
        ),
      );
      await service.appendHistory(
        HistoryRecord(
          date: DateTime(2026, 10, 25),
          count: 3,
          mbTrashed: 0,
          mbFreed: 8.25,
        ),
      );
      final Result<List<HistoryRecord>> loaded = await service.loadHistory();
      final List<HistoryRecord> records = loaded.fold(
        onSuccess: (List<HistoryRecord> value) => value,
        onFailure: (_) => <HistoryRecord>[],
      );
      expect(records.length, 2);
      expect(records.first.count, 3);
      expect(records.first.mbFreed, 8.25);
      expect(records.last.mbTrashed, 12.5);
    });
  });

  group('LocalServiceImpl tutorial flag', () {
    test('defaults false and toggles both ways', () async {
      expect(
        (await service.isTutorialSeen()).fold(
          onSuccess: (bool value) => value,
          onFailure: (_) => true,
        ),
        isFalse,
      );
      await service.setTutorialSeen(true);
      expect(
        (await service.isTutorialSeen()).fold(
          onSuccess: (bool value) => value,
          onFailure: (_) => false,
        ),
        isTrue,
      );
      await service.setTutorialSeen(false);
      expect(
        (await service.isTutorialSeen()).fold(
          onSuccess: (bool value) => value,
          onFailure: (_) => true,
        ),
        isFalse,
      );
    });
  });

  group('LocalServiceImpl directory resolution (Phase 1.4)', () {
    test(
      'documents directory resolves exactly once across operations',
      () async {
        int resolutions = 0;
        final LocalServiceImpl counting = LocalServiceImpl(
          directoryResolver: () async {
            resolutions++;
            return temp;
          },
        );
        // Pre-fix this paid one platform-channel round-trip per call
        // (saveSession alone resolves twice: read + write).
        await counting.loadSettings();
        await counting.saveSession(
          const DeckSession(
            filterKey: 'all',
            currentIndex: 0,
            marks: <String, DeckMark>{},
            favouriteIds: <String>{},
          ),
        );
        await counting.loadSession('all');
        await counting.loadTrashEntries();
        await counting.loadAnalyses();
        await counting.isTutorialSeen();
        expect(resolutions, 1);
      },
    );

    test('concurrent first calls share one resolution', () async {
      int resolutions = 0;
      final LocalServiceImpl counting = LocalServiceImpl(
        directoryResolver: () async {
          resolutions++;
          return temp;
        },
      );
      await Future.wait<void>(<Future<void>>[
        counting.loadSettings().then((_) {}),
        counting.loadTrashEntries().then((_) {}),
        counting.loadAnalyses().then((_) {}),
      ]);
      expect(resolutions, 1);
    });
  });
}
