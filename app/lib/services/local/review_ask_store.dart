// Persistence for the review-ask record (fix plan Stage 5).
//
// Interface only. The record (lifetime swipe/delete counters,
// usage days, per-place ask state — counts and dates only,
// never photo content) gets its own JSON file, following the
// ReminderStateStore pattern (Stage 1, ADR-016 §7): it does NOT
// ride on the LocalService interface, which is faked across the
// whole test suite, and this record has a single consumer (the
// review-ask service).

import '../../core/utils/result.dart';
import '../review_ask/review_ask.dart';

abstract class ReviewAskStore {
  /// The saved record, or a default (unseeded) record when none
  /// exists yet.
  Future<Result<ReviewAskState>> load();

  /// Replaces the saved record.
  Future<Result<void>> save(ReviewAskState state);
}
