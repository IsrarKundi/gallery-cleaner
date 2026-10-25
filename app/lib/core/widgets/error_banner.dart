import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';

/// Inline error strip for action failures on screens that keep their
/// content visible (review delete, trash restore/empty). Unlike
/// [ErrorView] it never replaces the screen: the message sits above
/// the content with an optional retry action and a dismiss control.
/// The message is a resolved [AppStrings] key, never exception text.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRetry = this.onRetry;
    final VoidCallback? onDismiss = this.onDismiss;
    return Container(
      color: context.palette.errorBg,
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            AppIcons.error,
            size: context.sizes.iconSm,
            color: context.palette.error,
          ),
          SizedBox(width: context.sizes.sm),
          Expanded(child: Text(message, style: context.textStyles.bodyMedium)),
          if (onRetry != null) ...<Widget>[
            SizedBox(width: context.sizes.sm),
            TextButton(
              onPressed: onRetry,
              child: Text(AppStrings.tr(AppStrings.errorRetry)),
            ),
          ],
          if (onDismiss != null)
            IconButton(
              icon: Icon(AppIcons.close, size: context.sizes.iconSm),
              tooltip: AppStrings.tr(AppStrings.actionClose),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
