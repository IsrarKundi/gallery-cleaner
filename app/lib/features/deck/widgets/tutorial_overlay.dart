import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/local/local_service.dart';
import '../../settings/controller/settings_controller.dart';

/// First-run interactive tutorial overlay (requirements §3 amendment 27 Oct 2026).
///
/// Explains the two horizontal swipe directions (Keep and Delete) with edge
/// actions and a dismiss action. Up/down swiping is disabled.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.onDismiss,
    this.swipeDirections,
  });

  final VoidCallback onDismiss;
  final SwipeDirections? swipeDirections;

  @override
  Widget build(BuildContext context) {
    final SwipeDirections directions =
        swipeDirections ??
        (Get.isRegistered<SettingsController>()
            ? Get.find<SettingsController>().swipeDirections
            : SwipeDirections.rightKeepLeftDelete);
    final bool rightIsKeep = directions == SwipeDirections.rightKeepLeftDelete;

    return Container(
      color: context.palette.scrim,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.all(context.sizes.screenPadding),
            padding: EdgeInsets.all(context.sizes.lg),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(context.sizes.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.tr(AppStrings.tutorialTitle),
                  style: context.textStyles.headlineSmall,
                ),
                SizedBox(height: context.sizes.lg),
                _TutorialRow(
                  icon: AppIcons.keep,
                  text: AppStrings.tr(
                    rightIsKeep
                        ? AppStrings.tutorialKeepRight
                        : AppStrings.tutorialKeepLeft,
                  ),
                ),
                SizedBox(height: context.sizes.sm),
                _TutorialRow(
                  icon: AppIcons.delete,
                  text: AppStrings.tr(
                    rightIsKeep
                        ? AppStrings.tutorialDeleteLeft
                        : AppStrings.tutorialDeleteRight,
                  ),
                ),
                SizedBox(height: context.sizes.lg),
                Text(
                  AppStrings.tr(AppStrings.tutorialSwipeNote),
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                SizedBox(height: context.sizes.lg),
                PrimaryButton(
                  label: AppStrings.tr(AppStrings.tutorialDone),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialRow extends StatelessWidget {
  const _TutorialRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: context.sizes.iconMd),
        SizedBox(width: context.sizes.sm),
        Expanded(child: Text(text, style: context.textStyles.bodyMedium)),
      ],
    );
  }
}
