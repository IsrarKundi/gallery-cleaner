// Widget tests for the reminder permission sheet (fix plan
// Stage 1, requirements §7 / design §6): turning the Settings
// reminders toggle on while the system permission is not
// granted must show the in-app sheet (title + one-line benefit)
// BEFORE any system permission request, and both ways out
// without a grant — "Not now" and a system denial after
// confirming — leave the toggle off and unpersisted. The
// controller-level grant path is covered in
// phase3a_settings_test.dart; this file covers the sheet
// surface itself (checker gap, stage-1-check.md §5).
//
// The harness follows phase3a_settings_test.dart: the real
// LocalServiceImpl on a temp directory, built inside runAsync.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/settings/controller/settings_controller.dart';
import 'package:klara/features/settings/view/settings_view.dart';
import 'package:klara/services/appinfo/app_info_service.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/notifications/notification_service.dart';

class _Notifications implements NotificationService {
  bool enabled = false;
  bool deny = false;
  int permissionRequests = 0;

  @override
  Future<Result<bool>> areEnabled() async => Success<bool>(enabled);

  @override
  Future<Result<bool>> requestPermission() async {
    permissionRequests++;
    return Success<bool>(!deny);
  }

  @override
  Future<Result<void>> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> cancelAllReminders() async => const Success<void>(null);
}

class _AppInfo implements AppInfoService {
  @override
  Future<String> appVersion() async => '1.0.0';
}

/// The reminders row's switch: the Switch inside the InkWell
/// tile titled "Notifications".
Finder _remindersSwitch() {
  return find.descendant(
    of: find.ancestor(
      of: find.text(AppStrings.tr(AppStrings.settingsNotifications)),
      matching: find.byType(InkWell),
    ),
    matching: find.byType(Switch),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  Future<({SettingsController controller, LocalServiceImpl local})>
  pumpSettings(WidgetTester tester, _Notifications notifications) async {
    late Directory dir;
    late SettingsController controller;
    late LocalServiceImpl local;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('klara-sheet');
      local = LocalServiceImpl(directoryResolver: () async => dir);
      controller = SettingsController(
        local: local,
        notifications: notifications,
        appInfo: _AppInfo(),
      );
      await controller.init();
    });
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    Get.put<SettingsController>(controller);
    // Tall surface so the lazy ListView builds every row at once.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const SettingsView()),
    );
    await tester.pumpAndSettle();
    return (controller: controller, local: local);
  }

  Future<bool> persistedReminders(LocalServiceImpl local) async {
    final Result<AppSettings> result = await local.loadSettings();
    return result.fold(
      onSuccess: (AppSettings value) => value.reminders,
      onFailure: (_) => throw StateError('load failed'),
    );
  }

  testWidgets('sheet shows before any system request; Not now asks nothing', (
    WidgetTester tester,
  ) async {
    final _Notifications notifications = _Notifications();
    final ({SettingsController controller, LocalServiceImpl local}) harness =
        await pumpSettings(tester, notifications);

    await tester.tap(_remindersSwitch());
    await tester.pumpAndSettle();

    // The sheet is up — benefit line and both choices — and the
    // system permission has NOT been requested yet.
    expect(
      find.text(AppStrings.tr(AppStrings.reminderPermissionBenefit)),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.tr(AppStrings.reminderPermissionTurnOn)),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.tr(AppStrings.reminderPermissionNotNow)),
      findsOneWidget,
    );
    expect(notifications.permissionRequests, 0);

    await tester.tap(
      find.text(AppStrings.tr(AppStrings.reminderPermissionNotNow)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.tr(AppStrings.reminderPermissionNotNow)),
      findsNothing,
    );
    expect(notifications.permissionRequests, 0);
    expect(harness.controller.reminders, isFalse);
    expect(tester.widget<Switch>(_remindersSwitch()).value, isFalse);
    await tester.runAsync(() async {
      expect(await persistedReminders(harness.local), isFalse);
    });
  });

  testWidgets('system denial after confirming leaves the toggle off', (
    WidgetTester tester,
  ) async {
    final _Notifications notifications = _Notifications()..deny = true;
    final ({SettingsController controller, LocalServiceImpl local}) harness =
        await pumpSettings(tester, notifications);

    await tester.tap(_remindersSwitch());
    await tester.pumpAndSettle();
    expect(notifications.permissionRequests, 0);

    await tester.tap(
      find.text(AppStrings.tr(AppStrings.reminderPermissionTurnOn)),
    );
    await tester.pumpAndSettle();

    // Exactly one system request happened — after the sheet —
    // and its denial left everything off and unsaved.
    expect(notifications.permissionRequests, 1);
    expect(
      find.text(AppStrings.tr(AppStrings.reminderPermissionTurnOn)),
      findsNothing,
    );
    expect(harness.controller.reminders, isFalse);
    expect(
      harness.controller.errorKey.value,
      AppStrings.settingsNotificationsDenied,
    );
    expect(tester.widget<Switch>(_remindersSwitch()).value, isFalse);
    await tester.runAsync(() async {
      expect(await persistedReminders(harness.local), isFalse);
    });
  });
}
