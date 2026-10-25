// One hub row: deck icon + name + count/size subtitle (or a
// "still scanning" subtitle while its count is not final yet).
// Layout only; navigation lives in the controller.

import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/detection/smart_decks.dart';
import '../model/smart_deck_meta.dart';

class DeckRow extends StatelessWidget {
  const DeckRow({
    super.key,
    required this.deckId,
    required this.count,
    required this.totalBytes,
    required this.ready,
    required this.onTap,
  });

  final SmartDeckId deckId;
  final int count;
  final int totalBytes;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String subtitle = !ready
        ? AppStrings.tr(AppStrings.decksRowScanning)
        : AppStrings.tr(AppStrings.decksRowCount, <String, String>{
            'count': Formatters.formatCount(count),
            'size': Formatters.formatBytes(totalBytes),
          });
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sizes.screenPadding,
          vertical: context.sizes.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              smartDeckIcon(deckId),
              size: context.sizes.iconMd,
              color: context.palette.primary,
            ),
            SizedBox(width: context.sizes.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.tr(smartDeckTitleKey(deckId)),
                    style: context.textStyles.titleMedium,
                  ),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
