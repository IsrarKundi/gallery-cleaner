import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../services/local/local_service.dart';

/// Bottom-anchored deck action bar (design.md §7): buttons for all
/// four actions — no action depends on gestures alone — plus Undo
/// (always visible, disabled only when the stack is empty) and Review
/// navigation. Buttons only MARK; confirmation lives on review —
/// except Clean-deck deletes, which confirm via the 2-second undo
/// window instead (ADR-013).
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
    this.isCleanScreen = true,
    this.onFavorite,
    this.onAddToAlbum,
    this.onShare,
    this.isFavourite = false,
  });

  final ValueChanged<DeckMark> onMark;
  final VoidCallback onUndo;
  final bool canUndo;
  final VoidCallback onReview;
  final bool isCleanScreen;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToAlbum;
  final VoidCallback? onShare;
  final bool isFavourite;

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
        child: isCleanScreen
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _CircleActionButton(
                        icon: AppIcons.undo,
                        tooltip: AppStrings.tr(AppStrings.actionUndo),
                        onPressed: canUndo ? onUndo : null,
                        iconColor: Colors.black,
                      ),
                      _CircleActionButton(
                        icon: isFavourite
                            ? AppIcons.favouriteActive
                            : AppIcons.favourite,
                        tooltip: AppStrings.tr(AppStrings.actionFavourite),
                        iconColor: isFavourite ? context.palette.error : null,
                        onPressed:
                            onFavorite ?? () => onMark(DeckMark.favourite),
                      ),
                      _CircleActionButton(
                        icon: AppIcons.addToAlbum,
                        iconWidget: AppSvgIcon(
                          asset: AppIcons.addToAlbumAsset,
                          size: context.sizes.iconMd,
                          color: context.palette.textPrimary,
                        ),
                        tooltip: AppStrings.tr(AppStrings.actionAddToAlbum),
                        onPressed: onAddToAlbum,
                      ),
                      _CircleActionButton(
                        icon: AppIcons.share,
                        tooltip: AppStrings.tr(AppStrings.actionShare),
                        onPressed: onShare,
                      ),
                    ],
                  ),
                  // Review and undo row commented out per request on clean screen:
                  // SizedBox(height: context.sizes.sm),
                  // Row(
                  //   children: <Widget>[
                  //     Expanded(
                  //       child: SizedBox(
                  //         height: context.sizes.hitArea,
                  //         child: OutlinedButton.icon(
                  //           onPressed: canUndo ? onUndo : null,
                  //           icon: Icon(AppIcons.undo, size: context.sizes.iconSm),
                  //           label: Text(AppStrings.tr(AppStrings.actionUndo)),
                  //         ),
                  //       ),
                  //     ),
                  //     SizedBox(width: context.sizes.sm),
                  //     Expanded(
                  //       child: SizedBox(
                  //         height: context.sizes.hitArea,
                  //         child: FilledButton.icon(
                  //           onPressed: onReview,
                  //           icon: Icon(AppIcons.review, size: context.sizes.iconSm),
                  //           label: Text(AppStrings.tr(AppStrings.actionReview)),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              )
            : Column(
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
                            icon: Icon(
                              AppIcons.undo,
                              size: context.sizes.iconSm,
                            ),
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
                            icon: Icon(
                              AppIcons.review,
                              size: context.sizes.iconSm,
                            ),
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

/// One semantic action button (Keep, Delete, Maybe, Favourite):
/// tint background with dark text plus icon + label.
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

/// Circular action button (Undo, Favorite, Add to Album, Share).
/// Uses 52dp hit area matching [AppSizes.buttonPrimary] and
/// dark circle styling.
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.iconWidget,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;

  /// Renders instead of [icon] when set (custom SVG actions).
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: context.sizes.buttonPrimary,
        height: context.sizes.buttonPrimary,
        child: Material(
          color: context.palette.surfaceVariant,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Opacity(
                opacity: isEnabled ? 1.0 : context.sizes.disabledOpacity,
                child:
                    iconWidget ??
                    Icon(
                      icon,
                      size: context.sizes.iconMd,
                      color: iconColor ?? context.palette.textPrimary,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
