// Settings screen state (Phase 3A, requirements §7).
//
// Owns the persisted [AppSettings] record and APPLIES each toggle,
// it does not merely store it:
// - theme: [Get.changeThemeMode] (via [themeApplier], injectable
//   for tests) so deck, review, trash, history, hub, dialogs,
//   snackbars and sheets all re-theme reactively.
// - haptics: [AppHaptics.enabled].
// - reduced motion: [reducedMotion] is read by main.dart's builder,
//   which forces MediaQuery disableAnimations when ON.
// - weekly nudge: the notification service schedules exactly one
//   weekly nudge when ON and cancels it when OFF; a denied
//   notification permission leaves the toggle OFF with an error.
// - private blur / protection: read live by review, trash, deck,
//   smart-deck and duplicates controllers from LocalService, so a
//   change here applies on the next screen load without restart.
// - trash auto-empty prompt: read by the trash controller; see the
//   trust-rule resolution on [AppSettings.trashAutoEmptyPrompt].
//
// Registered permanent in InitialBinding (so the persisted theme,
// haptics and reduced-motion apply at launch, not only after the
// settings screen is first opened); the /settings binding reuses
// that instance instead of creating a second one.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/appinfo/app_info_service.dart';
import '../../../services/local/local_service.dart';
import '../../../services/notifications/notification_service.dart';

class SettingsController extends GetxController {
  SettingsController({
    required this.local,
    this.notifications,
    this.appInfo,
    this.themeApplier,
  });

  final LocalService local;

  /// Null in tests that only check persistence: toggling the nudge
  /// then only persists, it never schedules.
  ///
  /// Phase 1.7: in production this is null too — InitialBinding
  /// deliberately does NOT resolve the service at launch (that would
  /// defeat its lazy registration). [_notifications] resolves it on
  /// first use instead, so the plugin object is created on the first
  /// nudge toggle, not at startup.
  final NotificationService? notifications;

  /// Null in tests: the version then reads as "unknown".
  ///
  /// Phase 1.7: in production this is null too, for the same reason
  /// as [notifications]. [_appInfo] resolves it on the first version
  /// read, which happens on the settings screen, not at startup.
  final AppInfoService? appInfo;

  /// Defaults to [Get.changeThemeMode]; tests inject a recorder.
  final void Function(ThemeMode mode)? themeApplier;

  /// Phase 1.7: the settings load started in [onInit]. The splash
  /// gate (see SplashController.beforeComplete) awaits this so the
  /// persisted theme applies before the splash leaves — no flash of
  /// the wrong theme. Falls back to starting the load if [onInit]
  /// never ran (directly constructed controllers in tests).
  Future<void> get settingsReady => _initFuture ??= init();

  Future<void>? _initFuture;

  /// Lazily resolved service, preferring the constructor-injected
  /// instance (tests) and falling back to the lazy registration
  /// (production, first use only).
  NotificationService? get _notifications =>
      notifications ??
      (Get.isRegistered<NotificationService>()
          ? Get.find<NotificationService>()
          : null);

  /// See [_notifications].
  AppInfoService? get _appInfo =>
      appInfo ??
      (Get.isRegistered<AppInfoService>() ? Get.find<AppInfoService>() : null);

  final Rx<AppSettings> settings = const AppSettings().obs;
  final RxString errorKey = ''.obs;
  final RxString version = ''.obs;

  ThemePreference get theme => settings.value.theme;
  bool get privateBlur => settings.value.privateBlur;
  bool get protection => settings.value.protection;
  bool get weeklyNudge => settings.value.weeklyNudge;
  bool get haptics => settings.value.haptics;
  bool get reducedMotion => settings.value.reducedMotion;
  bool get trashAutoEmptyPrompt => settings.value.trashAutoEmptyPrompt;

  @override
  void onInit() {
    super.onInit();
    _initFuture = init();
  }

  /// Loads the persisted record (defaults for a fresh install) and
  /// applies theme + haptics immediately. Phase 1.7: the version
  /// read is NOT here any more — PackageInfo.fromPlatform is a
  /// pointless platform call on every cold start, and the version is
  /// only shown on the settings screen, so [loadVersion] reads it
  /// when that screen opens.
  Future<void> init() async {
    final Result<AppSettings> result = await local.loadSettings();
    result.fold(
      onSuccess: (AppSettings value) {
        settings.value = value;
        _applyTheme(value.theme);
        AppHaptics.enabled = value.haptics;
      },
      onFailure: (_) {},
    );
  }

  /// Reads the version (idempotent) for the settings screen. Called
  /// by SettingsBinding on every settings visit; a second call is a
  /// no-op so repeat visits do not repeat the platform call.
  Future<void> loadVersion() async {
    if (_versionLoaded) {
      return;
    }
    _versionLoaded = true;
    version.value = await _readVersion();
  }

  bool _versionLoaded = false;

  Future<String> _readVersion() async {
    final String version = await _appInfo?.appVersion() ?? '';
    if (version.isEmpty) {
      return AppStrings.tr(AppStrings.settingsVersionUnknown);
    }
    return AppStrings.tr(AppStrings.settingsAboutVersion, <String, String>{
      'version': version,
    });
  }

  Future<bool> _persist(AppSettings next) async {
    errorKey.value = '';
    final Result<void> result = await local.saveSettings(next);
    final bool ok = result.fold(
      onSuccess: (_) => true,
      onFailure: (_) => false,
    );
    if (!ok) {
      errorKey.value = AppStrings.errorLocal;
      return false;
    }
    settings.value = next;
    return true;
  }

  void _applyTheme(ThemePreference preference) {
    final ThemeMode mode = switch (preference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };
    if (themeApplier != null) {
      themeApplier!(mode);
    } else {
      Get.changeThemeMode(mode);
    }
  }

  Future<void> setTheme(ThemePreference preference) async {
    if (preference == theme) {
      return;
    }
    final AppSettings next = settings.value.copyWith(theme: preference);
    if (await _persist(next)) {
      _applyTheme(preference);
      AppHaptics.mark();
    }
  }

  Future<void> setPrivateBlur(bool value) async {
    if (value == privateBlur) {
      return;
    }
    if (await _persist(settings.value.copyWith(privateBlur: value))) {
      AppHaptics.mark();
    }
  }

  Future<void> setProtection(bool value) async {
    if (value == protection) {
      return;
    }
    if (await _persist(settings.value.copyWith(protection: value))) {
      AppHaptics.mark();
    }
  }

  Future<void> setWeeklyNudge(bool value) async {
    if (value == weeklyNudge) {
      return;
    }
    if (value) {
      final Result<void> scheduled =
          await _notifications?.scheduleWeeklyNudge() ??
          const Success<void>(null);
      if (scheduled.isFailure) {
        errorKey.value = (scheduled as Failure<void>).failure.messageKey;
        return;
      }
    } else {
      await _notifications?.cancelWeeklyNudge();
    }
    if (await _persist(settings.value.copyWith(weeklyNudge: value))) {
      AppHaptics.mark();
    }
  }

  Future<void> setHaptics(bool value) async {
    if (value == haptics) {
      return;
    }
    if (await _persist(settings.value.copyWith(haptics: value))) {
      AppHaptics.enabled = value;
      AppHaptics.mark();
    }
  }

  Future<void> setReducedMotion(bool value) async {
    if (value == reducedMotion) {
      return;
    }
    if (await _persist(settings.value.copyWith(reducedMotion: value))) {
      AppHaptics.mark();
    }
  }

  Future<void> setTrashAutoEmptyPrompt(bool value) async {
    if (value == trashAutoEmptyPrompt) {
      return;
    }
    if (await _persist(settings.value.copyWith(trashAutoEmptyPrompt: value))) {
      AppHaptics.mark();
    }
  }
}
