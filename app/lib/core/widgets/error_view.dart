import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// Error state (AGENTS.md: errors reach the UI as state). Shows an
/// error icon, the caller-supplied message (a resolved [AppStrings] key,
/// never exception text) and a retry button when [onRetry] is given.
class ErrorView extends StatelessWidget {
  ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    String? retryLabel,
  }) : retryLabel = retryLabel ?? AppStrings.tr(AppStrings.errorRetry);

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.sizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: context.sizes.iconLg,
              color: context.palette.error,
            ),
            SizedBox(height: context.sizes.md),
            Text(
              message,
              style: context.textStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              SizedBox(height: context.sizes.lg),
              PrimaryButton(label: retryLabel, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
