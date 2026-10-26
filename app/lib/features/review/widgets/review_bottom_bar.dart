import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/review_controller.dart';

/// Bottom-anchored actions (design.md §5). Without a selection:
/// "Keep all" (secondary) and "Delete N photos" (the ONLY filled
/// Delete button in the app). With a selection, both act on the
/// selection only and their labels carry its count: "Keep X
/// photos" and "Delete X photos". The bar renders only while the
/// set is non-empty.
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
        // The labels observe the selection so they flip between
        // the whole-set and the selection counts without the
        // parent having to rebuild the bar.
        child: Obx(() {
          final bool hasSelection = controller.hasSelection;
          final int selectedCount = controller.selectedItems.length;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SecondaryButton(
                label: hasSelection
                    ? AppStrings.tr(
                        AppStrings.reviewKeepCount,
                        <String, String>{'count': '$selectedCount'},
                      )
                    : AppStrings.tr(AppStrings.actionKeepAll),
                icon: AppIcons.keep,
                onPressed: hasSelection
                    ? controller.keepSelected
                    : controller.keepAll,
                isLoading: controller.isDeleting.value,
              ),
              SizedBox(height: context.sizes.sm),
              PrimaryButton(
                label: AppStrings.tr(AppStrings.reviewDeleteCount, <
                  String,
                  String
                >{
                  'count':
                      '${hasSelection ? selectedCount : controller.items.length}',
                }),
                icon: AppIcons.delete,
                onPressed: onDelete,
                isLoading: controller.isDeleting.value,
              ),
            ],
          );
        }),
      ),
    );
  }
}
