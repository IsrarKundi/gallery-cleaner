import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../controller/deck_controller.dart';
import '../model/deck_status.dart';
import '../widgets/album_picker_sheet.dart';
import '../widgets/deck_action_bar.dart';
import '../widgets/deck_home_skeleton.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/session_summary_card.dart';
// import '../widgets/space_meter_bar.dart';
import '../widgets/deck_card_stack.dart';
import '../widgets/tutorial_overlay.dart';

/// Deck screen (requirements §3, §7 / design.md §7). Layout + Obx
/// only: all state, permission, pagination and persistence live in
/// [DeckController].
///
/// Layout, top to bottom: partial-access banner (limited grants
/// only), live three-state meter, full-bleed card, caption below the
/// card (date, size, folder — never overlaid on the photo's subject),
/// bottom-anchored action bar. The tutorial overlays the deck on
/// first run only. Delete here only MARKS; confirmation lives on
/// review, so there is no confirmation sheet on this screen.
class DeckView extends GetView<DeckController> {
  const DeckView({super.key});

  /// RepaintBoundary key for the summary card capture (Phase 2B
  /// share). The view owns the key; the controller owns sharing.
  static final GlobalKey _summaryBoundaryKey = GlobalKey();

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizes.radiusSheet),
        ),
      ),
      builder: (BuildContext context) {
        return FilterSheet(controller: controller);
      },
    );
  }

  /// Albums load lazily (Phase 2.2): fetch them before opening any
  /// sheet that lists them, so the sheet is populated without
  /// blocking deck readiness at init.
  Future<void> _openFiltersWithAlbums(BuildContext context) async {
    await controller.ensureAlbums();
    if (context.mounted) {
      _openFilters(context);
    }
  }

  Future<void> _openAlbumPickerWithAlbums(BuildContext context) async {
    await controller.ensureAlbums();
    if (context.mounted) {
      _openAlbumPicker(context);
    }
  }

  void _shareCurrentAsset() {
    final MediaAsset? asset = controller.currentAsset;
    if (asset == null) {
      return;
    }
    final Uint8List? thumb = controller.thumbnails[asset.id];
    controller.retention.share?.shareSummary(
      text:
          '${asset.title.isEmpty ? 'Photo' : asset.title} · ${Formatters.formatBytes(asset.sizeBytes)}',
      imagePng: thumb,
    );
  }

  void _openAlbumPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizes.radiusSheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return AlbumPickerSheet(
          albums: controller.albums,
          onAlbumSelected: (MediaAlbum album) {
            Navigator.of(sheetContext).pop();
            AppSnackbar.show(
              context,
              message:
                  '${AppStrings.tr(AppStrings.actionAddToAlbum)}: ${album.name}',
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool showBar =
          controller.status.value == DeckStatus.ready &&
          controller.currentAsset != null;
      final MediaAsset? current = controller.currentAsset;
      final bool isFav =
          current != null && controller.favouriteIds.contains(current.id);
      return AppScaffold(
        title: AppStrings.tr(AppStrings.screenDeck),
        actions: <Widget>[
          IconButton(
            icon: Icon(AppIcons.history, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.screenHistory),
            onPressed: () => Get.toNamed<dynamic>(AppRoutes.history),
          ),
          IconButton(
            icon: Icon(AppIcons.filter, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.filterTitle),
            onPressed: () => _openFiltersWithAlbums(context),
          ),
        ],
        bottomBar: showBar
            ? DeckActionBar(
                onMark: controller.markCurrent,
                onUndo: controller.undo,
                canUndo: controller.canUndo,
                onReview: controller.goToReview,
                isFavourite: isFav,
                onFavorite: () => controller.markCurrent(DeckMark.favourite),
                onAddToAlbum: () => _openAlbumPickerWithAlbums(context),
                onShare: _shareCurrentAsset,
              )
            : null,
        bottomNav: const AppBottomNav(currentIndex: 0),
        body: Stack(
          children: <Widget>[
            _Body(controller: controller),
            if (controller.showTutorial.value)
              TutorialOverlay(onDismiss: controller.dismissTutorial),
          ],
        ),
      );
    });
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DeckController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (controller.status.value) {
        case DeckStatus.loading:
          return const DeckHomeSkeleton();
        case DeckStatus.denied:
          return EmptyView(
            icon: AppIcons.photos,
            title: AppStrings.tr(AppStrings.permissionDeniedTitle),
            message: AppStrings.tr(AppStrings.permissionDeniedMessage),
            ctaLabel: AppStrings.tr(AppStrings.permissionAllowAccess),
            onCta: controller.retry,
            // Phase 3B: a permanently denied grant makes the system
            // prompt a no-op, so the denied state also offers the
            // Settings page (the EmptyView's one documented
            // two-action exception).
            secondaryCtaLabel: AppStrings.tr(AppStrings.permissionOpenSettings),
            onSecondaryCta: controller.openPermissionSettings,
          );
        case DeckStatus.error:
          return ErrorView(
            message: AppStrings.tr(
              controller.errorKey.value.isEmpty
                  ? AppStrings.errorGeneric
                  : controller.errorKey.value,
            ),
            onRetry: controller.retry,
          );
        case DeckStatus.ready:
          return _ReadyBody(controller: controller);
      }
    });
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.controller});

  final DeckController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.queue.isEmpty) {
        if (controller.filter.value.isAll) {
          return EmptyView(
            icon: AppIcons.photos,
            title: AppStrings.tr(AppStrings.emptyFirstRunTitle),
            message: AppStrings.tr(AppStrings.emptyFirstRunMessage),
            ctaLabel: AppStrings.tr(AppStrings.emptyFirstRunCta),
            onCta: controller.retry,
          );
        }
        return EmptyView(
          icon: AppIcons.photos,
          title: AppStrings.tr(AppStrings.emptyNoFilterTitle),
          message: AppStrings.tr(AppStrings.emptyNoFilterMessage),
          ctaLabel: AppStrings.tr(AppStrings.emptyNoFilterCta),
          onCta: controller.clearFilter,
        );
      }
      if (controller.isFinished) {
        // Phase 2B summary card: counts + share (when a share
        // backend exists). Capture failure falls back to sharing
        // the same numbers as text (controller.shareCard(null)).
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              RepaintBoundary(
                key: DeckView._summaryBoundaryKey,
                child: SessionSummaryCard(
                  summary: controller.summary,
                  onShare: controller.retention.canShare
                      ? () async {
                          final png = await captureBoundaryPng(
                            DeckView._summaryBoundaryKey,
                          );
                          await controller.retention.shareSummary(
                            controller.summary,
                            png,
                          );
                        }
                      : null,
                ),
              ),
              if (controller.retention.shareErrorKey.value.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: context.sizes.sm),
                  child: Text(
                    AppStrings.tr(controller.retention.shareErrorKey.value),
                    // Phase 3B: light error #DB4437 on white is
                    // 4.29:1, below the 4.5:1 text bar — the message
                    // text itself carries the error, so it renders
                    // in text ink (the error icon/badge elsewhere
                    // stays error-coloured as a component).
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
              // SizedBox(height: context.sizes.xl),
              // SizedBox(
              //   width: double.infinity,
              //   height: context.sizes.buttonPrimary,
              //   child: FilledButton.icon(
              //     onPressed: controller.goToReview,
              //     icon: Icon(AppIcons.review, size: context.sizes.iconSm),
              //     label: Text(AppStrings.tr(AppStrings.actionReview)),
              //   ),
              // ),
            ],
          ),
        );
      }
      final current = controller.currentAsset!;
      final String caption =
          '${Formatters.formatDate(current.createDate)} · '
          '${Formatters.formatBytes(current.sizeBytes)} · '
          '${current.albumName}';
      return Column(
        children: <Widget>[
          // Phase 3B rebuild hygiene: banners and the meter sit in
          // their own Obx widgets, so thumbnail preloads (which
          // rebuild the card section below) do not rebuild them.
          Obx(() {
            final List<Widget> banners = <Widget>[];
            if (controller.protection.blockedKey.value.isNotEmpty) {
              banners.add(
                InfoBanner(
                  message: AppStrings.tr(
                    controller.protection.blockedKey.value,
                  ),
                  onDismiss: controller.protection.clearNotice,
                ),
              );
            }
            if (controller.isPartialAccess) {
              banners.add(_PartialBanner(controller: controller));
            }
            return Column(children: banners);
          }),
          // Obx(() => SpaceMeterBar(totals: controller.meter)),
          // Phase 3.1: the stack owns the thumbnail Obx, so preload
          // arrivals rebuild only the stack — this Obx reads the
          // queue and index, never the thumbnail maps.
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              child: DeckCardStack(
                current: current,
                next: <MediaAsset>[
                  for (
                    int i = controller.currentIndex.value + 1;
                    i < controller.queue.length &&
                        i <= controller.currentIndex.value + 2;
                    i++
                  )
                    controller.queue[i],
                ],
                thumbnails: controller.thumbnails,
                failedThumbnails: controller.failedThumbnails,
                onSwiped: controller.markCurrent,
                onRetry: controller.retryCurrentThumbnail,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
              vertical: context.sizes.sm,
            ),
            child: Text(
              caption,
              style: context.textStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    });
  }
}

/// Phase 3B partial-access banner (requirements §5): honest copy
/// plus both recovery actions. "Add more photos" shows the Android
/// 14 system picker to ADD photos to the limited grant and reloads
/// the deck when it dismisses; "Open settings" opens the system
/// Settings page, the only place "Allow all photos" lives — the
/// hint below the actions says so, and returning users re-check
/// by tapping "Add more photos". Neither action claims a full
/// grant the system did not give.
class _PartialBanner extends StatelessWidget {
  const _PartialBanner({required this.controller});

  final DeckController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.palette.warningBg,
      padding: EdgeInsets.symmetric(
        horizontal: context.sizes.screenPadding,
        vertical: context.sizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.tr(AppStrings.permissionPartialTitle),
            style: context.textStyles.labelMedium,
          ),
          Text(
            AppStrings.tr(AppStrings.permissionPartialMessage),
            style: context.textStyles.bodySmall,
          ),
          Text(
            AppStrings.tr(AppStrings.permissionPartialSettingsHint),
            style: context.textStyles.bodySmall,
          ),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: controller.expandPartialAccess,
                child: Text(AppStrings.tr(AppStrings.permissionPartialAddMore)),
              ),
              SizedBox(width: context.sizes.sm),
              TextButton(
                onPressed: controller.openPermissionSettings,
                child: Text(AppStrings.tr(AppStrings.permissionOpenSettings)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
