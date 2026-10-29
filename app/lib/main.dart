import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/controller/settings_controller.dart';

// Minimal entry ONLY (AGENTS.md): binding, theme, routes, runApp. No
// UI and no feature logic live here.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Solutions 3.1: tune the framework image cache to the thumbnail
  // budget. Decoded bytes are the big memory (a 1080 px deck card
  // decodes to ~4.6 MiB RGBA; a 320 px grid tile to ~0.4 MiB), so
  // the cache holds roughly a deck stack plus a grid viewport, next
  // to the thumbnail service's own 32 MiB byte budget — instead of
  // the framework default (1000 images / 100 MiB), which lets a
  // long swipe session grow decoded memory unbounded.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  runApp(const KlaraApp());
}

class KlaraApp extends StatelessWidget {
  const KlaraApp({super.key, this.initialBinding});

  /// Test seam ONLY: the golden-path tests inject fake services
  /// here (no device, no MediaStore on the host). Production
  /// passes nothing, so behaviour is exactly [InitialBinding].
  final Bindings? initialBinding;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.tr(AppStrings.appTitle),
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      // Default is System (the persisted setting's default, Phase
      // 3A): the OS theme applies until the user picks Light/Dark
      // in Settings, and SettingsController (permanent, from
      // InitialBinding) re-applies the persisted choice at launch
      // via Get.changeThemeMode.
      themeMode: ThemeMode.system,
      initialBinding: initialBinding ?? InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      builder: (BuildContext context, Widget? child) {
        // System text scaling applies, clamped so layouts never break
        // (design.md §3).
        final TextScaler scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.30);
        // Reduced motion (Phase 3A): when the in-app toggle is ON,
        // animations are disabled app-wide even if the system
        // setting is off; when OFF, the system setting applies
        // (existing behaviour). Without a settings controller
        // (tests with a custom binding), the system setting alone
        // applies. The Obx re-runs this builder when the toggle
        // changes, so flipping the toggle re-themes motion live.
        if (!Get.isRegistered<SettingsController>()) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          );
        }
        final SettingsController settings = Get.find<SettingsController>();
        return Obx(() {
          final bool disableAnimations =
              settings.reducedMotion || MediaQuery.disableAnimationsOf(context);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          );
        });
      },
    );
  }
}
