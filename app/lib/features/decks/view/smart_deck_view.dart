// One smart deck as a swipe deck (requirements §7, Phase 2).
// Layout + Obx only: queue, marks, undo, session and review
// navigation live in SmartDeckController.
//
// Reuse, not duplication: the card is the deck's own SwipeCard and
// the bar is the deck's own DeckActionBar, so gestures, edge labels
// and the locked mapping are identical to the main deck. Only the
// header differs: a "N of M decided" progress line instead of the
// main deck's space meter (the meter lives on the main deck; this
// screen's job is deciding this deck's photos).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../core/widgets/review_ask_sheet.dart';
import '../../../features/deck/widgets/album_picker_sheet.dart';
import '../../../features/deck/widgets/deck_action_bar.dart';
import '../../../features/deck/widgets/deck_card_stack.dart';
import '../../../features/deck/widgets/deck_home_skeleton.dart';
import '../../../features/deck/widgets/session_summary_card.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/review_ask/review_ask.dart';
import '../../../services/review_ask/review_ask_service.dart';
import '../controller/smart_deck_controller.dart';
import '../model/smart_deck_meta.dart';

class SmartDeckView extends GetView<SmartDeckController> {
  const SmartDeckView({super.key});

  Future<void> _openAlbumPickerWithAlbums(
    BuildContext context,
    SmartDeckController controller,
  ) async {
    await controller.ensureAlbums();
    if (context.mounted) {
      _openAlbumPicker(context, controller);
    }
  }

  void _shareCurrentAsset(SmartDeckController controller) {
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

  void _openAlbumPicker(BuildContext context, SmartDeckController controller) {
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
    return _SwipeAskWatcher(
      controller: controller,
      child: Obx(() {
        final bool showBar =
            controller.ready.value && controller.currentAsset != null;
        final SmartDeckId? deckId = controller.deckId;
        final int decided = controller.marks.length;
        final int total = controller.queue.length;
        final MediaAsset? current = controller.currentAsset;
        final bool isFav =
            current != null && controller.favouriteIds.contains(current.id);

        return AppScaffold(
          title: deckId == null
              ? (controller.launchTitle ??
                    AppStrings.tr(AppStrings.screenSmartDeck))
              : AppStrings.tr(smartDeckTitleKey(deckId)),
          actions: <Widget>[
            if (showBar && total > 0)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sizes.screenPadding,
                  ),
                  child: Text(
                    AppStrings.tr(
                      AppStrings.smartDeckProgress,
                      <String, String>{
                        'index': decided.toString(),
                        'count': total.toString(),
                      },
                    ),
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
          bottomBar: showBar
              ? DeckActionBar(
                  onMark: controller.markCurrent,
                  onUndo: controller.undo,
                  canUndo: controller.canUndo,
                  onReview: controller.goToReview,
                  isCleanScreen: true,
                  isFavourite: isFav,
                  onFavorite: () => controller.markCurrent(DeckMark.favourite),
                  onAddToAlbum: () =>
                      _openAlbumPickerWithAlbums(context, controller),
                  onShare: () => _shareCurrentAsset(controller),
                )
              : null,
          body: _Body(controller: controller),
        );
      }),
    );
  }
}

/// Stage 5 (ADR-020): presents the swipe-place review ask when
/// a mark finishes this session — session end only, never
/// mid-session (the controller flags the moment; the sheet's
/// due check does the gating).
class _SwipeAskWatcher extends StatefulWidget {
  const _SwipeAskWatcher({required this.controller, required this.child});

  final SmartDeckController controller;
  final Widget child;

  @override
  State<_SwipeAskWatcher> createState() => _SwipeAskWatcherState();
}

class _SwipeAskWatcherState extends State<_SwipeAskWatcher> {
  Worker? _worker;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    _worker = ever<bool>(widget.controller.swipeAskPending, _onPending);
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _onPending(bool pending) async {
    if (!pending || _presenting || !mounted) {
      return;
    }
    widget.controller.swipeAskPending.value = false;
    final ReviewAskService? service = widget.controller.reviewAsk;
    if (service == null) {
      return;
    }
    _presenting = true;
    int amount = widget.controller.summary.deleteMarkedBytes;
    if (amount <= 0) {
      amount = await service.fallbackAmountBytes();
    }
    if (mounted) {
      await ReviewAskSheet.maybeShow(
        context,
        service: service,
        place: ReviewAskPlace.swipe,
        amountBytes: amount,
      );
    }
    _presenting = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final SmartDeckController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.ready.value) {
        return const DeckHomeSkeleton();
      }
      if (controller.queue.isEmpty) {
        return EmptyView(
          icon: AppIcons.decks,
          title: AppStrings.tr(AppStrings.smartDeckEmptyTitle),
          message: AppStrings.tr(AppStrings.smartDeckEmptyMessage),
        );
      }
      if (controller.isFinished) {
        // Phase 2B: same summary counts as the main deck, without
        // a share button (the main deck owns sharing).
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: context.sizes.lg),
              SessionSummaryCard(summary: controller.summary),
              SizedBox(height: context.sizes.xl),
              SizedBox(
                width: double.infinity,
                height: context.sizes.buttonPrimary,
                child: FilledButton.icon(
                  onPressed: controller.goToReview,
                  icon: Icon(AppIcons.review, size: context.sizes.iconSm),
                  label: Text(AppStrings.tr(AppStrings.actionReview)),
                ),
              ),
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
          if (controller.protection.blockedKey.value.isNotEmpty)
            InfoBanner(
              message: AppStrings.tr(controller.protection.blockedKey.value),
              onDismiss: controller.protection.clearNotice,
            ),
          // Phase 3.1: same card stack as the main deck (current +
          // next 2 pre-decoded underneath); the stack owns the
          // thumbnail Obx so preload arrivals rebuild only it.
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
                // Phase 7.1 settled-review gate, same contract as
                // the main deck: the gate releases when the swipe's
                // mark RECORDS (markCurrent is sync here), not when
                // the exit animation ends (which fires just before
                // onSwiped and would capture a stale review set).
                onSwiped: (mark) {
                  controller.markCurrent(mark);
                  controller.setCardExiting(false);
                },
                onRetry: controller.retryCurrentThumbnail,
                onExitStart: () => controller.setCardExiting(true),
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
