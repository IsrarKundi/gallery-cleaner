// Phase 4.1: JSON layer — coalescing, serialisation, atomicity,
// salvage (solutions 4.1). Tests run against the real
// [LocalServiceImpl] with temp directories, never platform channels.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/json_file_store.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';

void main() {
  late Directory temp;
  late LocalServiceImpl service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_json_store_test_');
    service = LocalServiceImpl(directoryResolver: () async => temp);
  });

  tearDown(() async {
    await service.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  DeckSession sessionWithMarks(String key, int count) {
    return DeckSession(
      filterKey: key,
      currentIndex: count,
      marks: <String, DeckMark>{
        for (int i = 0; i < count; i++) 'id$i': DeckMark.keep,
      },
      favouriteIds: <String>{},
    );
  }

  Future<DeckSession?> loadSessionOrNull(String key) async {
    final Result<DeckSession?> result = await service.loadSession(key);
    return result.fold(
      onSuccess: (DeckSession? value) => value,
      onFailure: (_) => null,
    );
  }

  group('4.1 coalesced session saves', () {
    test('a save is visible to loads before any flush', () async {
      await service.saveSession(sessionWithMarks('all', 3));
      expect(service.diskWriteCounts['klara_sessions.json'], 0);
      final DeckSession? back = await loadSessionOrNull('all');
      expect(back?.currentIndex, 3);
      expect(back?.marks.length, 3);
    });

    test('1,000 marks cost one disk write after flush', () async {
      for (int i = 0; i < 1000; i++) {
        await service.saveSession(sessionWithMarks('all', i + 1));
      }
      expect(service.diskWriteCounts['klara_sessions.json'], 0);
      await service.flushPendingWrites();
      expect(service.diskWriteCounts['klara_sessions.json'], 1);
      final File file = File('${temp.path}/klara_sessions.json');
      final Map<String, dynamic> onDisk =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final Map<String, dynamic> saved = onDisk['all'] as Map<String, dynamic>;
      expect((saved['marks'] as Map<String, dynamic>).length, 1000);
      // Bytes written (one final file) are ~1x the final size,
      // far under the 2x acceptance bound.
      expect(await file.length(), greaterThan(0));
    });

    test('500 rapid marks lose zero marks', () async {
      for (int i = 0; i < 500; i++) {
        await service.saveSession(sessionWithMarks('all', i + 1));
      }
      await service.flushPendingWrites();
      final DeckSession? back = await loadSessionOrNull('all');
      expect(back?.marks.length, 500);
      expect(back?.currentIndex, 500);
    });

    test('concurrent saves for different keys lose no updates', () async {
      await Future.wait<void>(<Future<void>>[
        for (int i = 0; i < 50; i++)
          service.saveSession(sessionWithMarks('key$i', 1)).then((_) {}),
      ]);
      await service.flushPendingWrites();
      final Result<List<DeckSession>> listed = await service.listSessions();
      final List<DeckSession> sessions = listed.fold(
        onSuccess: (List<DeckSession> value) => value,
        onFailure: (_) => <DeckSession>[],
      );
      expect(sessions.length, 50);
    });

    test(
      'continuous marking still flushes mid-stream (fixed window)',
      () async {
        // The window starts on the first pending write and does NOT
        // reset on later marks: a second mark 800 ms in must not
        // push the flush past the original 1.5 s deadline.
        await service.saveSession(sessionWithMarks('all', 1));
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await service.saveSession(sessionWithMarks('all', 2));
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(service.diskWriteCounts['klara_sessions.json'], 1);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('the coalescing timer flushes on its own', () async {
      await service.saveSession(sessionWithMarks('all', 1));
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(service.diskWriteCounts['klara_sessions.json'], 1);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('flushPendingWrites persists, then a new save starts clean', () async {
      await service.saveSession(sessionWithMarks('all', 1));
      await service.flushPendingWrites();
      expect(service.diskWriteCounts['klara_sessions.json'], 1);
      await service.flushPendingWrites();
      expect(service.diskWriteCounts['klara_sessions.json'], 1);
      await service.saveSession(sessionWithMarks('all', 2));
      await service.flushPendingWrites();
      expect(service.diskWriteCounts['klara_sessions.json'], 2);
    });
  });

  group('4.1 trash is never coalesced', () {
    test('recordTrashed hits disk immediately', () async {
      await service.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: 't1',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 100,
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      expect(service.diskWriteCounts['klara_trash.json'], 1);
      final Result<List<TrashEntry>> loaded = await service.loadTrashEntries();
      expect(
        loaded.fold(
          onSuccess: (List<TrashEntry> v) => v.length,
          onFailure: (_) => -1,
        ),
        1,
      );
    });
  });

  group('4.1 snooze batching', () {
    test('clearSnoozes writes once for the whole batch', () async {
      for (int i = 0; i < 5; i++) {
        await service.setSnooze('s$i', DateTime.utc(2026, 11, 1));
      }
      final int before = service.diskWriteCounts['klara_snoozes.json']!;
      await service.clearSnoozes(<String>['s0', 's1', 's2']);
      expect(service.diskWriteCounts['klara_snoozes.json'], before + 1);
      final Result<Map<String, DateTime>> snoozes = await service.loadSnoozes();
      final Map<String, DateTime> back = snoozes.fold(
        onSuccess: (Map<String, DateTime> v) => v,
        onFailure: (_) => <String, DateTime>{},
      );
      expect(back.keys, <String>{'s3', 's4'});
    });
  });

  group('4.1 salvage', () {
    test(
      'valid JSON with one bad session entry returns the good one',
      () async {
        final File file = File('${temp.path}/klara_sessions.json');
        await file.writeAsString(
          jsonEncode(<String, dynamic>{
            'good': DeckSession(
              filterKey: 'good',
              currentIndex: 2,
              marks: <String, DeckMark>{'a': DeckMark.keep},
              favouriteIds: <String>{},
            ).toJson(),
            // Bad entry: currentIndex has the wrong type.
            'bad': <String, dynamic>{
              'filterKey': 'bad',
              'currentIndex': 'not-an-int',
              'marks': <String, dynamic>{},
              'favouriteIds': <dynamic>[],
            },
          }),
        );
        final Result<List<DeckSession>> listed = await service.listSessions();
        final List<DeckSession> sessions = listed.fold(
          onSuccess: (List<DeckSession> v) => v,
          onFailure: (_) => <DeckSession>[],
        );
        expect(sessions.map((DeckSession s) => s.filterKey), <String>['good']);
        expect(service.salvageReport['klara_sessions.json'], 1);
      },
    );

    test('truncated trash file salvages complete entries', () async {
      String entryJson(String id) {
        return jsonEncode(
          TrashEntry(
            assetId: id,
            typeInt: 1,
            width: 10,
            height: 10,
            sizeBytes: 100,
            trashedAt: DateTime.utc(2026, 10, 26),
          ).toJson(),
        );
      }

      final String full =
          '[${entryJson('t1')},${entryJson('t2')},${entryJson('t3')}]';
      // Cut mid-third-entry: simulates a kill during the old
      // pre-atomic in-place rewrite.
      final String truncated = full.substring(0, full.length - 20);
      await File('${temp.path}/klara_trash.json').writeAsString(truncated);
      final Result<List<TrashEntry>> loaded = await service.loadTrashEntries();
      final List<TrashEntry> entries = loaded.fold(
        onSuccess: (List<TrashEntry> v) => v,
        onFailure: (_) => <TrashEntry>[],
      );
      expect(entries.map((TrashEntry e) => e.assetId).toSet(), <String>{
        't1',
        't2',
      });
      expect(service.salvageReport['klara_trash.json'], greaterThan(0));
    });

    test('a leftover .tmp file is ignored on load', () async {
      await service.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: 't1',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 100,
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      await File('${temp.path}/klara_trash.json.tmp')
          .writeAsString('[{"garbage":true}]');
      final Result<List<TrashEntry>> loaded = await service.loadTrashEntries();
      expect(
        loaded.fold(
          onSuccess: (List<TrashEntry> v) => v.length,
          onFailure: (_) => -1,
        ),
        1,
      );
    });

    test('truncated sessions map reads empty; trash unaffected', () async {
      await File('${temp.path}/klara_sessions.json')
          .writeAsString('{"all":{"filterKey":"all","currentIndex":');
      await service.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: 't1',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 100,
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      expect(await loadSessionOrNull('all'), isNull);
      final Result<List<TrashEntry>> trash = await service.loadTrashEntries();
      expect(
        trash.fold(
          onSuccess: (List<TrashEntry> v) => v.length,
          onFailure: (_) => -1,
        ),
        1,
      );
    });
  });

  group('4.1 failed writes keep data dirty for retry', () {
    test('store-level: write failure keeps dirty, retry succeeds', () async {
      final JsonFileStore store = JsonFileStore(
        fileName: 'probe.json',
        directoryResolver: () async => temp,
      );
      final List<dynamic> snapshot = await store.readList();
      snapshot.add(<String, dynamic>{'a': 1});
      store.scheduleWrite();
      await store.flush();
      expect(store.diskWrites, 1);
      // Break the directory: replace it with a plain file, so the
      // next write fails. The snapshot must stay dirty.
      await temp.delete(recursive: true);
      await File(temp.path).writeAsString('not a directory');
      snapshot.add(<String, dynamic>{'b': 2});
      store.scheduleWrite();
      await store.flush();
      expect(store.isDirty, isTrue);
      expect(store.diskWrites, 1);
      // Restore the directory: the retry now succeeds with both
      // entries — nothing was lost.
      await File(temp.path).delete();
      await temp.create();
      await store.flush();
      expect(store.isDirty, isFalse);
      expect(store.diskWrites, 2);
      final List<dynamic> back = await store.readList();
      expect(back.length, 2);
      await store.close();
    });
  });

  group('4.1 back-compat', () {
    test('a hand-written old-format sessions file loads', () async {
      await File('${temp.path}/klara_sessions.json').writeAsString(
        jsonEncode(<String, dynamic>{
          'all': <String, dynamic>{
            'filterKey': 'all',
            'currentIndex': 4,
            'marks': <String, dynamic>{'x': 'delete', 'y': 'maybe'},
            'favouriteIds': <dynamic>['z'],
          },
        }),
      );
      final DeckSession? back = await loadSessionOrNull('all');
      expect(back?.currentIndex, 4);
      expect(back?.marks['x'], DeckMark.delete);
      expect(back?.marks['y'], DeckMark.maybe);
      expect(back?.favouriteIds, <String>{'z'});
    });
  });
}
