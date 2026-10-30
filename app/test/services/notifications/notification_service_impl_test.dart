// Gateway tests for the reminder notification service
// (fix plan Stage 1, requirements §7). The engine tests use a
// fake NotificationService, so they cannot see the exact set of
// ids the real gateway cancels. That set is pinned here: it
// must always contain the legacy weekly-nudge id (7001) — the
// engine's cancel-all is the only thing standing between an old
// build's weekly nudge and the state reminders, so dropping
// 7001 from the list would let the legacy nudge survive every
// refresh (checker gap, stage-1-check.md §5).
//
// How: NotificationServiceImpl drives the real (singleton)
// plugin. On an unlisted target platform the plugin's cancel
// falls through to FlutterLocalNotificationsPlatform.instance,
// so a recording platform instance observes every id the
// gateway asks to cancel — no platform channel involved.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/notifications/notification_service_impl.dart';
import 'package:klara/services/notifications/reminder.dart';

class _RecordingPlatform extends FlutterLocalNotificationsPlatform {
  final List<int> cancelledIds = <int>[];

  @override
  Future<void> cancel({required int id}) async {
    cancelledIds.add(id);
  }
}

void main() {
  late _RecordingPlatform platform;

  setUp(() {
    // An unlisted platform makes the plugin's initialize a
    // no-op success and routes cancel() to the platform
    // instance registered below.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    platform = _RecordingPlatform();
    FlutterLocalNotificationsPlatform.instance = platform;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('the legacy weekly-nudge id is the Phase 3A id 7001', () {
    expect(legacyWeeklyNudgeId, 7001);
  });

  test('the cancel set contains the legacy id and every state step', () {
    final List<int> ids = allReminderNotificationIds();
    expect(ids, contains(legacyWeeklyNudgeId));
    for (final ReminderStateKind kind in ReminderStateKind.values) {
      for (int step = 0; step < reminderSteps[kind]!.length; step++) {
        expect(ids, contains(reminderNotificationId(kind, step)));
      }
    }
  });

  test(
    'cancelAllReminders cancels every id in the set, 7001 included',
    () async {
      final NotificationServiceImpl service = NotificationServiceImpl();
      final Result<void> result = await service.cancelAllReminders();
      expect(result.isSuccess, isTrue);
      expect(platform.cancelledIds, allReminderNotificationIds());
      expect(platform.cancelledIds, contains(7001));
    },
  );
}
