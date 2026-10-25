import 'package:flutter/material.dart';

/// The single source of colour truth for Klara (design.md §2, §10).
///
/// LIGHT set only. Phase 1 ships light theme only; dark mode is Phase 3,
/// so no dark set is shipped here.
///
/// Locked palette (owner pick, 25 Oct 2026, Option B "Google blue"):
/// primary #4285F4, Keep/success #0F9D58, Delete/error #DB4437,
/// Maybe/warning #F4B400, background #FFFFFF. Favourite is a heart filled
/// with the primary colour, so it has no separate hue: see [favourite].
///
/// Flat only: surfaces are solid fills plus hairline borders. No shadow,
/// glow or blended-fill decoration is defined here.
///
/// Contrast, measured against white (design.md §9: 4.5:1 normal text):
/// - textPrimary #202124: 16.1:1, textSecondary #5F6368: 6.05:1,
///   textTertiary #70757A: 4.65:1. All three pass 4.5:1, so even the
///   tertiary tone is safe at small sizes. Lighter greys such as #80868B
///   (3.68:1) and #8A919C (3.18:1) were deliberately NOT used for text.
/// - Primary, success and error as fills with white labels sit at
///   3.56:1, 3.51:1 and 4.29:1. That passes the 3:1 threshold for UI
///   components, but not 4.5:1 for normal text, so these colours are
///   never used as small text on white. Small coloured meaning is carried
///   by tint backgrounds (successBg / warningBg / errorBg) with dark text
///   plus an icon and a label, never by colour alone.
/// - Warning #F4B400 is 1.85:1 on white and 8.72:1 under #202124 text, so
///   it is used ONLY as a fill or badge with dark text, never as text on
///   white at any size.
/// - Border #DADCE0 is a hairline only, never text, so its low contrast
///   against white is acceptable for a non-text divider.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.scrim,
  });

  /// Locked light palette. The regression test in
  /// test/core/constants/app_palette_test.dart pins the locked hex values.
  static const AppPalette light = AppPalette(
    // Locked values (Option B "Google blue").
    primary: Color(0xFF4285F4),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF0F9D58),
    warning: Color(0xFFF4B400),
    error: Color(0xFFDB4437),
    background: Color(0xFFFFFFFF),
    // Neutrals: Material 3 light defaults in the Google grey family.
    primaryContainer: Color(0xFFD3E3FD),
    secondary: Color(0xFF5F6368),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F3F4),
    textPrimary: Color(0xFF202124),
    textSecondary: Color(0xFF5F6368),
    textTertiary: Color(0xFF70757A),
    border: Color(0xFFDADCE0),
    // Light tints of the semantic colours, for badges and banners
    // paired with dark text.
    successBg: Color(0xFFE6F4EA),
    warningBg: Color(0xFFFEF7E0),
    errorBg: Color(0xFFFCE8E6),
    scrim: Color(0x52000000),
  );

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color scrim;

  /// Favourite = heart filled with the primary colour (requirements §6).
  /// Not a separate field, so no second brand hue can drift in.
  Color get favourite => primary;

  /// Keep action colour (requirements §3: left = Keep).
  Color get keep => success;

  /// Delete action colour (requirements §3: right = Delete, mark only).
  Color get delete => error;

  /// Maybe action colour (requirements §3: up = Maybe).
  Color get maybe => warning;

  @override
  AppPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? error,
    Color? errorBg,
    Color? scrim,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
