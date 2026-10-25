// Phase 2B LocalService retention storage tests (requirements
// §7): snooze records, goal target, completion days and session
// listing round-trip through the JSON implementation on a temp
// directory (never the real documents directory).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';

void main() {
  late Directory temp;
  late LocalServiceImpl service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_retention_test_');
    service = LocalServiceImpl(directoryResolver: () async => temp);
  });

  tearDown(() async {
    await service.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  T unwrap<T>(Result<T> result) {
    return result.fold(
      onSuccess: (T value) => value,
      onFailure: (_) => throw StateError('expected success'),
    );
  }

  group('snoozes', () {
    test('set then load returns the date-only return date', () async {
      expect(
        (await service.setSnooze('a', DateTime(2026, 11, 1, 15, 30))).isSuccess,
        isTrue,
      );
      final Map<String, DateTime> snoozes = unwrap(await service.loadSnoozes());
      expect(snoozes['a'], DateTime(2026, 11, 1));
    });

    test('clearing a snooze removes only that record', () async {
      await service.setSnooze('a', DateTime(2026, 11, 1));
      await service.setSnooze('b', DateTime(2026, 11, 2));
      expect((await service.setSnooze('a', null)).isSuccess, isTrue);
      final Map<String, DateTime> snoozes = unwrap(await service.loadSnoozes());
      expect(snoozes.containsKey('a'), isFalse);
      expect(snoozes['b'], DateTime(2026, 11, 2));
    });
  });

  group('goal', () {
    test('default is 1 GB before anything is saved', () async {
      expect(unwrap(await service.loadGoalTargetMb()), 1024);
    });

    test('saved target round-trips', () async {
      expect((await service.saveGoalTargetMb(512)).isSuccess, isTrue);
      expect(unwrap(await service.loadGoalTargetMb()), 512);
    });
  });

  group('completion days', () {
    test('recording the same day twice stores it once', () async {
      await service.recordCompletionDay(DateTime(2026, 10, 25, 9));
      await service.recordCompletionDay(DateTime(2026, 10, 25, 20));
      await service.recordCompletionDay(DateTime(2026, 10, 24));
      expect(unwrap(await service.loadCompletionDays()), <DateTime>[
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
      ]);
    });
  });

  group('listSessions', () {
    test('lists every saved session for the Maybe pile', () async {
      await service.saveSession(
        const DeckSession(
          filterKey: 'all',
          currentIndex: 1,
          marks: <String, DeckMark>{'a': DeckMark.maybe},
          favouriteIds: <String>{},
        ),
      );
      await service.saveSession(
        const DeckSession(
          filterKey: 'smart:old',
          currentIndex: 2,
          marks: <String, DeckMark>{'b': DeckMark.keep},
          favouriteIds: <String>{},
        ),
      );
      final List<DeckSession> sessions = unwrap(await service.listSessions());
      expect(sessions.map((DeckSession s) => s.filterKey).toSet(), <String>{
        'all',
        'smart:old',
      });
    });

    test('empty storage lists no sessions, not a failure', () async {
      expect(unwrap(await service.listSessions()), isEmpty);
    });
  });
}
