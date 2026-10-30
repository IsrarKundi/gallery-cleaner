import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/review_controller.dart';

/// Bottom-anchored actions.
///
/// Without a selection:
/// - Keep
/// - Delete All
///
/// With a selection:
/// - Keep X
/// - Delete X
///
/// Keep occupies 40% and Delete occupies 60% of the
/// available button width, excluding the gap.
///
/// Loading is per action (ADR-025): a running action spins
/// ONLY its own button (design.md §5); the other button is
/// disabled — not spinning, not tappable — for the duration.
class ReviewBottomBar extends StatelessWidget {
  const ReviewBottomBar({
    super.key,
    required this.controller,
    required this.onDelete,
  });

  final ReviewController controller;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border(
          top: BorderSide(color: context.palette.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        context.sizes.screenPadding,
        context.sizes.md,
        context.sizes.screenPadding,
        context.sizes.sm,
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final bool hasSelection = controller.hasSelection;
          final int selectedCount = controller.selectedItems.length;
          final bool isDeleting = controller.isDeleting.value;
          final bool isKeeping = controller.isKeeping.value;

          return Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: SecondaryButton(
                  label: hasSelection
                      ? AppStrings.tr(
                          AppStrings.reviewKeepCount,
                          <String, String>{'count': '$selectedCount'},
                        )
                      : 'Keep',
                  icon: AppIcons.keep,
                  // While Delete runs, Keep is disabled outright;
                  // while Keep itself runs, the button's own
                  // isLoading disables it (ADR-025).
                  onPressed: isDeleting
                      ? null
                      : hasSelection
                      ? controller.keepSelected
                      : controller.keepAll,
                  isLoading: isKeeping,
                ),
              ),
              SizedBox(width: context.sizes.sm),
              Expanded(
                flex: 6,
                child: PrimaryButton(
                  label: hasSelection
                      ? AppStrings.tr(
                          AppStrings.reviewDeleteCount,
                          <String, String>{'count': '$selectedCount'},
                        )
                      : 'Delete All',
                  icon: AppIcons.delete,
                  onPressed: isKeeping ? null : onDelete,
                  isLoading: isDeleting,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
