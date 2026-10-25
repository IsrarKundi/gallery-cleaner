import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/review_controller.dart';

/// Bottom-anchored actions: "Keep all" (secondary) and "Delete N
/// photos" (the ONLY filled Delete button in the app, design.md §5).
/// The bar renders only while the set is non-empty.
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SecondaryButton(
              label: AppStrings.tr(AppStrings.actionKeepAll),
              icon: AppIcons.keep,
              onPressed: controller.keepAll,
              isLoading: controller.isDeleting.value,
            ),
            SizedBox(height: context.sizes.sm),
            PrimaryButton(
              label: AppStrings.tr(
                AppStrings.reviewDeleteCount,
                <String, String>{'count': '${controller.items.length}'},
              ),
              icon: AppIcons.delete,
              onPressed: onDelete,
              isLoading: controller.isDeleting.value,
            ),
          ],
        ),
      ),
    );
  }
}
