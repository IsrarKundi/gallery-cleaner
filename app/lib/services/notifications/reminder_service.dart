// State-based reminder engine (wipe. fix plan Stage 1,
// requirements §7 as amended 30 Oct 2026).
//
// Interface only. The implementation observes the app's
// persisted state (deck sessions, Trash records, history,
// completion days — LocalService), plans with the pure
// [ReminderPlanner], and applies the plan through
// [NotificationService]: cancel everything, schedule the plan.
// It runs at app launch (started from the splash binding, like
// the deck warm-up), again whenever the app is paused (the
// moment "what did the user leave unfinished?" is best asked),
// and when the Settings toggle turns reminders on.
//
// refresh() never throws and never blocks a screen: a failed
// read leaves the previously scheduled reminders untouched
// rather than cancelling good reminders on a bad read.

abstract class ReminderService {
  /// Re-evaluates the reminder states from persisted app state
  /// and replaces the scheduled set with the current plan.
  /// Honours the persisted reminders on/off choice and the
  /// system permission: with either off, nothing is scheduled.
  Future<void> refresh();
}
