import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The single source of text styles for Klara (design.md §3, §10).
///
/// Full Material 3 scale, Inter bundled as an asset (google_fonts is
/// forbidden). Every style defaults to [AppPalette.textPrimary]; callers
/// recolour with `copyWith` when a secondary tone is needed.
///
/// Never below 12sp for functional text; 11sp ([labelSmall]) is fine
/// print only.
class AppTextStyles {
  const AppTextStyles(this.palette);

  final AppPalette palette;

  static const String fontFamily = 'Inter';

  /// Hero number, e.g. the space that can be freed. 36/44, weight 700.
  TextStyle get displaySmall => _style(36, 44, FontWeight.w700);

  /// Large hero alternative. 32/40, weight 700.
  TextStyle get headlineLarge => _style(32, 40, FontWeight.w700);

  /// Screen titles. 24/32, weight 700.
  TextStyle get headlineSmall => _style(24, 32, FontWeight.w700);

  /// Screen titles (alternative), card titles. 22/28, weight 600.
  TextStyle get titleLarge => _style(22, 28, FontWeight.w600);

  /// List-row titles. 16/24, weight 600.
  TextStyle get titleMedium => _style(16, 24, FontWeight.w600);

  /// Primary reading text. 16/24, weight 400.
  TextStyle get bodyLarge => _style(16, 24, FontWeight.w400);

  /// Default body, list subtitles. 14/20, weight 400.
  TextStyle get bodyMedium => _style(14, 20, FontWeight.w400);

  /// Metadata, e.g. date and size lines. 12/16, weight 400.
  TextStyle get bodySmall => _style(12, 16, FontWeight.w400);

  /// Buttons. 14/20, weight 600.
  TextStyle get labelLarge => _style(14, 20, FontWeight.w600);

  /// Chips, badges, metadata alternative. 12/16, weight 600.
  TextStyle get labelMedium => _style(12, 16, FontWeight.w600);

  /// Fine print ONLY. 11/16, weight 600.
  TextStyle get labelSmall => _style(11, 16, FontWeight.w600);

  TextStyle _style(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      color: palette.textPrimary,
    );
  }
}
