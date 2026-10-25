// Inline information strip (Phase 3A).
//
// For non-error explanations that must stay visible above content:
// a blocked delete (favourites protection), protected photos kept
// out of a delete, and similar. It deliberately does NOT use the
// error styling ([ErrorBanner]): these are not failures, and
// painting them red would teach users to ignore real errors. The
// warning tint + text + optional dismiss is the neutral middle.

import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onDismiss = this.onDismiss;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.xs,
      ),
      child: Container(
        padding: EdgeInsets.all(context.sizes.md),
        decoration: BoxDecoration(
          color: context.palette.warningBg,
          borderRadius: BorderRadius.circular(context.sizes.radiusMd),
          border: Border.all(
            color: context.palette.warning.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(context.sizes.xs),
              decoration: BoxDecoration(
                color: context.palette.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.error,
                size: context.sizes.iconSm,
                color: context.palette.warning,
              ),
            ),
            SizedBox(width: context.sizes.sm),
            Expanded(
              child: Text(
                message,
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            if (onDismiss != null) ...<Widget>[
              SizedBox(width: context.sizes.xs),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(AppIcons.close, size: context.sizes.iconSm),
                tooltip: AppStrings.tr(AppStrings.actionClose),
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
