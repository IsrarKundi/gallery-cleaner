// flutter_local_notifications implementation of
// [NotificationService]. This is the ONLY file importing
// flutter_local_notifications (AGENTS.md dependency rules).
//
// One notification id, one channel, one schedule: the weekly nudge
// repeats weekly from the moment it is set (inexact schedule mode,
// so the system may shift it — a nudge, not an alarm). Importance
// is low: a quiet weekly reminder, never a heads-up interruption.
// Scheduling requests the Android notification permission first;
// a denial is a failure, not a silent no-op, so Settings leaves
// the toggle OFF (see SettingsController).
//
// Android 13+ note: showing notifications needs POST_NOTIFICATIONS,
// which is the single new permission in this increment (see
// AndroidManifest.xml). It is requested at toggle time only, never
// at first launch, and no media/storage permission changes.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'notification_service.dart';

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The one weekly-nudge notification id.
  static const int weeklyNudgeId = 7001;

  static const String _channelId = 'klara_weekly';
  static const String _channelName = 'Weekly nudge';

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

  @override
  Future<Result<void>> scheduleWeeklyNudge() async {
    try {
      await _ensureInitialized();
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await android?.requestNotificationsPermission();
      if (granted == false) {
        return const Failure<void>(
          AppFailure(messageKey: AppStrings.settingsNotificationsDenied),
        );
      }
      await _plugin.periodicallyShow(
        id: weeklyNudgeId,
        title: AppStrings.tr(AppStrings.settingsNudgeTitle),
        body: AppStrings.tr(AppStrings.settingsNudgeBody),
        repeatInterval: RepeatInterval.weekly,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'One gentle weekly reminder to clean up.',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }

  @override
  Future<Result<void>> cancelWeeklyNudge() async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(id: weeklyNudgeId);
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorNotifications),
      );
    }
  }
}
