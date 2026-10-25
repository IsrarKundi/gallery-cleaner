import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The ONLY dialog path (AGENTS.md: no ad hoc dialogs in features).
/// Returns true when the confirm action is tapped, false otherwise
/// (cancel, dismiss, or back). A destructive confirm renders in the
/// error colour; destructive actions are never text buttons
/// (design.md §5).
class AppDialog {
  AppDialog._();

  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            if (cancelLabel != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: dialogContext.palette.error,
                      foregroundColor: dialogContext.palette.onPrimary,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
