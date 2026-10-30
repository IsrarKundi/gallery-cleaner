// Review-ask accounting (fix plan Stage 5, ADR-020).
//
// Cleanup's system (teardown notes/retention.md §4.3): count
// swipes and deletes separately, ask at most once per place
// (after deleting / after swiping / home), two steps — our own
// sheet first, the store prompt only for happy users, a feedback
// form for unhappy ones. Cleanup's numeric limits are
// server-side and unreadable, so the thresholds here are the
// owner's own (30 Oct 2026): deletes ask above 10, swipes at
// 60, home at 3 usage days + a delete. A dismissal re-arms the
// place only at double the count (Cleanup's multiplier trick).
// A review or feedback given anywhere silences every place
// forever.
//
// Pure model + transitions only: no services, no state. The
// store persists this record; the service seeds and mutates it.

/// Where an ask can appear.
enum ReviewAskPlace { delete, swipe, home }

/// What the user ultimately gave, if anything. Once this is not
/// [none], no ask ever fires again in any place.
enum ReviewAnswer { none, review, feedback }

/// First thresholds (owner's numbers, ADR-020 decision 7).
const int firstDeleteThreshold = 10;
const int firstSwipeThreshold = 60;

/// Distinct usage days the home ask needs.
const int homeAskUsageDays = 3;

/// The persisted review-ask record. Counts and dates only —
/// never photo content (requirements §5).
class ReviewAskState {
  const ReviewAskState({
    this.seeded = false,
    this.totalSwipes = 0,
    this.totalDeletes = 0,
    this.usageDays = const <DateTime>[],
    this.deleteThreshold = firstDeleteThreshold,
    this.swipeThreshold = firstSwipeThreshold,
    this.deleteShown = 0,
    this.swipeShown = 0,
    this.homeShown = 0,
    this.homeExhausted = false,
    this.answered = ReviewAnswer.none,
    this.lastBatchCount,
    this.lastBatchBytes,
  });

  /// True once the one-time seed from the app's records ran
  /// (ADR-020 decision 6). An unseeded record is all defaults.
  final bool seeded;

  /// Lifetime recorded marks (both deck controllers).
  final int totalSwipes;

  /// Lifetime photos deleted through completed delete batches
  /// (Review permanent deletes + Clean-deck trash batches).
  final int totalDeletes;

  /// Distinct days the app was used (date-only), oldest first.
  final List<DateTime> usageDays;

  /// Next delete total that must be EXCEEDED for the delete
  /// place to ask (10, then 20, 40, … after dismissals).
  final int deleteThreshold;

  /// Next swipe total that must be REACHED for the swipe place
  /// to ask (60, then 120, 240, … after dismissals).
  final int swipeThreshold;

  /// Times each place's sheet was actually presented.
  final int deleteShown;
  final int swipeShown;
  final int homeShown;

  /// Home was presented and dismissed: home has no count to
  /// double, so its dismissal is final (ADR-020 decision 7).
  final bool homeExhausted;

  final ReviewAnswer answered;

  /// The most recent completed delete batch (finish-screen
  /// numbers), for the swipe/home sheet amount fallback.
  final int? lastBatchCount;
  final int? lastBatchBytes;

  bool get hasAnswered => answered != ReviewAnswer.none;

  int shownFor(ReviewAskPlace place) {
    return switch (place) {
      ReviewAskPlace.delete => deleteShown,
      ReviewAskPlace.swipe => swipeShown,
      ReviewAskPlace.home => homeShown,
    };
  }

  ReviewAskState copyWith({
    bool? seeded,
    int? totalSwipes,
    int? totalDeletes,
    List<DateTime>? usageDays,
    int? deleteThreshold,
    int? swipeThreshold,
    int? deleteShown,
    int? swipeShown,
    int? homeShown,
    bool? homeExhausted,
    ReviewAnswer? answered,
    int? lastBatchCount,
    int? lastBatchBytes,
  }) {
    return ReviewAskState(
      seeded: seeded ?? this.seeded,
      totalSwipes: totalSwipes ?? this.totalSwipes,
      totalDeletes: totalDeletes ?? this.totalDeletes,
      usageDays: usageDays ?? this.usageDays,
      deleteThreshold: deleteThreshold ?? this.deleteThreshold,
      swipeThreshold: swipeThreshold ?? this.swipeThreshold,
      deleteShown: deleteShown ?? this.deleteShown,
      swipeShown: swipeShown ?? this.swipeShown,
      homeShown: homeShown ?? this.homeShown,
      homeExhausted: homeExhausted ?? this.homeExhausted,
      answered: answered ?? this.answered,
      lastBatchCount: lastBatchCount ?? this.lastBatchCount,
      lastBatchBytes: lastBatchBytes ?? this.lastBatchBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'seeded': seeded,
      'totalSwipes': totalSwipes,
      'totalDeletes': totalDeletes,
      'usageDays': <String>[for (final DateTime day in usageDays) _dayKey(day)],
      'deleteThreshold': deleteThreshold,
      'swipeThreshold': swipeThreshold,
      'deleteShown': deleteShown,
      'swipeShown': swipeShown,
      'homeShown': homeShown,
      'homeExhausted': homeExhausted,
      'answered': answered.name,
      'lastBatchCount': lastBatchCount,
      'lastBatchBytes': lastBatchBytes,
    };
  }

  factory ReviewAskState.fromJson(Map<String, dynamic> json) {
    int count(String key, int fallback) {
      final Object? value = json[key];
      return value is int ? value : fallback;
    }

    final Object? answeredRaw = json['answered'];
    final ReviewAnswer answered = answeredRaw is String
        ? ReviewAnswer.values.firstWhere(
            (ReviewAnswer a) => a.name == answeredRaw,
            orElse: () => ReviewAnswer.none,
          )
        : ReviewAnswer.none;
    final List<DateTime> days = <DateTime>[];
    final Object? rawDays = json['usageDays'];
    if (rawDays is List<dynamic>) {
      for (final Object? raw in rawDays) {
        if (raw is String) {
          final DateTime? parsed = DateTime.tryParse(raw);
          if (parsed != null) {
            days.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }
      days.sort();
    }
    return ReviewAskState(
      seeded: json['seeded'] == true,
      totalSwipes: count('totalSwipes', 0),
      totalDeletes: count('totalDeletes', 0),
      usageDays: days,
      deleteThreshold: count('deleteThreshold', firstDeleteThreshold),
      swipeThreshold: count('swipeThreshold', firstSwipeThreshold),
      deleteShown: count('deleteShown', 0),
      swipeShown: count('swipeShown', 0),
      homeShown: count('homeShown', 0),
      homeExhausted: json['homeExhausted'] == true,
      answered: answered,
      lastBatchCount: count('lastBatchCount', -1) < 0
          ? null
          : count('lastBatchCount', -1),
      lastBatchBytes: count('lastBatchBytes', -1) < 0
          ? null
          : count('lastBatchBytes', -1),
    );
  }
}

/// Date-only key for a usage day ('2026-10-30').
String _dayKey(DateTime day) {
  final String month = day.month.toString().padLeft(2, '0');
  final String date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

/// Whether [place]'s ask may be presented from [state] now.
/// Pure: the service owns when "now" is checked (finish screen,
/// session end, home ready). The owner's rules, literally
/// (ADR-020 decision 7): deletes strictly above the threshold,
/// swipes at the threshold, home gated on the other two places
/// never having been shown at all.
bool reviewAskDue(ReviewAskState state, ReviewAskPlace place) {
  if (state.hasAnswered) {
    return false;
  }
  return switch (place) {
    ReviewAskPlace.delete => state.totalDeletes > state.deleteThreshold,
    ReviewAskPlace.swipe => state.totalSwipes >= state.swipeThreshold,
    ReviewAskPlace.home =>
      !state.homeExhausted &&
          state.deleteShown == 0 &&
          state.swipeShown == 0 &&
          state.usageDays.length >= homeAskUsageDays &&
          state.totalDeletes >= 1,
  };
}

/// Records a presentation of [place]'s sheet.
ReviewAskState reviewAskShown(ReviewAskState state, ReviewAskPlace place) {
  return switch (place) {
    ReviewAskPlace.delete => state.copyWith(deleteShown: state.deleteShown + 1),
    ReviewAskPlace.swipe => state.copyWith(swipeShown: state.swipeShown + 1),
    ReviewAskPlace.home => state.copyWith(homeShown: state.homeShown + 1),
  };
}

/// Records a dismissal (closed without answering) of [place]:
/// the count places re-arm at double their threshold; home is
/// exhausted — it has no count to double.
ReviewAskState reviewAskDismissed(ReviewAskState state, ReviewAskPlace place) {
  return switch (place) {
    ReviewAskPlace.delete => state.copyWith(
      deleteThreshold: state.deleteThreshold * 2,
    ),
    ReviewAskPlace.swipe => state.copyWith(
      swipeThreshold: state.swipeThreshold * 2,
    ),
    ReviewAskPlace.home => state.copyWith(homeExhausted: true),
  };
}

/// Records the user's answer: from now on, no place ever asks.
ReviewAskState reviewAskAnswered(ReviewAskState state, ReviewAnswer answer) {
  return state.copyWith(answered: answer);
}

/// [days] plus [day], date-only, de-duplicated and sorted.
List<DateTime> withUsageDay(List<DateTime> days, DateTime day) {
  final DateTime only = DateTime(day.year, day.month, day.day);
  final Set<String> keys = <String>{for (final DateTime d in days) _dayKey(d)};
  if (keys.contains(_dayKey(only))) {
    return days;
  }
  return <DateTime>[...days, only]..sort();
}
