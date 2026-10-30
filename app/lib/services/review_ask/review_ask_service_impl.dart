// [ReviewAskService] over the narrow [ReviewAskStore].
//
// The record is seeded ONCE from the app's real records
// (ADR-020 decision 6): history counts + photos currently in
// Trash for deletes (both are photos the user deleted), marks
// across all persisted sessions for swipes, completion days ∪
// history days for usage days. After seeding, counters move
// only at the real events. Mutations are serialized through a
// future chain so a swipe recorded while a batch lands cannot
// lose either update. Everything is best-effort: persistence
// failures keep the in-memory record and never throw into a
// controller.

import 'dart:async';

import '../../core/utils/result.dart';
import '../local/local_service.dart';
import '../local/review_ask_store.dart';
import '../trash/trash_entry.dart';
import 'review_ask.dart';
import 'review_ask_service.dart';
import 'review_gateway.dart';

class ReviewAskServiceImpl implements ReviewAskService {
  ReviewAskServiceImpl({
    required this.local,
    required this.store,
    required this.gateway,
  });

  final LocalService local;
  final ReviewAskStore store;
  final ReviewGateway gateway;

  ReviewAskState? _state;
  Future<void> _tail = Future<void>.value();

  /// Runs [work] after every previously queued mutation, so
  /// concurrent recorders never read-modify-write over each
  /// other.
  Future<T> _serialize<T>(Future<T> Function() work) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await work());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<ReviewAskState> _ensureLoaded() async {
    final ReviewAskState? cached = _state;
    if (cached != null) {
      return cached;
    }
    ReviewAskState loaded = const ReviewAskState();
    final Result<ReviewAskState> result = await store.load();
    if (result case Success<ReviewAskState>(:final value)) {
      loaded = value;
    }
    if (!loaded.seeded) {
      loaded = await _seed(loaded);
      _state = loaded;
      await store.save(loaded);
    } else {
      _state = loaded;
    }
    return loaded;
  }

  /// The one-time seed from the app's records (decision 6).
  /// Each read is independent: a failed read contributes
  /// nothing rather than blocking the seed.
  Future<ReviewAskState> _seed(ReviewAskState base) async {
    int deletes = base.totalDeletes;
    int swipes = base.totalSwipes;
    List<DateTime> days = base.usageDays;

    final Result<List<HistoryRecord>> history = await local.loadHistory();
    if (history case Success<List<HistoryRecord>>(:final value)) {
      for (final HistoryRecord record in value) {
        deletes += record.count;
        days = withUsageDay(days, record.date);
      }
    }
    final Result<List<TrashEntry>> trash = await local.loadTrashEntries();
    if (trash case Success<List<TrashEntry>>(:final value)) {
      // Photos deleted by past Clean-deck batches, still in
      // Trash: deleted, not yet permanently gone. When they are
      // later emptied, history counts them — but emptying never
      // re-counts (decision 6), so this is not double counting.
      deletes += value.length;
    }
    final Result<List<DeckSession>> sessions = await local.listSessions();
    if (sessions case Success<List<DeckSession>>(:final value)) {
      for (final DeckSession session in value) {
        swipes += session.marks.length;
      }
    }
    final Result<List<DateTime>> completions = await local.loadCompletionDays();
    if (completions case Success<List<DateTime>>(:final value)) {
      for (final DateTime day in value) {
        days = withUsageDay(days, day);
      }
    }
    return base.copyWith(
      seeded: true,
      totalDeletes: deletes,
      totalSwipes: swipes,
      usageDays: days,
    );
  }

  Future<void> _update(ReviewAskState Function(ReviewAskState state) change) {
    return _serialize(() async {
      final ReviewAskState next = change(await _ensureLoaded());
      // copyWith cannot clear a value, but no transition here
      // ever clears one; skip the write when nothing changed.
      if (identical(next, _state) || next == _state) {
        return;
      }
      _state = next;
      await store.save(next);
    });
  }

  @override
  Future<ReviewAskState> state() {
    return _serialize(_ensureLoaded);
  }

  @override
  Future<void> recordSwipe() {
    return _update(
      (ReviewAskState s) => s.copyWith(totalSwipes: s.totalSwipes + 1),
    );
  }

  @override
  Future<void> recordDeleteBatch({required int count, required int bytes}) {
    if (count <= 0) {
      return Future<void>.value();
    }
    return _update(
      (ReviewAskState s) => s.copyWith(
        totalDeletes: s.totalDeletes + count,
        lastBatchCount: count,
        lastBatchBytes: bytes < 0 ? 0 : bytes,
      ),
    );
  }

  @override
  Future<void> recordUsageDay(DateTime day) {
    return _update(
      (ReviewAskState s) =>
          s.copyWith(usageDays: withUsageDay(s.usageDays, day)),
    );
  }

  @override
  Future<bool> isDue(ReviewAskPlace place) async {
    final ReviewAskState current = await state();
    return reviewAskDue(current, place);
  }

  @override
  Future<void> markShown(ReviewAskPlace place) {
    return _update((ReviewAskState s) => reviewAskShown(s, place));
  }

  @override
  Future<void> markDismissed(ReviewAskPlace place) {
    return _update((ReviewAskState s) => reviewAskDismissed(s, place));
  }

  @override
  Future<void> answerWithReview() async {
    await _update(
      (ReviewAskState s) => reviewAskAnswered(s, ReviewAnswer.review),
    );
    // The ask is answered whatever the store does next; the
    // dialog's outcome is not observable (decision 10).
    if (await gateway.isAvailable()) {
      await gateway.requestReview();
    } else {
      await gateway.openStoreListing();
    }
  }

  @override
  Future<void> answerWithFeedback() async {
    // Marking the answer is the whole path: the submitted
    // text stays in the sheet that collected it and is
    // discarded with it — it never reaches this service, so
    // nothing can send, share, or store it (owner decision
    // 30 Oct 2026, ADR-020 addendum). A real feedback
    // channel is a future decision.
    await _update(
      (ReviewAskState s) => reviewAskAnswered(s, ReviewAnswer.feedback),
    );
  }

  @override
  Future<int> fallbackAmountBytes() async {
    final ReviewAskState current = await state();
    final int? last = current.lastBatchBytes;
    if (last != null && last > 0) {
      return last;
    }
    final Result<List<HistoryRecord>> history = await local.loadHistory();
    if (history case Success<List<HistoryRecord>>(:final value)) {
      double freedMb = 0;
      for (final HistoryRecord record in value) {
        freedMb += record.mbFreed;
      }
      final int freedBytes = (freedMb * 1048576).round();
      if (freedBytes > 0) {
        return freedBytes;
      }
    }
    return last ?? 0;
  }
}
