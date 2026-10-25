// Phase 3A settings tests (requirements §7, Phase 3): dark palette
// pins + contrast reasoning witnesses, theme switching via tokens,
// settings persistence + application, splash asset selection, the
// blurred review tile, and the settings screen rendering.
//
// Settings persistence uses the real [LocalServiceImpl] with a temp
// directory (never platform channels): a saved setting must read
// back from disk, not from a fake's memory.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/constants/app_colors.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/theme/theme_ext.dart';
import 'package:klara/core/utils/app_haptics.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/widgets/review_grid_tile.dart';
import 'package:klara/features/settings/controller/settings_controller.dart';
import 'package:klara/features/settings/view/settings_view.dart';
import 'package:klara/features/splash/view/splash_view.dart';
import 'package:klara/services/appinfo/app_info_service.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/notifications/notification_service.dart';

class _Notifications implements NotificationService {
  bool deny = false;
  int scheduled = 0;
  int cancelled = 0;

  @override
  Future<Result<void>> scheduleWeeklyNudge() async {
    if (deny) {
      return const Failure<void>(
        AppFailure(messageKey: 'settingsNotificationsDenied'),
      );
    }
    scheduled++;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> cancelWeeklyNudge() async {
    cancelled++;
    return const Success<void>(null);
  }
}

class _AppInfo implements AppInfoService {
  _AppInfo(this.version);

  final String version;

  @override
  Future<String> appVersion() async => version;
}

Future<LocalServiceImpl> _tempLocal() async {
  final Directory dir = await Directory.systemTemp.createTemp('klara3a');
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  return LocalServiceImpl(directoryResolver: () async => dir);
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
    AppHaptics.enabled = true;
  });

  group('dark palette', () {
    test('pins every locked dark value', () {
      const AppPalette dark = AppPalette.dark;
      expect(dark.background, const Color(0xFF121212));
      expect(dark.surface, const Color(0xFF1E1E1E));
      expect(dark.surfaceVariant, const Color(0xFF2C2C2C));
      expect(dark.primary, const Color(0xFF8AB4F8));
      expect(dark.onPrimary, const Color(0xFF202124));
      expect(dark.primaryContainer, const Color(0xFF1E3A5F));
      expect(dark.secondary, const Color(0xFF9AA0A6));
      expect(dark.textPrimary, const Color(0xFFE8EAED));
      expect(dark.textSecondary, const Color(0xFF9AA0A6));
      expect(dark.textTertiary, const Color(0xFF80868B));
      expect(dark.border, const Color(0xFF3C4043));
      expect(dark.success, const Color(0xFF81C995));
      expect(dark.successBg, const Color(0xFF1C3325));
      expect(dark.warning, const Color(0xFFFDD663));
      expect(dark.warningBg, const Color(0xFF332A0A));
      expect(dark.error, const Color(0xFFF28B82));
      expect(dark.errorBg, const Color(0xFF3C1E1A));
      expect(dark.scrim, const Color(0x99000000));
      expect(dark.onScrim, const Color(0xFFFFFFFF));
    });

    test('dark surfaces are the #121212 family, never pure black', () {
      expect(AppPalette.dark.background, isNot(const Color(0xFF000000)));
      expect(AppPalette.dark.surface, isNot(const Color(0xFF000000)));
    });

    test('favourite is the primary in both themes (no new hue)', () {
      expect(AppPalette.light.favourite, AppPalette.light.primary);
      expect(AppPalette.dark.favourite, AppPalette.dark.primary);
      expect(AppPalette.dark.favourite, const Color(0xFF8AB4F8));
    });

    test('tonal elevation rises with the surface', () {
      final AppPalette dark = AppPalette.dark;
      expect(
        dark.surface.computeLuminance(),
        greaterThan(dark.background.computeLuminance()),
      );
      expect(
        dark.surfaceVariant.computeLuminance(),
        greaterThan(dark.surface.computeLuminance()),
      );
    });
  });

  group('theme switching', () {
    test('dark theme carries the dark palette and dark brightness', () {
      final ThemeData dark = AppTheme.dark;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF121212));
      expect(dark.extension<AppPalette>(), AppPalette.dark);
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
    });

    testWidgets('theme mode changes the scaffold background via tokens', (
      WidgetTester tester,
    ) async {
      BuildContext? captured;
      Future<void> pump(ThemeMode mode) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: Builder(
              builder: (BuildContext context) {
                captured = context;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(ThemeMode.light);
      expect(captured!.palette.background, const Color(0xFFFFFFFF));
      expect(captured!.palette.primary, const Color(0xFF4285F4));
      expect(
        Theme.of(captured!).scaffoldBackgroundColor,
        const Color(0xFFFFFFFF),
      );
      await pump(ThemeMode.dark);
      expect(captured!.palette.background, const Color(0xFF121212));
      expect(captured!.palette.primary, const Color(0xFF8AB4F8));
      expect(
        Theme.of(captured!).scaffoldBackgroundColor,
        const Color(0xFF121212),
      );
    });
  });

  group('AppSettings record', () {
    test('defaults are system / off / haptics on', () {
      const AppSettings settings = AppSettings();
      expect(settings.theme, ThemePreference.system);
      expect(settings.privateBlur, isFalse);
      expect(settings.protection, isFalse);
      expect(settings.weeklyNudge, isFalse);
      expect(settings.haptics, isTrue);
      expect(settings.reducedMotion, isFalse);
      expect(settings.trashAutoEmptyPrompt, isFalse);
    });

    test('round-trips through JSON and tolerates old records', () {
      final AppSettings restored = AppSettings.fromJson(
        const AppSettings(
          theme: ThemePreference.dark,
          privateBlur: true,
          protection: true,
        ).toJson(),
      );
      expect(restored.theme, ThemePreference.dark);
      expect(restored.privateBlur, isTrue);
      expect(restored.protection, isTrue);
      // An old record (goal/tutorial keys only) reads as defaults.
      expect(
        AppSettings.fromJson(<String, dynamic>{}).theme,
        ThemePreference.system,
      );
      expect(
        AppSettings.fromJson(<String, dynamic>{'theme': 'bogus'}).theme,
        ThemePreference.system,
      );
    });

    test('real impl persists settings without dropping other keys', () async {
      final LocalServiceImpl local = await _tempLocal();
      await local.setTutorialSeen(true);
      await local.saveGoalTargetMb(2048);
      await local.saveSettings(
        const AppSettings(theme: ThemePreference.dark, haptics: false),
      );
      final AppSettings loaded = (await local.loadSettings()).fold(
        onSuccess: (AppSettings value) => value,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(loaded.theme, ThemePreference.dark);
      expect(loaded.haptics, isFalse);
      final bool tutorialSeen = (await local.isTutorialSeen()).fold(
        onSuccess: (bool value) => value,
        onFailure: (_) => false,
      );
      expect(tutorialSeen, isTrue);
      final double goal = (await local.loadGoalTargetMb()).fold(
        onSuccess: (double value) => value,
        onFailure: (_) => 0,
      );
      expect(goal, 2048);
    });
  });

  group('SettingsController', () {
    Future<SettingsController> make({
      required LocalServiceImpl local,
      _Notifications? notifications,
      String appVersion = '1.0.0',
      List<ThemeMode>? applied,
    }) async {
      final SettingsController controller = SettingsController(
        local: local,
        notifications: notifications,
        appInfo: _AppInfo(appVersion),
        themeApplier: applied == null
            ? null
            : (ThemeMode mode) => applied.add(mode),
      );
      await controller.init();
      return controller;
    }

    test('every toggle persists and the theme applies', () async {
      final LocalServiceImpl local = await _tempLocal();
      final List<ThemeMode> applied = <ThemeMode>[];
      final SettingsController controller = await make(
        local: local,
        applied: applied,
      );
      expect(controller.theme, ThemePreference.system);
      await controller.setTheme(ThemePreference.dark);
      expect(applied, contains(ThemeMode.dark));
      await controller.setPrivateBlur(true);
      await controller.setProtection(true);
      await controller.setHaptics(false);
      expect(AppHaptics.enabled, isFalse);
      await controller.setReducedMotion(true);
      await controller.setTrashAutoEmptyPrompt(true);
      final AppSettings saved = (await local.loadSettings()).fold(
        onSuccess: (AppSettings value) => value,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(saved.theme, ThemePreference.dark);
      expect(saved.privateBlur, isTrue);
      expect(saved.protection, isTrue);
      expect(saved.haptics, isFalse);
      expect(saved.reducedMotion, isTrue);
      expect(saved.trashAutoEmptyPrompt, isTrue);
    });

    test('persisted theme applies at load', () async {
      final LocalServiceImpl local = await _tempLocal();
      await local.saveSettings(const AppSettings(theme: ThemePreference.light));
      final List<ThemeMode> applied = <ThemeMode>[];
      await make(local: local, applied: applied);
      expect(applied, contains(ThemeMode.light));
    });

    test('weekly nudge schedules on, cancels off', () async {
      final LocalServiceImpl local = await _tempLocal();
      final _Notifications notifications = _Notifications();
      final SettingsController controller = await make(
        local: local,
        notifications: notifications,
      );
      await controller.setWeeklyNudge(true);
      expect(notifications.scheduled, 1);
      expect(controller.weeklyNudge, isTrue);
      await controller.setWeeklyNudge(false);
      expect(notifications.cancelled, 1);
      expect(controller.weeklyNudge, isFalse);
    });

    test('denied notification permission leaves the toggle off', () async {
      final LocalServiceImpl local = await _tempLocal();
      final _Notifications notifications = _Notifications()..deny = true;
      final SettingsController controller = await make(
        local: local,
        notifications: notifications,
      );
      await controller.setWeeklyNudge(true);
      expect(controller.weeklyNudge, isFalse);
      expect(controller.errorKey.value, isNotEmpty);
      expect(notifications.scheduled, 0);
    });

    test('version comes from the app-info service, never hard-coded', () async {
      final LocalServiceImpl local = await _tempLocal();
      final SettingsController controller = await make(
        local: local,
        appVersion: '9.9.9',
      );
      expect(controller.version.value, contains('9.9.9'));
      final SettingsController unknown = await make(
        local: local,
        appVersion: '',
      );
      expect(unknown.version.value, isNot(contains('9.9.9')));
    });
  });

  group('splash theme adaptation', () {
    test('dark picks the white assets, light picks the ink assets', () {
      expect(splashLogoAsset(true), contains('white'));
      expect(splashLogoAsset(false), isNot(contains('white')));
      expect(splashLottieAsset(true), contains('white'));
      expect(splashLottieAsset(false), isNot(contains('white')));
    });
  });

  group('ReviewGridTile blur', () {
    MediaAsset asset(String id) {
      return MediaAsset(
        id: id,
        type: MediaAssetType.image,
        width: 10,
        height: 10,
        sizeBytes: 100,
        createDate: DateTime(2026, 10, 25),
        title: '$id.jpg',
        albumName: 'Recent',
      );
    }

    testWidgets('blurred tile filters, reveals on tap, then unmarks', (
      WidgetTester tester,
    ) async {
      bool revealed = false;
      bool unmarked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ReviewGridTile(
              asset: asset('a'),
              thumbnail: null,
              thumbnailFailed: true,
              blurred: true,
              onReveal: () => revealed = true,
              onTap: () => unmarked = true,
            ),
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.text('Tap to reveal'), findsOneWidget);
      await tester.tap(find.byType(ReviewGridTile));
      expect(revealed, isTrue);
      expect(unmarked, isFalse);
    });

    testWidgets('unblurred tile has no filter and taps unmark', (
      WidgetTester tester,
    ) async {
      bool unmarked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ReviewGridTile(
              asset: asset('a'),
              thumbnail: null,
              thumbnailFailed: true,
              onTap: () => unmarked = true,
            ),
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsNothing);
      await tester.tap(find.byType(ReviewGridTile));
      expect(unmarked, isTrue);
    });
  });

  group('SettingsView', () {
    testWidgets('renders every section and toggle', (
      WidgetTester tester,
    ) async {
      // Real file IO must run in runAsync: a widget-test body awaits
      // real futures only when the binding pumps, so awaiting
      // createTemp/init directly deadlocks before the first pump.
      late Directory dir;
      late SettingsController controller;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('klara3a-view');
        controller = SettingsController(
          local: LocalServiceImpl(directoryResolver: () async => dir),
          appInfo: _AppInfo('1.0.0'),
        );
        await controller.init();
      });
      Get.put<SettingsController>(controller);
      // Tall surface so the lazy ListView builds every row at once;
      // scrolling to not-yet-built rows is not possible.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.light, home: const SettingsView()),
      );
      await tester.pumpAndSettle();
      for (final String label in <String>[
        'Theme',
        'Private blur',
        'Protect favourites',
        'Weekly nudge',
        'Haptics',
        'Reduced motion',
        'Prompt to empty expired trash',
        'Klara',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.byType(SwitchListTile), findsNWidgets(6));
      expect(find.byType(RadioListTile<ThemePreference>), findsNWidgets(3));
      await tester.runAsync(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
    });
  });
}
