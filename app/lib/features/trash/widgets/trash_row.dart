import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/trash/trash_entry.dart';

/// One Trash row: metadata only (size, trashed date, recoverable
/// until). No thumbnail is attempted — trashed assets are hidden
/// from MediaStore queries, so thumbnail loads would fail. The
/// leading art is a placeholder glyph, never a fake or stale image.
class TrashRow extends StatelessWidget {
  const TrashRow({super.key, required this.entry, required this.onRestore});

  final TrashEntry entry;
  final VoidCallback onRestore;

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
          AppIcons.trash,
          size: context.sizes.iconMd,
          color: context.palette.textSecondary,
        ),
      ),
      title: Text(Formatters.formatBytes(entry.sizeBytes)),
      subtitle: Text(
        AppStrings.tr(AppStrings.trashRowMeta, <String, String>{
          'trashed': Formatters.formatDate(entry.trashedAt),
          'until': Formatters.formatDate(entry.recoverableUntil),
        }),
      ),
      trailing: TextButton(
        onPressed: onRestore,
        child: Text(AppStrings.tr(AppStrings.actionRestore)),
      ),
    );
  }
}
