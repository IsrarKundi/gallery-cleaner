// One Maybe-pile row (Phase 2B): asset name/date/size, the
// snoozed-until date when snoozed, and the snooze actions.
// Layout only: snoozing/clearing lives in DecksController.
// Marking Maybe alone never snoozes — these buttons are the only
// way a snooze is set, deliberately, from this pile.

import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../model/maybe_pile_item.dart';

class MaybePileRow extends StatelessWidget {
  const MaybePileRow({
    super.key,
    required this.item,
    required this.onSnooze,
    required this.onClearSnooze,
  });

  final MaybePileItem item;
  final ValueChanged<int> onSnooze;
  final VoidCallback onClearSnooze;

  @override
  Widget build(BuildContext context) {
    final DateTime? snoozedUntil = item.snoozeUntil;
    final String meta =
        '${Formatters.formatDate(item.asset.createDate)} · '
        '${Formatters.formatBytes(item.asset.sizeBytes)}';
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.asset.title.isEmpty ? item.asset.id : item.asset.title,
            style: context.textStyles.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            meta,
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          if (snoozedUntil != null)
            Text(
              AppStrings.tr(
                AppStrings.retentionMaybeSnoozedUntil,
                <String, String>{'date': Formatters.formatDate(snoozedUntil)},
              ),
              style: context.textStyles.bodySmall,
            ),
          SizedBox(height: context.sizes.sm),
          Wrap(
            spacing: context.sizes.sm,
            runSpacing: context.sizes.sm,
            children: <Widget>[
              _SnoozeButton(
                label: AppStrings.tr(AppStrings.retentionSnooze7),
                onPressed: () => onSnooze(7),
              ),
              _SnoozeButton(
                label: AppStrings.tr(AppStrings.retentionSnooze14),
                onPressed: () => onSnooze(14),
              ),
              _SnoozeButton(
                label: AppStrings.tr(AppStrings.retentionSnooze30),
                onPressed: () => onSnooze(30),
              ),
              if (snoozedUntil != null)
                _SnoozeButton(
                  label: AppStrings.tr(AppStrings.retentionClearSnooze),
                  onPressed: onClearSnooze,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.sizes.buttonCompact,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
