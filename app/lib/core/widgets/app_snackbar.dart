import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The ONLY snackbar path (AGENTS.md: no ad hoc snackbars in features).
/// Dark bar with white text; an optional action label renders in the
/// primary colour, which passes 4.5:1 on the dark bar.
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
                  textColor: context.palette.primary,
                  onPressed: () {
                    onAction?.call();
                  },
                ),
        ),
      );
  }
}
