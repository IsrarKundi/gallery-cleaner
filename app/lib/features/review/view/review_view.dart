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
/// delete still goes to Trash with a stack reset carrying the
/// recoverable-until date as route arguments, so the Trash screen
/// can show the "Moved to Trash" snackbar on arrival and the
/// post-delete state loads fresh.
///
/// Selection (owner decision 26 Oct 2026): photos are always
/// shown revealed. Outside selection mode a tile tap unmarks the
/// photo; in selection mode (long-press or the header's Select
/// button) taps toggle selection, and the bottom bar acts on the
/// selection (Keep X / Delete X) instead of the whole set. The
/// back control first cancels an active selection, and only then
/// leaves the screen.
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
      case ReviewDeleteOutcome.trashed:
        // A partial run (a selection was deleted) stays on screen
        // with the rest of the set — only a whole-set run goes to
        // the Trash screen, as before.
        if (controller.items.isNotEmpty) {
          AppSnackbar.show(
            context,
            message: AppStrings.tr(
              AppStrings.snackMovedToTrashMany,
              <String, String>{'count': '${controller.lastTrashedCount.value}'},
            ),
          );
          break;
        }
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

  /// Back control shared by the AppBar button and the system
  /// gesture: an active selection is cancelled first (the pop is
  /// swallowed); only a second back leaves the screen.
  void _onBack() {
    if (!controller.selection.cancel()) {
      controller.goToDeck();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Obx(() {
        final bool isEmpty = controller.items.isEmpty;
        return AppScaffold(
          title: AppStrings.tr(AppStrings.screenReview),
          leading: IconButton(
            icon: Icon(AppIcons.back, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
            onPressed: _onBack,
          ),
          actions: <Widget>[
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
          // Phase 7.1 + ADR-009: nav taps from Review return to
          // the retained shell at the tapped tab (pop, never a
          // rebuild); Trash itself never fires here (it is the
          // current tab).
          bottomNav: AppBottomNav(
            currentIndex: 2,
            onDestinationSelected: controller.goToShellTab,
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
                        padding: EdgeInsets.all(context.sizes.screenPadding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: context.sizes.sm,
                          mainAxisSpacing: context.sizes.sm,
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
              // Phase 3.3: the count text observes items itself,
              // so it never rides the scaffold's rebuilds.
              Obx(() {
                return Text(
                  '${Formatters.formatCount(controller.items.length)} · '
                  '${Formatters.formatBytes(controller.totalBytes)}',
                  style: context.textStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
              }),
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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.tr(AppStrings.reviewUnmarkHint),
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
              // Select text button: enters selection mode, then
              // becomes Select all. The label observes the mode
              // so it flips without rebuilding the grid.
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
                      mode
                          ? AppStrings.actionSelectAll
                          : AppStrings.actionSelect,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
