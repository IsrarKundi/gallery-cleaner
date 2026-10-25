// Phase 2B retention math (requirements §7, Phase 2). Pure
// functions only: no services, no state, no widgets. Controllers
// and tests share these definitions, so the documented semantics
// below are the single source of truth for snooze, goals, streaks,
// On This Day, the session summary and the storage projection.
//
// CROSS-FEATURE NOTE (deliberate exception, documented per the
// Phase 2B brief): the decks feature imports this deck-feature
// model, exactly as smart-deck views already reuse the deck's
// SwipeCard/DeckActionBar widgets. No other cross-feature model
// import is added by Phase 2B.
//
// Definitions (frozen for Phase 2B):
// - Snooze: marking Maybe alone NEVER snoozes. A snooze is set
//   explicitly from the Maybe pile (7 / 14 / 30 days) and stores a
//   return date (today + days, date-only). While today is before
//   the return date the asset stays Maybe and does not reappear
//   (the deck skips marked assets). When today reaches the return
//   date the snooze has expired: the next load of the relevant
//   session clears that Maybe mark, so the asset returns to the
//   deck as undecided, and the snooze record is cleared.
// - Goal: weekly freed-space target, presets 500 MB / 1 GB / 2 GB,
//   default 1 GB. Progress = MB freed this calendar week
//   (Monday–Sunday) from history records' mbFreed ONLY — trashed MB
//   never counts, marked MB never counts.
// - Streak day: a day counts when the user completes a deck session
//   (the final mark lands) OR a history record exists that day
//   (a trash/empty run). The current streak counts consecutive days
//   ending today, or ending yesterday when today has no action yet
//   (the streak is still alive until the day ends). A gap over one
//   day resets it. Best streak is the longest run anywhere.
// - On This Day: createDate month + day equal today, from PREVIOUS
//   years only — today's just-taken photos must not dominate the
//   deck. Feb 29 photos match only in leap years (no Feb 29 in
//   other years, so they simply do not appear then).
// - Summary: counts come from the finished queue's marks only.
//   Delete MB is "to be freed" (marked), never freed; trashed MB is
//   never reported as freed anywhere in the summary.
// - Projection: projected free = device free now + MB currently in
//   Trash (emptying Trash is the only step that would free it).
//   When device free storage is unknown, no device numbers are
//   shown at all — the bar falls back to a labelled library
//   projection (marked + in-Trash figures from app records).

import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';

/// Date-only form of [date] (midnight, local time).
DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// Monday of the calendar week containing [now] (date-only).
DateTime weekMonday(DateTime now) {
  final DateTime day = dateOnly(now);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// MB freed this calendar week (Monday–Sunday) from history records.
/// Freed only: mbTrashed is ignored by construction.
double weekFreedMb(List<HistoryRecord> history, DateTime now) {
  final DateTime monday = weekMonday(now);
  final DateTime sundayEnd = monday.add(const Duration(days: 7));
  double total = 0;
  for (final HistoryRecord record in history) {
    final DateTime day = dateOnly(record.date);
    if (!day.isBefore(monday) && day.isBefore(sundayEnd)) {
      total += record.mbFreed;
    }
  }
  return total;
}

/// Current + best streak over [days] (completion days and/or
/// history-record days; duplicates and times are ignored).
StreakResult computeStreak(List<DateTime> days, DateTime now) {
  final Set<DateTime> set = <DateTime>{
    for (final DateTime day in days) dateOnly(day),
  };
  if (set.isEmpty) {
    return const StreakResult(current: 0, best: 0);
  }
  final List<DateTime> sorted = set.toList()..sort();
  int best = 0;
  int run = 0;
  DateTime? previous;
  for (final DateTime day in sorted) {
    if (previous != null && day.difference(previous).inDays == 1) {
      run += 1;
    } else {
      run = 1;
    }
    if (run > best) {
      best = run;
    }
    previous = day;
  }
  final DateTime today = dateOnly(now);
  DateTime anchor;
  if (set.contains(today)) {
    anchor = today;
  } else if (set.contains(today.subtract(const Duration(days: 1)))) {
    anchor = today.subtract(const Duration(days: 1));
  } else {
    return StreakResult(current: 0, best: best);
  }
  int current = 0;
  DateTime cursor = anchor;
  while (set.contains(cursor)) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return StreakResult(current: current, best: best);
}

/// A streak result: the live streak and the longest run ever.
class StreakResult {
  const StreakResult({required this.current, required this.best});

  final int current;
  final int best;
}

/// True while [until] (a return date) is still in the future:
/// today is before the return date.
bool isSnoozed(DateTime until, DateTime now) {
  return dateOnly(now).isBefore(dateOnly(until));
}

/// Return date for a snooze of [days] from [now] (date-only).
DateTime snoozeUntilFor(int days, DateTime now) {
  return dateOnly(now.add(Duration(days: days)));
}

/// Asset ids whose snooze has expired by [now] (today reached or
/// passed the return date).
List<String> expiredSnoozeIds(Map<String, DateTime> snoozes, DateTime now) {
  return <String>[
    for (final MapEntry<String, DateTime> entry in snoozes.entries)
      if (!isSnoozed(entry.value, now)) entry.key,
  ];
}

/// Applies expired snoozes to a session's marks: expired snoozed
/// Maybe marks are removed (the asset returns as undecided) and
/// the expired ids are returned so the caller clears the records.
/// Marks that are not Maybe are never touched, even if a stale
/// snooze record exists for them.
({Map<String, DeckMark> marks, List<String> clearedIds}) applySnoozeExpiry(
  Map<String, DeckMark> marks,
  Map<String, DateTime> snoozes,
  DateTime now,
) {
  final List<String> expired = expiredSnoozeIds(snoozes, now);
  final Map<String, DeckMark> updated = Map<String, DeckMark>.of(marks);
  final List<String> cleared = <String>[];
  for (final String id in expired) {
    cleared.add(id);
    if (updated[id] == DeckMark.maybe) {
      updated.remove(id);
    }
  }
  return (marks: updated, clearedIds: cleared);
}

/// On This Day / Memories predicate: same month from any previous year,
/// or photos taken today.
bool isOnThisDay(MediaAsset asset, DateTime now) {
  final bool isSameMonthPreviousYear =
      asset.createDate.month == now.month && asset.createDate.year != now.year;
  final bool isToday =
      asset.createDate.year == now.year &&
      asset.createDate.month == now.month &&
      asset.createDate.day == now.day;
  return isSameMonthPreviousYear || isToday;
}

/// Goal presets in MB (Phase 2B): 500 MB, 1 GB, 2 GB.
const List<double> goalPresetsMb = <double>[512, 1024, 2048];

/// Default goal target in MB: 1 GB.
const double defaultGoalMb = 1024;

/// Finished-session counts, computed from one queue's marks.
/// Delete MB is marked ("to be freed"), never freed.
class SessionSummary {
  const SessionSummary({
    required this.reviewed,
    required this.kept,
    required this.deleteMarked,
    required this.deleteMarkedBytes,
    required this.maybe,
    required this.favourite,
  });

  final int reviewed;
  final int kept;
  final int deleteMarked;
  final int deleteMarkedBytes;
  final int maybe;
  final int favourite;

  double get deleteMarkedMb => deleteMarkedBytes / 1048576;
}

/// Counts a finished session: only marks for assets still in the
/// queue count (stale marks for vanished assets contribute nothing).
SessionSummary computeSessionSummary({
  required Map<String, DeckMark> marks,
  required Map<String, MediaAsset> assetsById,
}) {
  int kept = 0;
  int deleteMarked = 0;
  int deleteBytes = 0;
  int maybe = 0;
  int favourite = 0;
  int reviewed = 0;
  for (final MapEntry<String, DeckMark> entry in marks.entries) {
    final MediaAsset? asset = assetsById[entry.key];
    if (asset == null) {
      continue;
    }
    reviewed += 1;
    switch (entry.value) {
      case DeckMark.keep:
        kept += 1;
      case DeckMark.delete:
        deleteMarked += 1;
        deleteBytes += asset.sizeBytes;
      case DeckMark.maybe:
        maybe += 1;
      case DeckMark.favourite:
        favourite += 1;
    }
  }
  return SessionSummary(
    reviewed: reviewed,
    kept: kept,
    deleteMarked: deleteMarked,
    deleteMarkedBytes: deleteBytes,
    maybe: maybe,
    favourite: favourite,
  );
}

/// Plain-text form of a summary, for the share fallback when the
/// card image capture fails. It never calls marked MB freed.
String summaryShareText(SessionSummary summary) {
  final String markedMb = summary.deleteMarkedMb % 1 == 0
      ? summary.deleteMarkedMb.toStringAsFixed(0)
      : summary.deleteMarkedMb.toStringAsFixed(1);
  return 'I cleaned up with Klara: ${summary.reviewed} photos reviewed, '
      '${summary.kept} kept, ${summary.deleteMarked} marked for removal '
      '($markedMb MB to be freed), ${summary.maybe} maybe, '
      '${summary.favourite} favourited.';
}

/// Projected device free storage after emptying Trash: free now +
/// MB currently in Trash. Both inputs are MB.
double projectedFreeMb(double freeMb, double inTrashMb) {
  return freeMb + inTrashMb;
}
