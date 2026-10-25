import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../services/detection/document_guard.dart';
import '../controller/review_controller.dart';
import '../widgets/review_bottom_bar.dart';
import '../widgets/review_grid_tile.dart';
import '../widgets/review_loading_skeleton.dart';

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
    await _handleOutcome(context, outcome);
  }

  /// Handles one delete outcome. Split from [_delete] so the
  /// document-guard override can re-run a delete and feed its
  /// outcome through the same handling (the override run can
  /// never return documentGuard again, so this terminates).
  Future<void> _handleOutcome(
    BuildContext context,
    ReviewDeleteOutcome? outcome,
  ) async {
    switch (outcome) {
      case ReviewDeleteOutcome.documentGuard:
        // Phase 4 document guard: warn first, then honour the
        // user's explicit choice — delete anyway (the deliberate
        // override, still via the native sheet) or keep the
        // document-like photos (they leave the grid, undecided).
        final bool deleteAnyway = await AppDialog.showConfirmation(
          context,
          title: AppStrings.tr(AppStrings.documentGuardTitle),
          message: AppStrings.tr(
            AppStrings.documentGuardMessage,
            <String, String>{
              'count': '${controller.documentGuardPending.length}',
            },
          ),
          confirmLabel: AppStrings.tr(AppStrings.documentGuardDeleteAnyway),
          cancelLabel: AppStrings.tr(AppStrings.documentGuardKeep),
          isDestructive: true,
        );
        if (!context.mounted) {
          return;
        }
        if (deleteAnyway) {
          final ReviewDeleteOutcome? next = await controller.deleteSelected(
            overrideDocumentGuard: true,
          );
          if (!context.mounted) {
            return;
          }
          await _handleOutcome(context, next);
        } else {
          await controller.keepDocumentGuarded();
          if (!context.mounted) {
            return;
          }
          if (controller.documentGuardKeptCount.value > 0) {
            AppSnackbar.show(
              context,
              message: AppStrings.tr(
                AppStrings.documentGuardKept,
                <String, String>{
                  'count': '${controller.documentGuardKeptCount.value}',
                },
              ),
            );
          }
        }
      case ReviewDeleteOutcome.trashed:
        final DateTime? until = controller.trashedUntil.value;
        Get.offAllNamed<dynamic>(
          AppRoutes.trash,
          arguments: until == null ? null : Formatters.formatDate(until),
        );
      case ReviewDeleteOutcome.denied:
        // Phase 3B mixed runs: a denied run may also have trashed
        // some photos and failed others. The pure-denied dialog
        // would hide both, so a mixed run gets a counted dialog
        // (and, when anything was trashed, a View trash choice —
        // the trashed photos are in Trash, not on the deck).
        if (controller.lastTrashedCount.value > 0 ||
            controller.lastFailedCount.value > 0) {
          final bool backToDeck = await AppDialog.showConfirmation(
            context,
            title: AppStrings.tr(AppStrings.deniedConfirmTitle),
            message: AppStrings.tr(
              AppStrings.deniedConfirmMixedMessage,
              <String, String>{
                'trashed': '${controller.lastTrashedCount.value}',
                'denied': '${controller.deniedIds.length}',
                'failed': '${controller.lastFailedCount.value}',
              },
            ),
            confirmLabel: AppStrings.tr(AppStrings.actionBackToDeck),
            cancelLabel: controller.lastTrashedCount.value > 0
                ? AppStrings.tr(AppStrings.actionViewTrash)
                : null,
          );
          if (!context.mounted) {
            return;
          }
          if (backToDeck) {
            controller.goToDeck();
          } else {
            final DateTime? until = controller.trashedUntil.value;
            Get.offAllNamed<dynamic>(
              AppRoutes.trash,
              arguments: until == null ? null : Formatters.formatDate(until),
            );
          }
        } else {
          await AppDialog.showConfirmation(
            context,
            title: AppStrings.tr(AppStrings.deniedConfirmTitle),
            message: AppStrings.tr(AppStrings.deniedConfirmMessage),
            confirmLabel: AppStrings.tr(AppStrings.actionOk),
          );
          if (context.mounted) {
            controller.goToDeck();
          }
        }
      case ReviewDeleteOutcome.failed:
        // Phase 3B: trashed + failed runs stay on screen with the
        // failed items and the error banner — but the trashed part
        // was previously invisible. Say it, with a count.
        if (controller.lastTrashedCount.value > 0) {
          AppSnackbar.show(
            context,
            message: AppStrings.tr(
              AppStrings.snackMovedToTrashMany,
              <String, String>{'count': '${controller.lastTrashedCount.value}'},
            ),
          );
        }
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
          // Phase 3A quick eye toggle: same global private-blur
          // setting as Settings. Icon shows the CURRENT state:
          // eyeSlash while blurred (tap to show), eye while shown.
          actions: <Widget>[
            IconButton(
              icon: Icon(
                controller.privateBlur.value ? AppIcons.eyeSlash : AppIcons.eye,
                size: context.sizes.iconMd,
              ),
              tooltip: AppStrings.tr(
                controller.privateBlur.value
                    ? AppStrings.blurShowPhotos
                    : AppStrings.blurHidePhotos,
              ),
              onPressed: controller.toggleBlur,
            ),
            IconButton(
              icon: Icon(AppIcons.trash, size: context.sizes.iconMd),
              tooltip: AppStrings.tr(AppStrings.screenTrash),
              onPressed: () => Get.toNamed<dynamic>(AppRoutes.trash),
            ),
          ],
          bottomBar: isEmpty
              ? null
              : ReviewBottomBar(
                  controller: controller,
                  onDelete: () => _delete(context),
                ),
          bottomNav: const AppBottomNav(currentIndex: 2),
          body: isEmpty
              ? (controller.isLoading.value
                    ? const ReviewLoadingSkeleton()
                    : EmptyView(
                        icon: AppIcons.review,
                        title: AppStrings.tr(AppStrings.reviewEmptyTitle),
                        message: AppStrings.tr(AppStrings.reviewEmptyMessage),
                        // ctaLabel: AppStrings.tr(AppStrings.actionBackToDeck),
                        // onCta: controller.goToDeck,
                      ))
              : Column(
                  children: <Widget>[
                    _Header(controller: controller),
                    if (controller.protectedExcludedCount.value > 0)
                      InfoBanner(
                        message: AppStrings.tr(
                          AppStrings.protectionReviewExcluded,
                          <String, String>{
                            'count':
                                '${controller.protectedExcludedCount.value}',
                          },
                        ),
                        onDismiss: () =>
                            controller.protectedExcludedCount.value = 0,
                      ),
                    // Phase 4 document guard: warn while the
                    // document-like items sit in the grid, before
                    // any delete is attempted. The counted dialog
                    // at delete time is the override itself.
                    if (documentLikeItems(controller.items).isNotEmpty)
                      InfoBanner(
                        message: AppStrings.tr(
                          AppStrings.documentGuardBanner,
                          <String, String>{
                            'count':
                                '${documentLikeItems(controller.items).length}',
                          },
                        ),
                      ),
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
                            blurred: controller.isBlurred(asset),
                            onReveal: () => controller.reveal(asset.id),
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
        context.sizes.sm,
        context.sizes.screenPadding,
        context.sizes.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${Formatters.formatCount(controller.items.length)} · '
                '${Formatters.formatBytes(controller.totalBytes)}',
                style: context.textStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sizes.sm,
                  vertical: context.sizes.xxs,
                ),
                decoration: BoxDecoration(
                  color: context.palette.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                  border: Border.all(
                    color: context.palette.error.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      AppIcons.delete,
                      size: context.sizes.md,
                      color: context.palette.error,
                    ),
                    SizedBox(width: context.sizes.xs),
                    Text(
                      AppStrings.tr(AppStrings.edgeDelete),
                      style: context.textStyles.labelSmall.copyWith(
                        color: context.palette.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
