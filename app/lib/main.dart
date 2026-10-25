import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';

// Minimal entry ONLY (AGENTS.md): binding, theme, runApp. No UI and no
// feature logic live here.
void main() {
  runApp(const KlaraApp());
}

class KlaraApp extends StatelessWidget {
  const KlaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.tr(AppStrings.appTitle),
      theme: AppTheme.light,
      // Light theme only in Phase 1; dark mode is Phase 3.
      themeMode: ThemeMode.light,
      initialBinding: InitialBinding(),
      builder: (BuildContext context, Widget? child) {
        // System text scaling applies, clamped so layouts never break
        // (design.md §3).
        final TextScaler scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.30);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
      // Temporary home: bare scaffold, no buttons, no placeholder
      // actions. Deck routing (AppRoutes.deck) replaces this in a
      // later increment, once the deck view exists.
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
