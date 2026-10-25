import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';

/// First-run interactive tutorial overlay (requirements §3, mandatory
/// because the mapping is the opposite of the usual convention).
///
/// Explains all four directions with arrows + edge labels and a
/// dismiss action. It is skippable, never permanently blocks the deck
/// (it sits above the deck and dismisses on one tap), and never
/// reappears once dismissed — the controller records the flag.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
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
                  text: AppStrings.tr(AppStrings.tutorialKeep),
                ),
                SizedBox(height: context.sizes.sm),
                _TutorialRow(
                  icon: AppIcons.delete,
                  text: AppStrings.tr(AppStrings.tutorialDelete),
                ),
                SizedBox(height: context.sizes.sm),
                _TutorialRow(
                  icon: AppIcons.maybe,
                  text: AppStrings.tr(AppStrings.tutorialMaybe),
                ),
                SizedBox(height: context.sizes.sm),
                _TutorialRow(
                  icon: AppIcons.favourite,
                  text: AppStrings.tr(AppStrings.tutorialFavourite),
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
