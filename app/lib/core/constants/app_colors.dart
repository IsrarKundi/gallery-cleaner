import 'package:flutter/material.dart';

/// The single source of colour truth for Klara (design.md §2, §10).
///
/// LIGHT set (Phase 1) + DARK set (Phase 3A). Surfaces in dark are
/// the #121212 family, never pure black; elevation in dark is
/// lightness (higher surfaces slightly lighter), never shadow.
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
///
/// DARK contrast, measured against background #121212 (same 4.5:1 rule):
/// - textPrimary #E8EAED: 15.54:1, textSecondary #9AA0A6: 7.09:1,
///   textTertiary #80868B: 5.09:1. All three pass 4.5:1 on #121212.
///   (Note #80868B fails on white but passes on #121212 — the dark
///   tertiary is safe here precisely because the background is dark.)
/// - Dark brand colours are LIGHTENED, not darkened, versions of the
///   Google family, so they stay readable on dark surfaces:
///   primary #8AB4F8 (Google dark-theme blue) is 8.89:1 on #121212,
///   success #81C995 is 9.56:1, warning #FDD663 is 13.36:1,
///   error #F28B82 is 7.84:1. All pass 4.5:1 as fills/badges on dark.
/// - Because the dark brand fills are light, their labels flip to
///   dark ink: #202124 on primary is 7.64:1, on success 8.22:1, on
///   warning 11.48:1, on error 6.74:1. That is why dark [onPrimary]
///   is #202124, not white — white labels on the light dark-theme
///   fills would fail. Buttons use the theme's onPrimary, so this
///   flip is automatic.
/// - Dark tints (successBg / warningBg / errorBg) pair with LIGHT
///   text: #E8EAED on successBg #1C3325 is 11.24:1, on warningBg
///   #332A0A is 11.80:1, on errorBg #3C1E1A is 12.51:1. Dark tints
///   are therefore dark surfaces, not light ones — a light tint
///   with dark text would be a second, inverted scheme.
/// - Tonal elevation: background #121212 < surface #1E1E1E <
///   surfaceVariant #2C2C2C. #E8EAED text stays 13.83:1 on surface
///   and 11.59:1 on surfaceVariant, so elevation never costs
///   readability. Border #3C4043 is a hairline only, never text.
/// - Favourite in dark = heart filled with the dark primary #8AB4F8
///   (via [favourite] = [primary]), so no new hue appears in dark.
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
    required this.onScrim,
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
    // White label on the translucent scrim, both themes: the scrim
    // is dark in both, so white always contrasts on it.
    onScrim: Color(0xFFFFFFFF),
  );

  /// Dark palette (Phase 3A). Lightened Google-family brand colours
  /// (see the contrast reasoning in the file doc above); #121212
  /// family surfaces with tonal elevation; dark [onPrimary] because
  /// the dark brand fills are light. Pinned by the palette test.
  static const AppPalette dark = AppPalette(
    primary: Color(0xFF8AB4F8),
    onPrimary: Color(0xFF202124),
    success: Color(0xFF81C995),
    warning: Color(0xFFFDD663),
    error: Color(0xFFF28B82),
    background: Color(0xFF121212),
    // Tonal elevation: lighter as the surface rises, never shadow.
    primaryContainer: Color(0xFF1E3A5F),
    secondary: Color(0xFF9AA0A6),
    surface: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFF9AA0A6),
    textTertiary: Color(0xFF80868B),
    border: Color(0xFF3C4043),
    // Dark tints, paired with light text (see file doc).
    successBg: Color(0xFF1C3325),
    warningBg: Color(0xFF332A0A),
    errorBg: Color(0xFF3C1E1A),
    scrim: Color(0x99000000),
    onScrim: Color(0xFFFFFFFF),
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
  final Color onScrim;

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
    Color? onScrim,
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
      onScrim: onScrim ?? this.onScrim,
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
      onScrim: Color.lerp(onScrim, other.onScrim, t)!,
    );
  }
}
