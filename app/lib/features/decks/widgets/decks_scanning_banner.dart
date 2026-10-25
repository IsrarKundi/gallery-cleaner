import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../controller/decks_controller.dart';

/// Scanning banner card displayed during library scanning on DecksView.
class DecksScanningBanner extends StatelessWidget {
  const DecksScanningBanner({super.key, required this.controller});

  final DecksController controller;

  @override
  Widget build(BuildContext context) {
    final int scanned = controller.scanned.value;
    final int? total = controller.estimatedTotal.value;
    final double? progress = controller.progress;
    final int percent = progress != null ? (progress * 100).toInt() : 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sizes.screenPadding),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sizes.md,
          vertical: context.sizes.sm,
        ),
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(context.sizes.radiusMd),
          border: Border.all(color: context.palette.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    total != null && total > 0
                        ? 'Scanning library: ${Formatters.formatCount(scanned)} of ${Formatters.formatCount(total)} photos…'
                        : 'Scanning library: ${Formatters.formatCount(scanned)} photos…',
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress != null) ...<Widget>[
                  SizedBox(width: context.sizes.xs),
                  Text(
                    '$percent%',
                    style: context.textStyles.labelSmall.copyWith(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: context.sizes.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(context.sizes.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: context.palette.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
