// Review-ask service (fix plan Stage 5, ADR-020).
//
// Interface only. Owns the persisted [ReviewAskState]: seeds it
// once from the app's real records, counts swipes and delete
// batches at the events that produce them, answers the places'
// due checks, and performs the two answers (store prompt via
// [ReviewGateway]; feedback via the share sheet — decision 11).
// Every method is best-effort: a storage or store failure must
// never break swiping, deleting, or navigation, so nothing here
// throws.

import 'review_ask.dart';

abstract class ReviewAskService {
  /// The current record (seeded on first use).
  Future<ReviewAskState> state();

  /// Counts one recorded mark (a swipe decision).
  Future<void> recordSwipe();

  /// Counts a completed delete batch — [count] photos, [bytes]
  /// total — and remembers it as the last batch (the finish
  /// screen's numbers; the sheet amount fallback).
  Future<void> recordDeleteBatch({required int count, required int bytes});

  /// Notes that the app was used on [day] (date-only).
  Future<void> recordUsageDay(DateTime day);

  /// Whether [place]'s ask may be presented now.
  Future<bool> isDue(ReviewAskPlace place);

  /// Records that [place]'s sheet was presented.
  Future<void> markShown(ReviewAskPlace place);

  /// Records that [place]'s sheet was closed without answering:
  /// the place re-arms at double the count (home: never again).
  Future<void> markDismissed(ReviewAskPlace place);

  /// The happy path: marks the ask answered (review) first —
  /// the store dialog's outcome is not observable, so the tap
  /// is the answer — then asks the store to prompt, falling
  /// back to the store listing when the dialog is unavailable.
  Future<void> answerWithReview();

  /// The feedback path: marks the ask answered (feedback), then
  /// hands [text] to the system share sheet so the USER picks
  /// the destination and sends it — the app has no support
  /// channel, and nothing is ever sent silently (decision 11).
  Future<void> answerWithFeedback(String text);

  /// The sheet amount for places with no batch of their own:
  /// the last batch's bytes, else the lifetime freed bytes from
  /// the history records. Always a real recorded number.
  Future<int> fallbackAmountBytes();
}
