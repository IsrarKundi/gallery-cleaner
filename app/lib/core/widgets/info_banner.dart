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
    return Container(
      color: context.palette.warningBg,
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message, style: context.textStyles.bodyMedium)),
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
