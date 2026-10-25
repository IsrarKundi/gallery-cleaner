import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The ONLY snackbar path (AGENTS.md: no ad hoc snackbars in features).
/// The bar is ink in the light theme and light ink in dark, so the
/// action label uses the matching inverse colour (onPrimary):
/// Phase 3B fix — the old primary action was 1.75:1 on the dark
/// theme's light bar (and only 4.52:1 on the light bar); onPrimary
/// is 16.1:1 light and 13.36:1 dark.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: context.sizes.snackBarDuration,
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: context.palette.onPrimary,
                  onPressed: () {
                    onAction?.call();
                  },
                ),
        ),
      );
  }
}
