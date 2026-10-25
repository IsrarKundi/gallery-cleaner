import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Light + dark themes for Klara (design.md §2, §3, §10).
///
/// Built ONLY from [AppPalette], [AppTextStyles] and [AppSizes]. No raw
/// colours, font sizes or layout numbers live here. The dark theme
/// (Phase 3A) is the same builder with the dark palette — no screen
/// may hard-code light colours; every colour comes from the active
/// palette via `context.palette`, so re-theming is automatic.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    const AppSizes sizes = AppSizes();
    final AppTextStyles styles = AppTextStyles(palette);
    final bool isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
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
        // The bar is the ink colour in both themes (dark ink on
        // light, light ink on dark), so its text is the inverse:
        // white labels on light theme, dark labels on dark theme.
        backgroundColor: palette.textPrimary,
        contentTextStyle: styles.bodyMedium.copyWith(
          color: isDark ? palette.background : palette.onPrimary,
        ),
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
          // Phase 3B accessibility (design.md §9): a text button
          // is plain text on the background, so it needs 4.5:1 —
          // and light primary #4285F4 on white is only 3.56:1.
          // Text ink passes in both themes (16.1:1 light,
          // 13.83:1 dark). Filled buttons keep primary fills:
          // their white labels are UI components at the 3:1 bar.
          foregroundColor: palette.textPrimary,
          textStyle: styles.labelMedium,
        ),
      ),
      extensions: <ThemeExtension<AppPalette>>[palette],
    );
  }
}
