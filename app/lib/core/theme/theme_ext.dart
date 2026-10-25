import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Shortcuts for the token files, so views never import tokens directly
/// for values they only read (design.md §10).
extension ThemeExt on BuildContext {
  /// The active [AppPalette] (light or dark, Phase 3A).
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  /// The Material 3 type scale, coloured from the active palette.
  AppTextStyles get textStyles => AppTextStyles(palette);

  /// The 8dp spacing, radius, button and motion scale.
  AppSizes get sizes => const AppSizes();
}
