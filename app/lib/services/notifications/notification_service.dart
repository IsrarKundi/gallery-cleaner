// Weekly-nudge scheduling (Phase 3A, requirements §7).
//
// Interface only. The implementation is the single file allowed to
// import flutter_local_notifications. Exactly ONE notification is
// ever scheduled: a gentle weekly nudge (see the copy in
// app_strings.dart: no countdown, no marketing). Cancelling removes
// it. Nothing here reads, logs or sends photo content.

import '../../core/utils/result.dart';

abstract class NotificationService {
  /// Schedules the single weekly nudge. Returns failure when the
  /// device notification permission is denied, so the caller can
  /// leave the toggle OFF instead of pretending a nudge is set.
  Future<Result<void>> scheduleWeeklyNudge();

  /// Cancels the weekly nudge, if one is scheduled.
  Future<Result<void>> cancelWeeklyNudge();
}
