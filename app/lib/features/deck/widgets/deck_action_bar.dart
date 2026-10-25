import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/local/local_service.dart';

/// Bottom-anchored deck action bar (design.md §7): buttons for all
/// four actions — no action depends on gestures alone — plus Undo
/// (always visible, disabled only when the stack is empty) and Review
/// navigation. Buttons only MARK; confirmation lives on review.
///
/// Callback-based (not controller-typed) so the smart-deck screen
/// reuses this exact bar with its own controller: same buttons, same
/// locked mapping, no duplicated action UI.
class DeckActionBar extends StatelessWidget {
  const DeckActionBar({
    super.key,
    required this.onMark,
    required this.onUndo,
    required this.canUndo,
    required this.onReview,
  });

  final ValueChanged<DeckMark> onMark;
  final VoidCallback onUndo;
  final bool canUndo;
  final VoidCallback onReview;

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
            Row(
              children: <Widget>[
                Expanded(
                  child: _ActionButton(
                    icon: AppIcons.keep,
                    label: AppStrings.tr(AppStrings.actionKeep),
                    background: context.palette.successBg,
                    onPressed: () => onMark(DeckMark.keep),
                  ),
                ),
                SizedBox(width: context.sizes.sm),
                Expanded(
                  child: _ActionButton(
                    icon: AppIcons.delete,
                    label: AppStrings.tr(AppStrings.actionDelete),
                    background: context.palette.errorBg,
                    onPressed: () => onMark(DeckMark.delete),
                  ),
                ),
                SizedBox(width: context.sizes.sm),
                Expanded(
                  child: _ActionButton(
                    icon: AppIcons.maybe,
                    label: AppStrings.tr(AppStrings.actionMaybe),
                    background: context.palette.warningBg,
                    onPressed: () => onMark(DeckMark.maybe),
                  ),
                ),
                SizedBox(width: context.sizes.sm),
                Expanded(
                  child: _ActionButton(
                    icon: AppIcons.favourite,
                    label: AppStrings.tr(AppStrings.actionFavourite),
                    background: context.palette.primaryContainer,
                    onPressed: () => onMark(DeckMark.favourite),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sizes.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: context.sizes.hitArea,
                    child: OutlinedButton.icon(
                      onPressed: canUndo ? onUndo : null,
                      icon: Icon(AppIcons.undo, size: context.sizes.iconSm),
                      label: Text(AppStrings.tr(AppStrings.actionUndo)),
                    ),
                  ),
                ),
                SizedBox(width: context.sizes.sm),
                Expanded(
                  child: SizedBox(
                    height: context.sizes.hitArea,
                    child: FilledButton.icon(
                      onPressed: onReview,
                      icon: Icon(AppIcons.review, size: context.sizes.iconSm),
                      label: Text(AppStrings.tr(AppStrings.actionReview)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One semantic action button: tint background with dark text plus
/// icon + label, so meaning is never carried by colour alone
/// (design.md §9). 48dp+ hit area via the 52dp button height.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.sizes.buttonPrimary,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(context.sizes.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.sizes.radiusMd),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: context.sizes.iconSm),
              SizedBox(height: context.sizes.xs),
              Text(label, style: context.textStyles.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
