// Persistence for the state-reminder record (fix plan Stage 1).
//
// Interface only. The record (per-state start times, sent steps
// and scheduled fire times — dates and counts only, never photo
// content) gets its own JSON file, following LocalServiceImpl's
// one-file-per-data-kind pattern. It deliberately does NOT ride
// on the LocalService interface: that interface is implemented
// by fakes across the whole test suite, and reminder state is a
// separate data kind with a single consumer (the reminder
// engine), so a narrow store keeps the change surface honest.

import '../../core/utils/result.dart';
import '../notifications/reminder.dart';

abstract class ReminderStateStore {
  /// The saved record, or an empty record when none exists yet.
  Future<Result<ReminderRecord>> load();

  /// Replaces the saved record.
  Future<Result<void>> save(ReminderRecord record);
}
