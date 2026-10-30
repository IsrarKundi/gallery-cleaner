// Planner tests for the state-based reminders (fix plan
// Stage 1, requirements §7). The planner is pure: every test
// drives it with a fixed clock and an observed state, and pins
// the owner-approved times (first reminder, one repeat, stop),
// the 19:00 evening placement, the one-per-day rule with
// priority order, and the cancellation semantics (a state that
// stops being true loses its track and its pending steps).

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/services/notifications/reminder.dart';
import 'package:klara/services/notifications/reminder_planner.dart';

ReminderObservation observed({
  int waitingPhotos = 0,
  int waitingVideos = 0,
  bool finishedDeck = false,
  bool everDeleted = false,
  bool everSwiped = false,
  bool mediaGranted = false,
}) {
  return ReminderObservation(
    waitingPhotos: waitingPhotos,
    waitingVideos: waitingVideos,
    finishedDeck: finishedDeck,
    everDeleted: everDeleted,
    everSwiped: everSwiped,
    mediaGranted: mediaGranted,
  );
}

/// Monday 2 Nov 2026, 10:00 local — a plain morning "now".
final DateTime t0 = DateTime(2026, 11, 2, 10);

DateTime evening(int day) => DateTime(2026, 11, day, 19);

void main() {
  const ReminderPlanner planner = ReminderPlanner();

  group('evening slot', () {
    test('before 19:00 lands the same evening', () {
      expect(
        ReminderPlanner.eveningSlot(DateTime(2026, 11, 2, 10)),
        evening(2),
      );
    });

    test('after 19:00 lands the next evening', () {
      expect(
        ReminderPlanner.eveningSlot(DateTime(2026, 11, 2, 20, 30)),
        evening(3),
      );
    });

    test('exactly 19:00 is the slot itself', () {
      expect(ReminderPlanner.eveningSlot(evening(2)), evening(2));
    });
  });

  group('waiting state (plan state 1)', () {
    test('first reminder after 1 day, repeat at day 4, both 19:00', () {
      // finishedDeck: true isolates the waiting ladder (the
      // unfinished ladder is covered by its own group).
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(
          waitingPhotos: 3,
          everSwiped: true,
          finishedDeck: true,
        ),
        record: const ReminderRecord(),
      );
      expect(plan.schedule, hasLength(2));
      expect(plan.schedule[0].kind, ReminderStateKind.waiting);
      expect(plan.schedule[0].step, 0);
      expect(plan.schedule[0].fireAt, evening(3));
      expect(plan.schedule[0].titleKey, AppStrings.reminderWaitingTitle);
      expect(plan.schedule[1].step, 1);
      expect(plan.schedule[1].fireAt, evening(6));
      final ReminderTrack track =
          plan.record.tracks[ReminderStateKind.waiting]!;
      expect(track.startedAt, t0);
      expect(track.sentCount, 0);
    });

    test('a fired step counts as sent at the next refresh', () {
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: t0,
            planned: <int, DateTime>{0: evening(3), 1: evening(6)},
          ),
        },
      );
      final ReminderPlan plan = planner.plan(
        now: DateTime(2026, 11, 4, 9),
        observed: observed(
          waitingPhotos: 2,
          everSwiped: true,
          finishedDeck: true,
        ),
        record: before,
      );
      final ReminderTrack track =
          plan.record.tracks[ReminderStateKind.waiting]!;
      expect(track.sentCount, 1);
      // Only the repeat remains, on its original evening.
      expect(plan.schedule, hasLength(1));
      expect(plan.schedule.single.step, 1);
      expect(plan.schedule.single.fireAt, evening(6));
    });

    test('finishing the work drops the track and the schedule', () {
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: t0,
            planned: <int, DateTime>{0: evening(3), 1: evening(6)},
          ),
        },
      );
      // The waiting photos were deleted (history exists now):
      // no state is true, so the track and its pending steps
      // are gone — the cancellation rule.
      final ReminderPlan plan = planner.plan(
        now: DateTime(2026, 11, 2, 18),
        observed: observed(
          everSwiped: true,
          finishedDeck: true,
          everDeleted: true,
        ),
        record: before,
      );
      expect(plan.schedule, isEmpty);
      expect(plan.record.tracks, isEmpty);
    });
  });

  group('finished deck, nothing deleted (plan state 2)', () {
    test('fires at day 1 and day 4 with the finished copy', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(finishedDeck: true, everSwiped: true),
        record: const ReminderRecord(),
      );
      expect(plan.schedule, hasLength(2));
      expect(
        plan.schedule.every(
          (ScheduledReminder r) =>
              r.kind == ReminderStateKind.finishedNoDelete &&
              r.titleKey == AppStrings.reminderFinishedTitle,
        ),
        isTrue,
      );
      expect(plan.schedule[0].fireAt, evening(3));
      expect(plan.schedule[1].fireAt, evening(6));
    });

    test('not active once anything was deleted', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(
          finishedDeck: true,
          everSwiped: true,
          everDeleted: true,
        ),
        record: const ReminderRecord(),
      );
      expect(
        plan.record.tracks.containsKey(ReminderStateKind.finishedNoDelete),
        isFalse,
      );
    });

    test('waiting photos outrank it (state 1, not state 2)', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(
          finishedDeck: true,
          everSwiped: true,
          waitingPhotos: 1,
        ),
        record: const ReminderRecord(),
      );
      expect(
        plan.record.tracks.containsKey(ReminderStateKind.finishedNoDelete),
        isFalse,
      );
      expect(plan.record.tracks.keys, contains(ReminderStateKind.waiting));
    });
  });

  group('unfinished deck (plan states 3 + 4)', () {
    test('simple reminder at day 1; counted step waits for counts', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(everSwiped: true),
        record: const ReminderRecord(),
      );
      expect(plan.schedule, hasLength(1));
      final ScheduledReminder only = plan.schedule.single;
      expect(only.kind, ReminderStateKind.unfinished);
      expect(only.step, 0);
      expect(only.fireAt, evening(3));
      expect(only.titleKey, AppStrings.reminderUnfinishedTitle);
    });

    test('counted step is planned once truthful counts exist', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(
          everSwiped: true,
          waitingPhotos: 4,
          waitingVideos: 1,
        ),
        record: const ReminderRecord(),
      );
      final ScheduledReminder counted = plan.schedule.firstWhere(
        (ScheduledReminder r) => r.needsCounts,
      );
      expect(counted.kind, ReminderStateKind.unfinished);
      expect(counted.step, 1);
      expect(counted.titleKey, AppStrings.reminderCountsTitle);
      expect(counted.bodyKey, AppStrings.reminderCountsBody);
    });

    test('a scheduled counted step is un-planned when counts hit zero', () {
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.unfinished: ReminderTrack(
            startedAt: t0,
            planned: <int, DateTime>{0: evening(3), 1: evening(6)},
          ),
        },
      );
      final ReminderPlan plan = planner.plan(
        now: DateTime(2026, 11, 2, 12),
        observed: observed(everSwiped: true),
        record: before,
      );
      expect(
        plan.schedule.map((ScheduledReminder r) => r.step),
        isNot(contains(1)),
      );
    });
  });

  group('never swiped (plan state 5)', () {
    test('fires at day 2 and day 7, then stops', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(mediaGranted: true),
        record: const ReminderRecord(),
      );
      expect(plan.schedule, hasLength(2));
      expect(plan.schedule[0].kind, ReminderStateKind.neverSwiped);
      expect(plan.schedule[0].fireAt, evening(4));
      expect(plan.schedule[1].fireAt, evening(9));
    });

    test('needs photo access granted', () {
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(mediaGranted: false),
        record: const ReminderRecord(),
      );
      expect(plan.schedule, isEmpty);
    });
  });

  group('one per day, most important first', () {
    test('colliding steps spread over consecutive evenings', () {
      // Waiting + unfinished both start now: day-1 steps collide,
      // day-4 steps collide. Waiting (priority) keeps its days.
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(everSwiped: true, waitingPhotos: 2),
        record: const ReminderRecord(),
      );
      final Map<String, DateTime> byStep = <String, DateTime>{
        for (final ScheduledReminder r in plan.schedule)
          '${r.kind.name}:${r.step}': r.fireAt,
      };
      expect(byStep['waiting:0'], evening(3));
      expect(byStep['unfinished:0'], evening(4));
      expect(byStep['waiting:1'], evening(6));
      expect(byStep['unfinished:1'], evening(7));
      final Set<String> days = plan.schedule
          .map((ScheduledReminder r) => '${r.fireAt.day}')
          .toSet();
      expect(days, hasLength(plan.schedule.length));
    });

    test('state 1 due later the same day beats a lower state due earlier', () {
      // Checker N1: both steps fall due on Mon 2 Nov — the
      // unfinished step at 09:00, the waiting step at 14:00.
      // They compete for the same evening (2 Nov, 19:00): the
      // more important state (waiting) takes it even though it
      // became due later in the day, and the unfinished step
      // defers to the next evening — it is not dropped. The
      // day-4 steps repeat the pattern on 5 Nov.
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.unfinished: ReminderTrack(
            startedAt: DateTime(2026, 11, 1, 9),
          ),
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: DateTime(2026, 11, 1, 14),
          ),
        },
      );
      final ReminderPlan plan = planner.plan(
        now: DateTime(2026, 11, 2, 8),
        observed: observed(everSwiped: true, waitingPhotos: 2),
        record: before,
      );
      final Map<String, DateTime> byStep = <String, DateTime>{
        for (final ScheduledReminder r in plan.schedule)
          '${r.kind.name}:${r.step}': r.fireAt,
      };
      expect(byStep['waiting:0'], evening(2));
      expect(byStep['unfinished:0'], evening(3));
      expect(byStep['waiting:1'], evening(5));
      expect(byStep['unfinished:1'], evening(6));
    });

    test('priority never pulls a step before its own due evening', () {
      // The unfinished step is due today; the waiting state only
      // starts now, so its first step is due tomorrow. Priority
      // orders competition for an evening — it does not shorten
      // the waiting ladder: the unfinished step keeps tonight and
      // the waiting step fires on its own due evening.
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.unfinished: ReminderTrack(
            startedAt: DateTime(2026, 11, 1, 10),
          ),
        },
      );
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(everSwiped: true, waitingPhotos: 1),
        record: before,
      );
      final Map<String, DateTime> byStep = <String, DateTime>{
        for (final ScheduledReminder r in plan.schedule)
          '${r.kind.name}:${r.step}': r.fireAt,
      };
      expect(byStep['unfinished:0'], evening(2));
      expect(byStep['waiting:0'], evening(3));
      expect(byStep['unfinished:1'], evening(5));
      expect(byStep['waiting:1'], evening(6));
    });
  });

  group('missed steps', () {
    test('a step never scheduled fires at the next evening, not dropped', () {
      // State first observed 10 days ago (e.g. reminders were
      // off): nothing planned, nothing sent.
      final ReminderRecord before = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: t0.subtract(const Duration(days: 10)),
          ),
        },
      );
      final ReminderPlan plan = planner.plan(
        now: t0,
        observed: observed(
          waitingPhotos: 1,
          everSwiped: true,
          finishedDeck: true,
        ),
        record: before,
      );
      expect(plan.schedule, hasLength(2));
      expect(plan.schedule[0].fireAt, evening(2));
      expect(plan.schedule[1].fireAt, evening(3));
      expect(plan.record.tracks[ReminderStateKind.waiting]!.sentCount, 0);
    });
  });

  group('record JSON', () {
    test('round-trips tracks, planned steps and sent counts', () {
      final ReminderRecord record = ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: t0,
            sentCount: 1,
            planned: <int, DateTime>{1: evening(6)},
          ),
        },
      );
      final ReminderRecord restored = ReminderRecord.fromJson(record.toJson());
      final ReminderTrack track = restored.tracks[ReminderStateKind.waiting]!;
      expect(track.startedAt, t0);
      expect(track.sentCount, 1);
      expect(track.planned, <int, DateTime>{1: evening(6)});
    });
  });
}
