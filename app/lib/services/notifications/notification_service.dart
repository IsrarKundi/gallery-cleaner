// Low-level notification gateway for the state-based reminders
// (wipe. fix plan Stage 1, requirements §7 as amended 30 Oct
// 2026; replaces the Phase 3A weekly nudge).
//
// Interface only. The implementation is the single file allowed
// to import flutter_local_notifications. This gateway knows
// nothing about states or copy: the reminder engine
// (reminder_service.dart) decides WHAT is scheduled and WHEN;
// this file only talks to the plugin. Nothing here reads, logs
// or sends photo content.

import '../../core/utils/result.dart';

abstract class NotificationService {
  /// Whether notifications are currently enabled for the app
  /// (system permission granted). Never prompts: safe to call
  /// at launch or on resume.
  Future<Result<bool>> areEnabled();

  /// Requests the Android notification permission (the system
  /// popup). Only ever called from the in-app permission sheet
  /// flow in Settings, never at launch. Success(false) means the
  /// user (or the system) said no — an answer, not an error.
  Future<Result<bool>> requestPermission();

  /// Schedules one reminder for [fireAt] (local time). Inexact
  /// scheduling: the system may shift it slightly — a reminder,
  /// not an alarm, and no exact-alarm permission is requested.
  Future<Result<void>> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  });

  /// Cancels every notification this system may have scheduled,
  /// including the legacy weekly nudge from older builds.
  Future<Result<void>> cancelAllReminders();
}
