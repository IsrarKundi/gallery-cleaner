import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Shortcuts for the token files, so views never import tokens directly
/// for values they only read (design.md §10).
extension ThemeExt on BuildContext {
  // Phase 3.4: one-entry identity cache. The old getter built a
  // fresh AppTextStyles per access (per widget per build); the
  // palette instance is stable while the theme is unchanged
  // (AppPalette.light/dark are const singletons), so identity is
  // a correct cache key, and a theme switch yields a new
  // palette and rebuilds the set.
  static AppPalette? _lastPalette;
  static AppTextStyles? _lastStyles;

  /// The active [AppPalette] (light or dark, Phase 3A).
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  /// The Material 3 type scale, coloured from the active palette.
  AppTextStyles get textStyles {
    final AppPalette current = palette;
    if (!identical(current, _lastPalette)) {
      _lastPalette = current;
      _lastStyles = AppTextStyles(current);
    }
    return _lastStyles!;
  }

  /// The 8dp spacing, radius, button and motion scale.
  AppSizes get sizes => const AppSizes();
}
