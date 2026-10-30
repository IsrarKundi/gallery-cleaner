// State-based reminder model + planner (wipe. fix plan Stage 1,
// requirements §7 as amended 30 Oct 2026).
//
// Pure Dart: no plugin, no I/O, no clock reads. The engine in
// reminder_service_impl.dart observes the app's persisted state,
// hands it here as a [ReminderObservation], and applies the
// returned [ReminderPlan] through NotificationService. Every rule
// the owner approved lives in this one pure unit, so it is fully
// testable without a device:
//
// - There is no clock-based reminder. Each reminder fires because
//   of a STATE the user left behind (Cleanup's pattern, teardown
//   notes/retention.md §1.3), mapped to wipe.'s flow (ADR-013/014/
//   015): photos waiting in the Trash tab, a finished deck with
//   nothing deleted, a deck left part-way, a first swipe not yet
//   tried. Cleanup's contacts state is skipped (no such feature).
// - Steps per state (owner-approved times): first reminder after
//   the state's delay, one repeat, then stop. A state's clock
//   starts when the engine first observes the state after the
//   user turned reminders on — the app persists no install date,
//   and inventing one would be guessing (see ADR-016).
// - Never more than one reminder per calendar day: unsent steps
//   are placed on distinct evenings. Steps that want the same
//   evening are ordered by state priority (enum order is the
//   priority order), so the more important state takes that
//   evening and the other step moves to the next free evening —
//   deferred, never dropped. A step never fires before its own
//   due evening, so priority cannot shorten a ladder.
// - Reminders fire at 19:00 local (early evening, never at night).
// - A step counts as sent once its scheduled time has passed. A
//   step whose slot passed while it was never scheduled (e.g.
//   reminders were off, or the permission was revoked) is NOT
//   counted as sent: it is placed at the next free evening.
// - When a state stops being true its track is dropped, so its
//   pending steps vanish from the plan (and the engine cancels
//   them): finishing the work cancels the reminder.

import '../../core/strings/app_strings.dart';

/// The unfinished-work states that can carry a reminder, in
/// priority order (index 0 is the most important).
enum ReminderStateKind {
  /// Photos marked for deletion and still waiting (Trash tab).
  waiting,

  /// A deck was finished, photos were found, nothing was
  /// marked for deletion or deleted.
  finishedNoDelete,

  /// A deck was started and left part-way. Step 2 is the counted
  /// variant of the same ladder (plan states 3 and 4).
  unfinished,

  /// App installed, photo access granted, never swiped once.
  neverSwiped,
}

/// One step of a state's ladder.
class ReminderStep {
  const ReminderStep({
    required this.dueAfterStart,
    required this.titleKey,
    required this.bodyKey,
    this.needsCounts = false,
  });

  /// How long after the state's clock starts this step is due
  /// (before evening placement). Step 2 values are totals from
  /// the start, per the owner's table ("day 4 in total",
  /// "day 7 in total").
  final Duration dueAfterStart;

  final String titleKey;
  final String bodyKey;

  /// True when the body needs the real waiting photo/video
  /// counts. Such a step is only planned while at least one
  /// waiting photo or video exists — a "0 photos and 0 videos"
  /// message would not be truthful, so the step waits instead
  /// (see ADR-016).
  final bool needsCounts;
}

/// The approved ladders (owner, 30 Oct 2026). Copy keys resolve
/// through AppStrings at schedule time.
const Map<ReminderStateKind, List<ReminderStep>> reminderSteps =
    <ReminderStateKind, List<ReminderStep>>{
      ReminderStateKind.waiting: <ReminderStep>[
        ReminderStep(
          dueAfterStart: Duration(days: 1),
          titleKey: AppStrings.reminderWaitingTitle,
          bodyKey: AppStrings.reminderWaitingBody,
        ),
        ReminderStep(
          dueAfterStart: Duration(days: 4),
          titleKey: AppStrings.reminderWaitingTitle,
          bodyKey: AppStrings.reminderWaitingBody,
        ),
      ],
      ReminderStateKind.finishedNoDelete: <ReminderStep>[
        ReminderStep(
          dueAfterStart: Duration(days: 1),
          titleKey: AppStrings.reminderFinishedTitle,
          bodyKey: AppStrings.reminderFinishedBody,
        ),
        ReminderStep(
          dueAfterStart: Duration(days: 4),
          titleKey: AppStrings.reminderFinishedTitle,
          bodyKey: AppStrings.reminderFinishedBody,
        ),
      ],
      ReminderStateKind.unfinished: <ReminderStep>[
        ReminderStep(
          dueAfterStart: Duration(days: 1),
          titleKey: AppStrings.reminderUnfinishedTitle,
          bodyKey: AppStrings.reminderUnfinishedBody,
        ),
        ReminderStep(
          dueAfterStart: Duration(days: 4),
          titleKey: AppStrings.reminderCountsTitle,
          bodyKey: AppStrings.reminderCountsBody,
          needsCounts: true,
        ),
      ],
      ReminderStateKind.neverSwiped: <ReminderStep>[
        ReminderStep(
          dueAfterStart: Duration(days: 2),
          titleKey: AppStrings.reminderNeverSwipedTitle,
          bodyKey: AppStrings.reminderNeverSwipedBody,
        ),
        ReminderStep(
          dueAfterStart: Duration(days: 7),
          titleKey: AppStrings.reminderNeverSwipedTitle,
          bodyKey: AppStrings.reminderNeverSwipedBody,
        ),
      ],
    };

/// The legacy weekly-nudge notification id (Phase 3A). Cancelled
/// by the reminder engine so an old build's weekly nudge can
/// never fire alongside the state reminders.
const int legacyWeeklyNudgeId = 7001;

/// Notification id for one state step. Ids are stable so a
/// re-plan replaces exactly the same notifications.
int reminderNotificationId(ReminderStateKind kind, int step) =>
    7100 + kind.index * 10 + step;

/// Every notification id the reminder system may ever schedule:
/// the legacy weekly nudge plus all state steps.
List<int> allReminderNotificationIds() {
  return <int>[
    legacyWeeklyNudgeId,
    for (final ReminderStateKind kind in ReminderStateKind.values)
      for (int step = 0; step < (reminderSteps[kind]?.length ?? 0); step++)
        reminderNotificationId(kind, step),
  ];
}

/// Per-state progress, persisted through LocalService: when the
/// state was first observed, how many steps have fired, and the
/// fire times currently scheduled for the remaining steps.
class ReminderTrack {
  ReminderTrack({
    required this.startedAt,
    this.sentCount = 0,
    Map<int, DateTime>? planned,
  }) : planned = planned ?? <int, DateTime>{};

  final DateTime startedAt;
  int sentCount;

  /// Step index -> scheduled fire time (future only; an entry is
  /// removed once its time passes and the step counts as sent).
  final Map<int, DateTime> planned;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startedAt': startedAt.toIso8601String(),
      'sentCount': sentCount,
      'planned': planned.map(
        (int step, DateTime at) =>
            MapEntry<String, String>('$step', at.toIso8601String()),
      ),
    };
  }

  factory ReminderTrack.fromJson(Map<String, dynamic> json) {
    final Map<int, DateTime> planned = <int, DateTime>{};
    final Object? rawPlanned = json['planned'];
    if (rawPlanned is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawPlanned.entries) {
        final int? step = int.tryParse(entry.key);
        final Object? value = entry.value;
        if (step != null && value is String) {
          final DateTime? at = DateTime.tryParse(value);
          if (at != null) {
            planned[step] = at;
          }
        }
      }
    }
    return ReminderTrack(
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sentCount: json['sentCount'] as int? ?? 0,
      planned: planned,
    );
  }
}

/// The whole persisted reminder state: one track per active
/// state. Stored as one record in its own JSON file (see
/// ReminderStateStore in services/local) — counts and dates
/// only, never photo content.
class ReminderRecord {
  const ReminderRecord({
    this.tracks = const <ReminderStateKind, ReminderTrack>{},
  });

  final Map<ReminderStateKind, ReminderTrack> tracks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tracks': tracks.map(
        (ReminderStateKind kind, ReminderTrack track) =>
            MapEntry<String, dynamic>(kind.name, track.toJson()),
      ),
    };
  }

  factory ReminderRecord.fromJson(Map<String, dynamic> json) {
    final Map<ReminderStateKind, ReminderTrack> tracks =
        <ReminderStateKind, ReminderTrack>{};
    final Object? raw = json['tracks'];
    if (raw is Map<String, dynamic>) {
      for (final ReminderStateKind kind in ReminderStateKind.values) {
        final Object? value = raw[kind.name];
        if (value is Map<String, dynamic>) {
          tracks[kind] = ReminderTrack.fromJson(value);
        }
      }
    }
    return ReminderRecord(tracks: tracks);
  }
}

/// What the engine observed in the app's persisted state at one
/// refresh. All fields are facts read from LocalService /
/// MediaService — the planner invents nothing.
class ReminderObservation {
  const ReminderObservation({
    required this.waitingPhotos,
    required this.waitingVideos,
    required this.finishedDeck,
    required this.everDeleted,
    required this.everSwiped,
    required this.mediaGranted,
  });

  /// Delete-marked photos still in the library, waiting.
  final int waitingPhotos;

  /// Delete-marked videos still in the library, waiting.
  final int waitingVideos;

  /// At least one deck session has been completed (a completion
  /// day is recorded).
  final bool finishedDeck;

  /// Anything was ever trashed or deleted (Trash entries or
  /// history exist).
  final bool everDeleted;

  /// At least one swipe mark exists in any saved session.
  final bool everSwiped;

  /// Photo access is granted (full or limited).
  final bool mediaGranted;

  int get waitingTotal => waitingPhotos + waitingVideos;

  /// Whether [kind]'s state is true in this observation. The
  /// ladder is exclusive at the story level (ADR-016): finishing
  /// a deck with waiting photos is the waiting state, not the
  /// finished state; an unfinished deck can still be true next
  /// to the waiting state, and priority orders their days.
  bool isActive(ReminderStateKind kind) {
    return switch (kind) {
      ReminderStateKind.waiting => waitingTotal > 0,
      ReminderStateKind.finishedNoDelete =>
        finishedDeck && !everDeleted && waitingTotal == 0,
      ReminderStateKind.unfinished => everSwiped && !finishedDeck,
      ReminderStateKind.neverSwiped =>
        !everSwiped && !everDeleted && mediaGranted,
    };
  }
}

/// One notification to (re)schedule.
class ScheduledReminder {
  const ScheduledReminder({
    required this.kind,
    required this.step,
    required this.fireAt,
    required this.titleKey,
    required this.bodyKey,
    required this.needsCounts,
  });

  final ReminderStateKind kind;
  final int step;
  final DateTime fireAt;
  final String titleKey;
  final String bodyKey;
  final bool needsCounts;

  int get id => reminderNotificationId(kind, step);
}

/// The planner's output: every notification that should be
/// scheduled after this refresh (the engine replaces the whole
/// set), plus the record to persist.
class ReminderPlan {
  const ReminderPlan({required this.schedule, required this.record});

  final List<ScheduledReminder> schedule;
  final ReminderRecord record;
}
