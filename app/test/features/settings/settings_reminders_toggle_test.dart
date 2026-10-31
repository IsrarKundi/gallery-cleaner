// Widget tests for the Settings reminders toggle (fix plan
// Stage 1, requirements §7; behaviour changed by the owner
// decision of 31 Oct 2026, ADR-016 addendum): tapping the
// switch ON is the user's own deliberate action, so the system
// permission is requested DIRECTLY — no in-app benefit sheet
// appears first. A denial leaves the toggle off, unpersisted,
// with the reason shown; the grant outcome (on + persisted) is
// pinned at controller level in phase3a_settings_test.dart.
// (This file replaces the old sheet test file, which pinned
// the removed sheet-first behaviour.)
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
      dir = await Directory.systemTemp.createTemp('klara-toggle');
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

  testWidgets('toggle on asks the system directly — no sheet first', (
    WidgetTester tester,
  ) async {
    final _Notifications notifications = _Notifications();
    await pumpSettings(tester, notifications);

    await tester.tap(_remindersSwitch());
    await tester.pumpAndSettle();

    // Exactly one system request, made immediately by the tap
    // itself — before the fix this tap showed the sheet and the
    // count stayed 0 until the sheet was confirmed. The removed
    // priming sheet never appears (its strings no longer exist
    // in the app at all).
    expect(notifications.permissionRequests, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Turn on reminders'), findsNothing);
    expect(find.text('Not now'), findsNothing);

    // What the grant then does — toggle on, persisted — is
    // covered deterministically at controller level in
    // phase3a_settings_test.dart ('reminders ask permission on,
    // cancel all off'), which runs in the real zone; this
    // widget harness (real-IO LocalServiceImpl under fake async)
    // cannot observe the post-grant state reliably, the same
    // reason the old sheet tests never asserted it from here.
  });

  testWidgets('system denial leaves the toggle off', (
    WidgetTester tester,
  ) async {
    final _Notifications notifications = _Notifications()..deny = true;
    final ({SettingsController controller, LocalServiceImpl local}) harness =
        await pumpSettings(tester, notifications);

    await tester.tap(_remindersSwitch());
    await tester.pumpAndSettle();

    // One direct system request; its denial left everything off
    // and unsaved, with the reason on the controller.
    expect(notifications.permissionRequests, 1);
    expect(find.byType(BottomSheet), findsNothing);
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
