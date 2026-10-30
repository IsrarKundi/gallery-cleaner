// The reminder planner (wipe. fix plan Stage 1,
// requirements §7): the pure planning unit for the
// state-based reminders. The model it works on (states,
// steps, tracks, observations) lives in reminder.dart;
// every rule the owner approved is stated in that file's
// header. Given the current time, an observation and the
// persisted record, [ReminderPlanner.plan] settles fired
// steps, drops tracks for states that stopped being true,
// and places every remaining step on its own 19:00 evening
// slot; when two steps want the same evening, the more
// important state takes it (ADR-016 §4).

import 'reminder.dart';

/// The pure planning unit. See the file header for the rules.
class ReminderPlanner {
  const ReminderPlanner();

  /// Local hour reminders fire at: early evening, never night.
  static const int fireHour = 19;

  /// The first [fireHour]:00 local time at or after [earliest].
  static DateTime eveningSlot(DateTime earliest) {
    DateTime slot = DateTime(
      earliest.year,
      earliest.month,
      earliest.day,
      fireHour,
    );
    if (slot.isBefore(earliest)) {
      slot = DateTime(
        earliest.year,
        earliest.month,
        earliest.day + 1,
        fireHour,
      );
    }
    return slot;
  }

  ReminderPlan plan({
    required DateTime now,
    required ReminderObservation observed,
    required ReminderRecord record,
  }) {
    final Map<ReminderStateKind, ReminderTrack> tracks =
        <ReminderStateKind, ReminderTrack>{};

    // Pass 1: keep tracks for states still true (starting new
    // ones at first observation), settle steps whose scheduled
    // time has passed, and drop tracks for states now false —
    // dropping is what cancels a finished state's reminders.
    for (final ReminderStateKind kind in ReminderStateKind.values) {
      if (!observed.isActive(kind)) {
        continue;
      }
      final ReminderTrack? existing = record.tracks[kind];
      final ReminderTrack track = existing == null
          ? ReminderTrack(startedAt: now)
          : ReminderTrack(
              startedAt: existing.startedAt,
              sentCount: existing.sentCount,
              planned: Map<int, DateTime>.of(existing.planned),
            );
      final int stepTotal = reminderSteps[kind]?.length ?? 0;
      track.planned.removeWhere((int step, DateTime at) {
        if (step >= stepTotal) {
          return true;
        }
        if (!at.isAfter(now)) {
          if (step + 1 > track.sentCount) {
            track.sentCount = step + 1;
          }
          return true;
        }
        return false;
      });
      if (track.sentCount > stepTotal) {
        track.sentCount = stepTotal;
      }
      // A counted step already scheduled loses its slot when the
      // counts reach zero (the waiting photos were dealt with):
      // its text would no longer be true. It re-plans if counts
      // exist again at a later refresh.
      if (observed.waitingTotal == 0) {
        final List<ReminderStep> steps = reminderSteps[kind]!;
        track.planned.removeWhere(
          (int step, DateTime at) =>
              step < steps.length && steps[step].needsCounts,
        );
      }
      tracks[kind] = track;
    }

    // Pass 2: place every unsent step (placement is recomputed
    // from the due times on every refresh — the engine cancels
    // and re-schedules the whole set anyway, so a step whose
    // competitor vanished moves back to its own due evening).
    // A step's first-choice evening is the first 19:00 at or
    // after its due time (or tonight, when overdue). Steps are
    // placed in order of that evening; steps wanting the SAME
    // evening are ordered by state priority, so the more
    // important state takes the evening and the other defers to
    // the next free evening — deferred, never dropped, and
    // never placed before its own due evening (ADR-016 §4).
    final List<
      ({ReminderStateKind kind, int step, DateTime due, DateTime evening})
    >
    candidates =
        <
          ({ReminderStateKind kind, int step, DateTime due, DateTime evening})
        >[];
    for (final ReminderStateKind kind in ReminderStateKind.values) {
      final ReminderTrack? track = tracks[kind];
      if (track == null) {
        continue;
      }
      final List<ReminderStep> steps = reminderSteps[kind]!;
      for (int step = track.sentCount; step < steps.length; step++) {
        final ReminderStep def = steps[step];
        if (def.needsCounts && observed.waitingTotal == 0) {
          // No truthful counts exist right now: the step waits
          // for a later refresh instead of inventing numbers.
          continue;
        }
        final DateTime due = track.startedAt.add(def.dueAfterStart);
        candidates.add((
          kind: kind,
          step: step,
          due: due,
          evening: eveningSlot(due.isAfter(now) ? due : now),
        ));
      }
    }
    candidates.sort((a, b) {
      final int byEvening = a.evening.compareTo(b.evening);
      if (byEvening != 0) {
        return byEvening;
      }
      final int byPriority = a.kind.index.compareTo(b.kind.index);
      if (byPriority != 0) {
        return byPriority;
      }
      final int byDue = a.due.compareTo(b.due);
      if (byDue != 0) {
        return byDue;
      }
      return a.step.compareTo(b.step);
    });
    final Set<String> takenDays = <String>{};
    for (final ReminderTrack track in tracks.values) {
      track.planned.clear();
    }
    for (final candidate in candidates) {
      DateTime slot = candidate.evening;
      while (takenDays.contains(_dayKey(slot))) {
        slot = DateTime(slot.year, slot.month, slot.day + 1, fireHour);
      }
      takenDays.add(_dayKey(slot));
      tracks[candidate.kind]!.planned[candidate.step] = slot;
    }

    // Pass 3: flatten to the schedule, earliest first.
    final List<ScheduledReminder> schedule = <ScheduledReminder>[];
    for (final ReminderStateKind kind in ReminderStateKind.values) {
      final ReminderTrack? track = tracks[kind];
      if (track == null) {
        continue;
      }
      final List<ReminderStep> steps = reminderSteps[kind]!;
      for (final MapEntry<int, DateTime> entry in track.planned.entries) {
        final ReminderStep def = steps[entry.key];
        schedule.add(
          ScheduledReminder(
            kind: kind,
            step: entry.key,
            fireAt: entry.value,
            titleKey: def.titleKey,
            bodyKey: def.bodyKey,
            needsCounts: def.needsCounts,
          ),
        );
      }
    }
    schedule.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    return ReminderPlan(
      schedule: schedule,
      record: ReminderRecord(tracks: tracks),
    );
  }

  static String _dayKey(DateTime at) => '${at.year}-${at.month}-${at.day}';
}
