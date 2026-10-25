import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Light theme for Phase 1 (design.md §2, §3, §10).
///
/// Built ONLY from [AppPalette], [AppTextStyles] and [AppSizes]. No raw
/// colours, font sizes or layout numbers live here. ThemeMode.light is
/// set explicitly in main.dart; no dark theme is shipped in Phase 1
/// (dark mode is Phase 3).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const AppPalette palette = AppPalette.light;
    const AppSizes sizes = AppSizes();
    final AppTextStyles styles = AppTextStyles(palette);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.light(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        primaryContainer: palette.primaryContainer,
        onPrimaryContainer: palette.textPrimary,
        secondary: palette.secondary,
        onSecondary: palette.onPrimary,
        secondaryContainer: palette.surfaceVariant,
        onSecondaryContainer: palette.textPrimary,
        tertiary: palette.primary,
        onTertiary: palette.onPrimary,
        tertiaryContainer: palette.primaryContainer,
        onTertiaryContainer: palette.textPrimary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: palette.error,
        onError: palette.onPrimary,
        errorContainer: palette.errorBg,
        onErrorContainer: palette.textPrimary,
        outline: palette.border,
        outlineVariant: palette.border,
        surfaceContainerHighest: palette.surfaceVariant,
        onSurfaceVariant: palette.textSecondary,
        shadow: palette.scrim,
        scrim: palette.scrim,
        inverseSurface: palette.textPrimary,
        onInverseSurface: palette.onPrimary,
        inversePrimary: palette.primaryContainer,
        surfaceTint: palette.primary,
      ),
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        titleTextStyle: styles.titleLarge,
        iconTheme: IconThemeData(
          color: palette.textPrimary,
          size: sizes.iconMd,
        ),
        toolbarHeight: sizes.appBar,
      ),
      textTheme: TextTheme(
        displaySmall: styles.displaySmall,
        headlineLarge: styles.headlineLarge,
        headlineSmall: styles.headlineSmall,
        titleLarge: styles.titleLarge,
        titleMedium: styles.titleMedium,
        bodyLarge: styles.bodyLarge,
        bodyMedium: styles.bodyMedium,
        bodySmall: styles.bodySmall,
        labelLarge: styles.labelLarge,
        labelMedium: styles.labelMedium,
        labelSmall: styles.labelSmall,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: sizes.iconMd),
      dividerColor: palette.border,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: styles.bodyMedium.copyWith(color: palette.onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizes.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        titleTextStyle: styles.titleLarge,
        contentTextStyle: styles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizes.radiusLg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          disabledBackgroundColor: palette.primary,
          disabledForegroundColor: palette.onPrimary,
          textStyle: styles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizes.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          disabledForegroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          textStyle: styles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizes.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: styles.labelMedium,
        ),
      ),
      extensions: const <ThemeExtension<AppPalette>>[AppPalette.light],
    );
  }
}
