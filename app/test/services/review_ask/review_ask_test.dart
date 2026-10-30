// Review-ask state machine tests (fix plan Stage 5, ADR-020
// decision 7): the owner's counts, literally — deletes strictly
// above 10, swipes at 60, home at 3 usage days + a delete and
// only while the other places never fired; once per place;
// dismissal re-arms at double; an answer anywhere silences
// every place forever.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/review_ask/review_ask.dart';

ReviewAskState _state({
  int totalSwipes = 0,
  int totalDeletes = 0,
  List<DateTime> usageDays = const <DateTime>[],
  int deleteThreshold = firstDeleteThreshold,
  int swipeThreshold = firstSwipeThreshold,
  int deleteShown = 0,
  int swipeShown = 0,
  int homeShown = 0,
  bool homeExhausted = false,
  ReviewAnswer answered = ReviewAnswer.none,
}) {
  return ReviewAskState(
    seeded: true,
    totalSwipes: totalSwipes,
    totalDeletes: totalDeletes,
    usageDays: usageDays,
    deleteThreshold: deleteThreshold,
    swipeThreshold: swipeThreshold,
    deleteShown: deleteShown,
    swipeShown: swipeShown,
    homeShown: homeShown,
    homeExhausted: homeExhausted,
    answered: answered,
  );
}

final List<DateTime> _threeDays = <DateTime>[
  DateTime(2026, 10, 28),
  DateTime(2026, 10, 29),
  DateTime(2026, 10, 30),
];

void main() {
  group('delete place', () {
    test('not due at exactly 10 deletes — the rule is MORE than 10', () {
      expect(
        reviewAskDue(_state(totalDeletes: 10), ReviewAskPlace.delete),
        isFalse,
      );
    });

    test('due at 11 deletes — including on the very first clean', () {
      // First clean ever: no asks shown anywhere, one batch of 11.
      expect(
        reviewAskDue(_state(totalDeletes: 11), ReviewAskPlace.delete),
        isTrue,
      );
    });

    test('dismissal doubles the bar: 10 → 20 → 40', () {
      ReviewAskState state = _state(totalDeletes: 11);
      state = reviewAskShown(state, ReviewAskPlace.delete);
      state = reviewAskDismissed(state, ReviewAskPlace.delete);
      expect(state.deleteThreshold, 20);
      state = state.copyWith(totalDeletes: 20);
      expect(reviewAskDue(state, ReviewAskPlace.delete), isFalse);
      state = state.copyWith(totalDeletes: 21);
      expect(reviewAskDue(state, ReviewAskPlace.delete), isTrue);
      state = reviewAskShown(state, ReviewAskPlace.delete);
      state = reviewAskDismissed(state, ReviewAskPlace.delete);
      expect(state.deleteThreshold, 40);
      state = state.copyWith(totalDeletes: 40);
      expect(reviewAskDue(state, ReviewAskPlace.delete), isFalse);
      state = state.copyWith(totalDeletes: 41);
      expect(reviewAskDue(state, ReviewAskPlace.delete), isTrue);
    });
  });

  group('swipe place', () {
    test('not due at 59 swipes, due at exactly 60', () {
      expect(
        reviewAskDue(_state(totalSwipes: 59), ReviewAskPlace.swipe),
        isFalse,
      );
      expect(
        reviewAskDue(_state(totalSwipes: 60), ReviewAskPlace.swipe),
        isTrue,
      );
    });

    test('dismissal doubles the bar: 60 → 120 → 240', () {
      ReviewAskState state = _state(totalSwipes: 60);
      state = reviewAskShown(state, ReviewAskPlace.swipe);
      state = reviewAskDismissed(state, ReviewAskPlace.swipe);
      expect(state.swipeThreshold, 120);
      state = state.copyWith(totalSwipes: 119);
      expect(reviewAskDue(state, ReviewAskPlace.swipe), isFalse);
      state = state.copyWith(totalSwipes: 120);
      expect(reviewAskDue(state, ReviewAskPlace.swipe), isTrue);
      state = reviewAskShown(state, ReviewAskPlace.swipe);
      state = reviewAskDismissed(state, ReviewAskPlace.swipe);
      expect(state.swipeThreshold, 240);
      state = state.copyWith(totalSwipes: 239);
      expect(reviewAskDue(state, ReviewAskPlace.swipe), isFalse);
      state = state.copyWith(totalSwipes: 240);
      expect(reviewAskDue(state, ReviewAskPlace.swipe), isTrue);
    });
  });

  group('home place', () {
    test('due at 3 usage days and at least one delete', () {
      expect(
        reviewAskDue(
          _state(totalDeletes: 1, usageDays: _threeDays),
          ReviewAskPlace.home,
        ),
        isTrue,
      );
    });

    test('not due with only 2 usage days', () {
      expect(
        reviewAskDue(
          _state(totalDeletes: 5, usageDays: _threeDays.sublist(0, 2)),
          ReviewAskPlace.home,
        ),
        isFalse,
      );
    });

    test('not due when nothing was ever deleted', () {
      expect(
        reviewAskDue(
          _state(totalDeletes: 0, usageDays: _threeDays),
          ReviewAskPlace.home,
        ),
        isFalse,
      );
    });

    test('never due once the delete place has fired', () {
      expect(
        reviewAskDue(
          _state(totalDeletes: 30, usageDays: _threeDays, deleteShown: 1),
          ReviewAskPlace.home,
        ),
        isFalse,
      );
    });

    test('never due once the swipe place has fired', () {
      expect(
        reviewAskDue(
          _state(totalDeletes: 30, usageDays: _threeDays, swipeShown: 1),
          ReviewAskPlace.home,
        ),
        isFalse,
      );
    });

    test('a dismissed home ask never returns (no count to double)', () {
      ReviewAskState state = _state(totalDeletes: 1, usageDays: _threeDays);
      state = reviewAskShown(state, ReviewAskPlace.home);
      state = reviewAskDismissed(state, ReviewAskPlace.home);
      expect(state.homeExhausted, isTrue);
      expect(reviewAskDue(state, ReviewAskPlace.home), isFalse);
      // ...while the other places are untouched by it.
      expect(state.deleteThreshold, firstDeleteThreshold);
      expect(state.swipeThreshold, firstSwipeThreshold);
    });
  });

  group('answering silences everything', () {
    test('a review anywhere: no place ever asks again', () {
      ReviewAskState state = _state(
        totalDeletes: 100,
        totalSwipes: 500,
        usageDays: _threeDays,
      );
      state = reviewAskAnswered(state, ReviewAnswer.review);
      for (final ReviewAskPlace place in ReviewAskPlace.values) {
        expect(reviewAskDue(state, place), isFalse, reason: '$place');
      }
    });

    test('feedback anywhere: no place ever asks again', () {
      ReviewAskState state = _state(
        totalDeletes: 100,
        totalSwipes: 500,
        usageDays: _threeDays,
      );
      state = reviewAskAnswered(state, ReviewAnswer.feedback);
      for (final ReviewAskPlace place in ReviewAskPlace.values) {
        expect(reviewAskDue(state, place), isFalse, reason: '$place');
      }
    });
  });

  group('shown counts and usage days', () {
    test('shown increments only its own place', () {
      ReviewAskState state = _state();
      state = reviewAskShown(state, ReviewAskPlace.swipe);
      expect(state.swipeShown, 1);
      expect(state.deleteShown, 0);
      expect(state.homeShown, 0);
    });

    test('withUsageDay dedupes by calendar day and sorts', () {
      List<DateTime> days = withUsageDay(
        <DateTime>[],
        DateTime(2026, 10, 30, 21, 15),
      );
      days = withUsageDay(days, DateTime(2026, 10, 30, 8, 0));
      expect(days.length, 1);
      days = withUsageDay(days, DateTime(2026, 10, 28));
      expect(days, <DateTime>[DateTime(2026, 10, 28), DateTime(2026, 10, 30)]);
    });
  });

  group('persistence shape', () {
    test('JSON round-trips every field', () {
      final ReviewAskState state = ReviewAskState(
        seeded: true,
        totalSwipes: 75,
        totalDeletes: 21,
        usageDays: _threeDays,
        deleteThreshold: 20,
        swipeThreshold: 120,
        deleteShown: 1,
        swipeShown: 2,
        homeShown: 0,
        homeExhausted: true,
        answered: ReviewAnswer.feedback,
        lastBatchCount: 12,
        lastBatchBytes: 3456789,
      );
      final ReviewAskState back = ReviewAskState.fromJson(state.toJson());
      expect(back.seeded, isTrue);
      expect(back.totalSwipes, 75);
      expect(back.totalDeletes, 21);
      expect(back.usageDays, _threeDays);
      expect(back.deleteThreshold, 20);
      expect(back.swipeThreshold, 120);
      expect(back.deleteShown, 1);
      expect(back.swipeShown, 2);
      expect(back.homeExhausted, isTrue);
      expect(back.answered, ReviewAnswer.feedback);
      expect(back.lastBatchCount, 12);
      expect(back.lastBatchBytes, 3456789);
    });

    test('an empty map reads as the unseeded default record', () {
      final ReviewAskState state = ReviewAskState.fromJson(<String, dynamic>{});
      expect(state.seeded, isFalse);
      expect(state.deleteThreshold, firstDeleteThreshold);
      expect(state.swipeThreshold, firstSwipeThreshold);
      expect(state.lastBatchBytes, isNull);
    });
  });
}
