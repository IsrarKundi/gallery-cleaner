// flutter_local_notifications implementation of
// [NotificationService]. This is the ONLY file importing
// flutter_local_notifications (AGENTS.md dependency rules), and
// the only one importing timezone: a one-shot schedule needs a
// TZDateTime, built here from the fire instant in UTC — for a
// one-shot the plugin consumes the instant, so no timezone
// database or device-timezone plugin is needed (ADR-016).
//
// One channel for all reminders. Importance is default: the
// user opted in, and a reminder that never surfaces would be a
// silent no-op; it is still not a heads-up alarm (no exact
// scheduling, no SCHEDULE_EXACT_ALARM permission).
//
// The manifest already declares the plugin's scheduled +
// boot/update receivers and RECEIVE_BOOT_COMPLETED (audit
// finding F-33, fixed before this stage), so scheduled
// reminders survive a phone restart or app update with no
// manifest change.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'notification_service.dart';
import 'reminder.dart';

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'wipe_reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription =
      'Gentle reminders when cleaning is left unfinished.';

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<Result<bool>> areEnabled() async {
    try {
      await _ensureInitialized();
      final bool? enabled = await _android?.areNotificationsEnabled();
      // No Android implementation (host tests): treat as enabled,
      // the same leniency the Phase 3A code used for a null
      // permission answer.
      return Success<bool>(enabled ?? true);
    } catch (_) {
      return const Failure<bool>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }

  @override
  Future<Result<bool>> requestPermission() async {
    try {
      await _ensureInitialized();
      final bool? granted = await _android?.requestNotificationsPermission();
      return Success<bool>(granted ?? true);
    } catch (_) {
      return const Failure<bool>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }

  @override
  Future<Result<void>> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    try {
      await _ensureInitialized();
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC,
          fireAt.millisecondsSinceEpoch,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }

  @override
  Future<Result<void>> cancelAllReminders() async {
    try {
      await _ensureInitialized();
      for (final int id in allReminderNotificationIds()) {
        await _plugin.cancel(id: id);
      }
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }
}
