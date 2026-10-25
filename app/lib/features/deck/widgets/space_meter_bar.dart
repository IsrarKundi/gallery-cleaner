import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../model/space_meter.dart';

/// Live three-state space meter (design.md §7, the #1 differentiator):
/// Marked "to be freed", In Trash "recoverable until [date]", Freed
/// only after emptying or expiry. Never hidden in Stats, never
/// reporting trashed MB as freed (requirements §4).
class SpaceMeterBar extends StatelessWidget {
  const SpaceMeterBar({super.key, required this.totals});

  final SpaceMeterTotals totals;

  @override
  Widget build(BuildContext context) {
    final DateTime? recoverableUntil = totals.recoverableUntil;
    final String inTrashLabel = recoverableUntil == null
        ? AppStrings.tr(AppStrings.meterInTrashEmpty)
        : AppStrings.tr(AppStrings.meterInTrash, <String, String>{
            'date': Formatters.formatDate(recoverableUntil),
          });
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _MeterCell(
              label: AppStrings.tr(AppStrings.meterToBeFreed),
              value: Formatters.formatBytes(totals.markedBytes),
            ),
          ),
          Expanded(
            child: _MeterCell(
              label: inTrashLabel,
              value: Formatters.formatBytes(totals.inTrashBytes),
            ),
          ),
          Expanded(
            child: _MeterCell(
              label: AppStrings.tr(AppStrings.meterFreed),
              value: Formatters.formatBytes(totals.freedBytes),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterCell extends StatelessWidget {
  const _MeterCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: context.textStyles.titleMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.sizes.xs),
        Text(
          label,
          style: context.textStyles.bodySmall.copyWith(
            color: context.palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
