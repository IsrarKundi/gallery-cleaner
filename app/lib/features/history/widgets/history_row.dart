import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/local/local_service.dart';

/// One history row: the run's date, photo count, MB trashed and MB
/// freed. Trashed MB is never presented as freed: trash events show
/// freed 0, and only empty-trash events show a non-zero freed figure
/// (requirements §4).
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.record});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(context.sizes.sm),
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant,
          borderRadius: BorderRadius.circular(context.sizes.radiusMd),
        ),
        child: Icon(
          AppIcons.history,
          size: context.sizes.iconMd,
          color: context.palette.textSecondary,
        ),
      ),
      title: Text(Formatters.formatDate(record.date)),
      subtitle: Text(
        AppStrings.tr(AppStrings.historyRowMeta, <String, String>{
          'count': Formatters.formatCount(record.count),
          'trashed': Formatters.formatMb(record.mbTrashed),
          'freed': Formatters.formatMb(record.mbFreed),
        }),
      ),
    );
  }
}
