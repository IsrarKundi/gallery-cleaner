import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/secondary_button.dart';

/// Trash bottom bar (extracted from [TrashView] in Phase 3B to
/// hold that file's line budget): Restore-all + Empty-trash
/// actions. Dumb widget — the view passes [isBusy] from the
/// controller's reactive state inside its Obx.
class TrashBottomBar extends StatelessWidget {
  const TrashBottomBar({
    super.key,
    required this.isBusy,
    required this.onRestoreAll,
    required this.onEmptyTrash,
  });

  final bool isBusy;
  final VoidCallback onRestoreAll;
  final VoidCallback onEmptyTrash;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.palette.background,
      padding: EdgeInsets.fromLTRB(
        context.sizes.screenPadding,
        context.sizes.sm,
        context.sizes.screenPadding,
        context.sizes.sm,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SecondaryButton(
              label: AppStrings.tr(AppStrings.trashRestoreAll),
              icon: AppIcons.undo,
              onPressed: onRestoreAll,
              isLoading: isBusy,
            ),
            SizedBox(height: context.sizes.sm),
            // Phase 3B: the button itself is 48dp (see
            // SecondaryButton for why a 40dp button inside a 48dp
            // box does not count as a 48dp tap target).
            SizedBox(
              height: context.sizes.hitArea,
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.error,
                ),
                onPressed: isBusy ? null : onEmptyTrash,
                icon: Icon(AppIcons.trash, size: context.sizes.iconSm),
                label: Text(AppStrings.tr(AppStrings.trashEmpty)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
