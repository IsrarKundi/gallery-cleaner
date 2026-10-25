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

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../features/deck/widgets/deck_action_bar.dart';
import '../../../features/deck/widgets/swipe_card.dart';
import '../../../services/detection/smart_decks.dart';
import '../controller/smart_deck_controller.dart';
import '../model/smart_deck_meta.dart';

class SmartDeckView extends GetView<SmartDeckController> {
  const SmartDeckView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool showBar =
          controller.ready.value && controller.currentAsset != null;
      final SmartDeckId? deckId = controller.deckId;
      return AppScaffold(
        title: deckId == null
            ? AppStrings.tr(AppStrings.screenSmartDeck)
            : AppStrings.tr(smartDeckTitleKey(deckId)),
        bottomBar: showBar
            ? DeckActionBar(
                onMark: controller.markCurrent,
                onUndo: controller.undo,
                canUndo: controller.canUndo,
                onReview: controller.goToReview,
              )
            : null,
        body: _Body(controller: controller),
      );
    });
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final SmartDeckController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.ready.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.queue.isEmpty) {
        return EmptyView(
          icon: AppIcons.decks,
          title: AppStrings.tr(AppStrings.smartDeckEmptyTitle),
          message: AppStrings.tr(AppStrings.smartDeckEmptyMessage),
        );
      }
      if (controller.isFinished) {
        return EmptyView(
          icon: AppIcons.check,
          title: AppStrings.tr(AppStrings.smartDeckFinishedTitle),
          message: AppStrings.tr(AppStrings.smartDeckFinishedMessage),
          ctaLabel: AppStrings.tr(AppStrings.actionReview),
          onCta: controller.goToReview,
        );
      }
      final current = controller.currentAsset!;
      final String caption =
          '${Formatters.formatDate(current.createDate)} · '
          '${Formatters.formatBytes(current.sizeBytes)} · '
          '${current.albumName}';
      final int decided = controller.marks.length;
      return Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(context.sizes.screenPadding),
            child: Text(
              AppStrings.tr(AppStrings.smartDeckProgress, <String, String>{
                'index': decided.toString(),
                'count': controller.queue.length.toString(),
              }),
              style: context.textStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              child: SwipeCard(
                key: ValueKey<String>(current.id),
                thumbnail: controller.thumbnails[current.id],
                thumbnailFailed: controller.failedThumbnails.contains(
                  current.id,
                ),
                onSwiped: controller.markCurrent,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.sizes.screenPadding),
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
