import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/info_banner.dart';
import '../controller/review_controller.dart';
import '../widgets/review_bottom_bar.dart';
import '../widgets/review_grid_tile.dart';
import '../widgets/review_loading_skeleton.dart';

/// Review screen (requirements §4): editable grid of delete-marked
/// photos with counts and total size. Layout + Obx only: marks,
/// trash outcomes and session writes live in [ReviewController].
///
/// Navigation contract (see the controller): exits return to the
/// retained shell when one is alive — the AppBar back control, the
/// system back gesture (via [PopScope]) and the bottom nav all pop
/// back to the shell's tabs instead of rebuilding them; standalone
/// Review falls back to a stack reset. A successful whole-set
/// permanent delete opens the finish screen (Stage 5, ADR-020;
/// the delete itself is ADR-014's, unchanged); leaving Review
/// pops back to the shell, never a rebuild.
///
/// Selection (owner decision 26 Oct 2026): photos are always
/// shown revealed. Outside selection mode a tile tap unmarks the
/// photo; in selection mode (long-press or the header's Select
/// button) taps toggle selection, and the bottom bar acts on the
/// selection (Keep X / Delete X) instead of the whole set. The
/// back control first cancels an active selection, and only then
/// leaves the screen.
///
/// Leave-guard (fix plan Stage 1): leaving via back or the
/// bottom nav while photos still wait in the grid first shows a
/// confirmation ("Open Review" / "Save and Exit"); the marks are
/// persisted either way, so exiting loses nothing.
class ReviewView extends GetView<ReviewController> {
  const ReviewView({super.key});

  Future<void> _delete(BuildContext context) async {
    // A selection scopes the run to those photos; without one the
    // whole set is deleted, as before.
    final List<String>? onlyIds = controller.hasSelection
        ? controller.selectedItems.map((a) => a.id).toList()
        : null;
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected(
      onlyIds: onlyIds,
    );
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
      case ReviewDeleteOutcome.deleted:
        // A partial run (a selection was deleted) stays on screen
        // with the rest of the set. A whole-set run empties the
        // grid — the batch is complete, so the finish screen
        // replaces Review (fix plan Stage 5, ADR-020 decision 1;
        // ADR-014's permanent delete is unchanged).
        if (controller.items.isNotEmpty) {
          AppSnackbar.show(
            context,
            message: AppStrings.tr(
              AppStrings.snackDeletedMany,
              <String, String>{'count': '${controller.lastDeletedCount.value}'},
            ),
          );
          break;
        }
        Get.offNamed<dynamic>(
          AppRoutes.finish,
          arguments: controller.finishSummary,
        );
      case ReviewDeleteOutcome.denied:
        // Phase 3B mixed runs: a denied run may also have deleted
        // some photos and failed others. A mixed run gets a counted
        // dialog with no "View trash" choice (nothing was trashed).
        if (controller.lastDeletedCount.value > 0 ||
            controller.lastFailedCount.value > 0) {
          await AppDialog.showConfirmation(
            context,
            title: AppStrings.tr(AppStrings.deniedConfirmTitle),
            message: AppStrings.tr(
              AppStrings.deniedConfirmMixedDeleteMessage,
              <String, String>{
                'deleted': '${controller.lastDeletedCount.value}',
                'denied': '${controller.deniedIds.length}',
                'failed': '${controller.lastFailedCount.value}',
              },
            ),
            confirmLabel: AppStrings.tr(AppStrings.actionBackToDeck),
          );
          if (context.mounted) {
            controller.goToDeck();
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
        if (controller.lastDeletedCount.value > 0) {
          AppSnackbar.show(
            context,
            message: AppStrings.tr(
              AppStrings.snackDeletedMany,
              <String, String>{'count': '${controller.lastDeletedCount.value}'},
            ),
          );
        }
      case ReviewDeleteOutcome.serviceError:
      case null:
        // The error state renders inline with a retry action.
        break;
    }
  }

  /// Back control shared by the AppBar button and the system
  /// gesture: an active selection is cancelled first (the pop is
  /// swallowed); only a second back leaves the screen — and when
  /// photos are still waiting, the leave-guard asks first.
  Future<void> _onBack(BuildContext context) async {
    if (controller.selection.cancel()) {
      return;
    }
    if (await _confirmLeave(context)) {
      controller.goToDeck();
    }
  }

  /// Leave-guard (fix plan Stage 1; Cleanup's trash-leave popup
  /// pattern in wipe.'s own words — teardown notes/retention.md
  /// §1.3): leaving Review while photos are still waiting in the
  /// grid asks first. The dialog's confirm is "Save and Exit" —
  /// the marks are already persisted, so leaving loses nothing;
  /// "Open Review" and dismissing the dialog both stay. An empty
  /// grid never prompts.
  Future<bool> _confirmLeave(BuildContext context) async {
    final int waiting = controller.items.length;
    if (waiting == 0) {
      return true;
    }
    if (controller.leavePromptOpen) {
      return false;
    }
    controller.leavePromptOpen = true;
    try {
      return await AppDialog.showConfirmation(
        context,
        title: AppStrings.tr(AppStrings.reviewLeaveTitle),
        message: AppStrings.tr(AppStrings.reviewLeaveMessage, <String, String>{
          'count': '$waiting',
        }),
        confirmLabel: AppStrings.tr(AppStrings.reviewLeaveSaveExit),
        cancelLabel: AppStrings.tr(AppStrings.reviewLeaveOpenReview),
      );
    } finally {
      controller.leavePromptOpen = false;
    }
  }

  /// Bottom-nav exit: same leave-guard as the back control, then
  /// the controller's pop-to-shell navigation.
  Future<void> _onNavDestination(BuildContext context, int index) async {
    if (await _confirmLeave(context)) {
      controller.goToShellTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_onBack(context));
        }
      },
      child: Obx(() {
        final bool isEmpty = controller.items.isEmpty;
        return AppScaffold(
          title: AppStrings.tr(AppStrings.screenReview),
          // leading: IconButton(
          //   icon: Icon(AppIcons.back, size: context.sizes.iconMd),
          //   tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
          //   onPressed: _onBack,
          // ),
          actions: <Widget>[
            Obx(() {
              final bool mode = controller.selection.mode.value;
              return TextButton(
                onPressed: () => mode
                    ? controller.selection.selectAll(
                        controller.items.map((a) => a.id),
                      )
                    : controller.selection.enter(),
                child: Text(
                  AppStrings.tr(
                    mode ? AppStrings.actionSelectAll : AppStrings.actionSelect,
                  ),
                  style: context.textStyles.labelMedium.copyWith(
                    color: context.palette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              );
            }),
          ],
          bottomBar: isEmpty
              ? null
              : ReviewBottomBar(
                  controller: controller,
                  onDelete: () => _delete(context),
                ),
          // Phase 7.1 + ADR-009: nav taps from Review return to
          // the retained shell at the tapped tab (pop, never a
          // rebuild); Trash itself never fires here (it is the
          // current tab).
          bottomNav: AppBottomNav(
            currentIndex: 2,
            onDestinationSelected: (int index) =>
                unawaited(_onNavDestination(context, index)),
          ),
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
                    // const SizedBox(height: 10),
                    // _Header(controller: controller),
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
                    // Phase 3.3: the count is a controller aggregate
                    // refreshed on items-change, not a title scan
                    // per build.
                    if (controller.errorKey.value.isNotEmpty)
                      ErrorBanner(
                        message: AppStrings.tr(controller.errorKey.value),
                        onRetry: () => _delete(context),
                        onDismiss: () => controller.errorKey.value = '',
                      ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sizes.screenPadding,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: .5,
                          mainAxisSpacing: .5,
                        ),
                        itemCount: controller.items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final asset = controller.items[index];
                          // Phase 3.3: per-tile observer. The tile
                          // reads thumbnails/failures/blur inside
                          // its own Obx, so a thumbnail arrival
                          // rebuilds visible tiles only — never
                          // the scaffold, header, or bottom bar.
                          // (GetX RxMap granularity: every visible
                          // tile's Obx fires per arrival; the
                          // scaffold no longer does.)
                          return Obx(() {
                            final bool mode = controller.selection.mode.value;
                            final bool selected = controller.selection
                                .isSelected(asset.id);
                            return ReviewGridTile(
                              asset: asset,
                              thumbnail: controller.thumbnails[asset.id],
                              thumbnailFailed: controller.failedThumbnails
                                  .contains(asset.id),
                              selected: selected,
                              selectionMode: mode,
                              onTap: () => mode
                                  ? controller.selection.toggle(asset.id)
                                  : controller.unmark(asset),
                              onLongPress: () =>
                                  controller.selection.longPress(asset.id),
                              onRetry: () =>
                                  controller.retryThumbnail(asset.id),
                            );
                          }, key: ValueKey<String>(asset.id));
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
