// Phase 2B retention math tests (requirements §7): snooze
// semantics, goal week math, streak math, On This Day predicate,
// session summary accounting and projection math. All pure — no
// services, no platform — so they run on this host.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/deck/model/retention.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(String id, {int size = 2 * 1024 * 1024, DateTime? date}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date ?? DateTime(2025, 10, 25),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

HistoryRecord _history(DateTime date, double freed, [double trashed = 0]) {
  return HistoryRecord(
    date: date,
    count: 1,
    mbTrashed: trashed,
    mbFreed: freed,
  );
}

void main() {
  group('snooze', () {
    test('snoozed while today is before the return date', () {
      expect(isSnoozed(DateTime(2026, 11, 1), DateTime(2026, 10, 25)), isTrue);
      expect(
        isSnoozed(DateTime(2026, 10, 25), DateTime(2026, 10, 25)),
        isFalse,
      );
      expect(
        isSnoozed(DateTime(2026, 10, 24), DateTime(2026, 10, 25)),
        isFalse,
      );
    });

    test('snoozeUntilFor adds whole days, date-only', () {
      expect(
        snoozeUntilFor(7, DateTime(2026, 10, 25, 15, 30)),
        DateTime(2026, 11, 1),
      );
    });

    test('expiry clears only expired Maybe marks, never other marks', () {
      final Map<String, DeckMark> marks = <String, DeckMark>{
        'a': DeckMark.maybe,
        'b': DeckMark.maybe,
        'c': DeckMark.keep,
      };
      final Map<String, DateTime> snoozes = <String, DateTime>{
        'a': DateTime(2026, 10, 25),
        'b': DateTime(2026, 11, 1),
        'c': DateTime(2026, 10, 20),
      };
      final result = applySnoozeExpiry(marks, snoozes, DateTime(2026, 10, 25));
      // 'a' expired today: its Maybe mark clears. 'b' still snoozed.
      // 'c' has a stale snooze record but is Keep, so its mark stays
      // while the record itself is reported for clearing.
      expect(result.marks.containsKey('a'), isFalse);
      expect(result.marks['b'], DeckMark.maybe);
      expect(result.marks['c'], DeckMark.keep);
      expect(result.clearedIds, <String>['a', 'c']);
      // The input map is untouched (pure function).
      expect(marks['a'], DeckMark.maybe);
    });

    test('expiredSnoozeIds lists exactly the expired records', () {
      expect(
        expiredSnoozeIds(<String, DateTime>{
          'a': DateTime(2026, 10, 25),
          'b': DateTime(2026, 10, 26),
        }, DateTime(2026, 10, 25)),
        <String>['a'],
      );
    });
  });

  group('goals', () {
    test('week boundary is Monday: Sunday counts, prior Monday does not', () {
      // 2026-10-25 is a Sunday; its week starts Mon 2026-10-19.
      final List<HistoryRecord> history = <HistoryRecord>[
        _history(DateTime(2026, 10, 19), 100),
        _history(DateTime(2026, 10, 25), 50),
        _history(DateTime(2026, 10, 18), 999),
        _history(DateTime(2026, 10, 26), 999),
      ];
      expect(weekFreedMb(history, DateTime(2026, 10, 25)), 150);
    });

    test('freed-only: trashed MB never counts toward the goal', () {
      final List<HistoryRecord> history = <HistoryRecord>[
        _history(DateTime(2026, 10, 20), 0, 500),
        _history(DateTime(2026, 10, 21), 25, 500),
      ];
      expect(weekFreedMb(history, DateTime(2026, 10, 21)), 25);
    });

    test('goal presets are 500 MB, 1 GB, 2 GB with 1 GB default', () {
      expect(goalPresetsMb, <double>[512, 1024, 2048]);
      expect(defaultGoalMb, 1024);
    });
  });

  group('streaks', () {
    test('consecutive days ending today count fully', () {
      final StreakResult result = computeStreak(<DateTime>[
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
      ], DateTime(2026, 10, 25));
      expect(result.current, 3);
      expect(result.best, 3);
    });

    test('a gap over one day resets the current streak', () {
      final StreakResult result = computeStreak(<DateTime>[
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 25),
      ], DateTime(2026, 10, 25));
      expect(result.current, 1);
      expect(result.best, 2);
    });

    test('same-day duplicates count once', () {
      final StreakResult result = computeStreak(<DateTime>[
        DateTime(2026, 10, 25, 9),
        DateTime(2026, 10, 25, 20),
        DateTime(2026, 10, 24),
      ], DateTime(2026, 10, 25));
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('streak stays alive through yesterday when today is quiet', () {
      final StreakResult result = computeStreak(<DateTime>[
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 24),
      ], DateTime(2026, 10, 25));
      expect(result.current, 2);
    });

    test('no recent day means no current streak, best still reported', () {
      final StreakResult result = computeStreak(<DateTime>[
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ], DateTime(2026, 10, 25));
      expect(result.current, 0);
      expect(result.best, 2);
    });
  });

  group('On This Day', () {
    test('same month from a previous year matches regardless of day', () {
      expect(
        isOnThisDay(
          _asset('a', date: DateTime(2023, 10, 25)),
          DateTime(2026, 10, 25),
        ),
        isTrue,
      );
      expect(
        isOnThisDay(
          _asset('b', date: DateTime(2024, 10, 10)),
          DateTime(2026, 10, 25),
        ),
        isTrue,
      );
    });

    test('today photos match, but other days in the current year do not', () {
      expect(
        isOnThisDay(
          _asset('a', date: DateTime(2026, 10, 25)),
          DateTime(2026, 10, 25),
        ),
        isTrue,
      );
      expect(
        isOnThisDay(
          _asset('b', date: DateTime(2026, 10, 1)),
          DateTime(2026, 10, 25),
        ),
        isFalse,
      );
    });

    test('a different month never matches', () {
      expect(
        isOnThisDay(
          _asset('a', date: DateTime(2024, 9, 24)),
          DateTime(2026, 10, 25),
        ),
        isFalse,
      );
    });
  });

  group('session summary', () {
    test('counts marks per queue asset; stale marks contribute nothing', () {
      final SessionSummary summary = computeSessionSummary(
        marks: <String, DeckMark>{
          'a': DeckMark.keep,
          'b': DeckMark.delete,
          'c': DeckMark.maybe,
          'd': DeckMark.favourite,
          'ghost': DeckMark.delete,
        },
        assetsById: <String, MediaAsset>{
          'a': _asset('a', size: 1000),
          'b': _asset('b', size: 2000),
          'c': _asset('c', size: 3000),
          'd': _asset('d', size: 4000),
        },
      );
      expect(summary.reviewed, 4);
      expect(summary.kept, 1);
      expect(summary.deleteMarked, 1);
      expect(summary.deleteMarkedBytes, 2000);
      expect(summary.maybe, 1);
      expect(summary.favourite, 1);
    });

    test('share text labels marked MB "to be freed", never freed', () {
      final SessionSummary summary = computeSessionSummary(
        marks: <String, DeckMark>{'b': DeckMark.delete},
        assetsById: <String, MediaAsset>{
          'b': _asset('b', size: 2 * 1024 * 1024),
        },
      );
      final String text = summaryShareText(summary);
      expect(text, contains('to be freed'));
      expect(text, isNot(contains('2 MB freed')));
    });
  });

  group('projection', () {
    test('projected free is free now plus MB in trash', () {
      expect(projectedFreeMb(1200, 350), 1550);
      expect(projectedFreeMb(0, 0), 0);
    });
  });
}
