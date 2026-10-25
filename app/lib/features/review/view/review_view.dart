import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/review_controller.dart';
import '../widgets/review_grid_tile.dart';

/// Review screen (requirements §4): editable grid of delete-marked
/// photos with counts and total size. Layout + Obx only: marks,
/// trash outcomes and session writes live in [ReviewController].
///
/// Navigation contract (see the controller): every exit resets the
/// stack with [Get.offAllNamed] — the AppBar back control, the system
/// back gesture (via [PopScope]) and the empty-state CTA all go to
/// the deck, never [Get.back] into a stale deck controller. A
/// successful delete goes to Trash carrying the recoverable-until
/// date as route arguments, so the Trash screen can show the
/// "Moved to Trash" snackbar on arrival.
class ReviewView extends GetView<ReviewController> {
  const ReviewView({super.key});

  Future<void> _delete(BuildContext context) async {
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    if (!context.mounted) {
      return;
    }
    switch (outcome) {
      case ReviewDeleteOutcome.trashed:
        final DateTime? until = controller.trashedUntil.value;
        Get.offAllNamed<dynamic>(
          AppRoutes.trash,
          arguments: until == null ? null : Formatters.formatDate(until),
        );
      case ReviewDeleteOutcome.denied:
        await AppDialog.showConfirmation(
          context,
          title: AppStrings.tr(AppStrings.deniedConfirmTitle),
          message: AppStrings.tr(AppStrings.deniedConfirmMessage),
          confirmLabel: AppStrings.tr(AppStrings.actionOk),
        );
        controller.goToDeck();
      case ReviewDeleteOutcome.failed:
      case ReviewDeleteOutcome.serviceError:
      case null:
        // The error state renders inline with a retry action.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.goToDeck();
        }
      },
      child: Obx(() {
        final bool isEmpty = controller.items.isEmpty;
        return AppScaffold(
          title: AppStrings.tr(AppStrings.screenReview),
          leading: IconButton(
            icon: Icon(AppIcons.back, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
            onPressed: controller.goToDeck,
          ),
          bottomBar: isEmpty
              ? null
              : _BottomBar(
                  controller: controller,
                  onDelete: () => _delete(context),
                ),
          body: isEmpty
              ? EmptyView(
                  icon: AppIcons.review,
                  title: AppStrings.tr(AppStrings.reviewEmptyTitle),
                  message: AppStrings.tr(AppStrings.reviewEmptyMessage),
                  ctaLabel: AppStrings.tr(AppStrings.actionBackToDeck),
                  onCta: controller.goToDeck,
                )
              : Column(
                  children: <Widget>[
                    _Header(controller: controller),
                    if (controller.errorKey.value.isNotEmpty)
                      ErrorBanner(
                        message: AppStrings.tr(controller.errorKey.value),
                        onRetry: () => _delete(context),
                        onDismiss: () => controller.errorKey.value = '',
                      ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.all(context.sizes.screenPadding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: context.sizes.sm,
                          mainAxisSpacing: context.sizes.sm,
                        ),
                        itemCount: controller.items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final asset = controller.items[index];
                          return ReviewGridTile(
                            asset: asset,
                            thumbnail: controller.thumbnails[asset.id],
                            thumbnailFailed: controller.failedThumbnails
                                .contains(asset.id),
                            onTap: () => controller.unmark(asset),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      }),
    );
  }
}

/// Header: live count + total size of the marked set, and the tap-to-
/// unmark hint. Trashed MB is never described as freed here.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ReviewController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sizes.screenPadding,
        context.sizes.screenPadding,
        context.sizes.screenPadding,
        context.sizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${Formatters.formatCount(controller.items.length)} · '
            '${Formatters.formatBytes(controller.totalBytes)}',
            style: context.textStyles.titleMedium,
          ),
          SizedBox(height: context.sizes.xs),
          Text(
            AppStrings.tr(AppStrings.reviewUnmarkHint),
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-anchored actions: "Keep all" (secondary) and "Delete N
/// photos" (the ONLY filled Delete button in the app, design.md §5).
/// The bar renders only while the set is non-empty, so the 0-selected
/// state is the empty state above — Delete is never offered at 0.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onDelete});

  final ReviewController controller;
  final VoidCallback onDelete;

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
