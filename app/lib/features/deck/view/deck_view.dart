import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../controller/deck_controller.dart';
import '../model/deck_status.dart';
import '../widgets/deck_action_bar.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/space_meter_bar.dart';
import '../widgets/swipe_card.dart';
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool showBar =
          controller.status.value == DeckStatus.ready &&
          controller.currentAsset != null;
      return AppScaffold(
        title: AppStrings.tr(AppStrings.screenDeck),
        actions: <Widget>[
          // Phase 1 screens are reachable from the deck, not only
          // via the review-delete flow: Trash for restore/emptying
          // and History for past cleaning runs. Both reset the
          // stack back to the deck (their own navigation contract).
          IconButton(
            icon: Icon(AppIcons.decks, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.screenDecks),
            onPressed: () => Get.toNamed<dynamic>(AppRoutes.decks),
          ),
          IconButton(
            icon: Icon(AppIcons.trash, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.screenTrash),
            onPressed: () => Get.toNamed<dynamic>(AppRoutes.trash),
          ),
          IconButton(
            icon: Icon(AppIcons.history, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.screenHistory),
            onPressed: () => Get.toNamed<dynamic>(AppRoutes.history),
          ),
          IconButton(
            icon: Icon(AppIcons.filter, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.filterTitle),
            onPressed: () => _openFilters(context),
          ),
        ],
        bottomBar: showBar
            ? DeckActionBar(
                onMark: controller.markCurrent,
                onUndo: controller.undo,
                canUndo: controller.canUndo,
                onReview: controller.goToReview,
              )
            : null,
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
          return const Center(child: CircularProgressIndicator());
        case DeckStatus.denied:
          return EmptyView(
            icon: AppIcons.photos,
            title: AppStrings.tr(AppStrings.permissionDeniedTitle),
            message: AppStrings.tr(AppStrings.permissionDeniedMessage),
            ctaLabel: AppStrings.tr(AppStrings.permissionAllowAccess),
            onCta: controller.retry,
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
        return EmptyView(
          icon: AppIcons.check,
          title: AppStrings.tr(AppStrings.deckFinishedTitle),
          message: AppStrings.tr(AppStrings.deckFinishedMessage),
          ctaLabel: AppStrings.tr(AppStrings.actionReview),
          onCta: controller.goToReview,
        );
      }
      final current = controller.currentAsset!;
      final String caption =
          '${Formatters.formatDate(current.createDate)} · '
          '${Formatters.formatBytes(current.sizeBytes)} · '
          '${current.albumName}';
      return Column(
        children: <Widget>[
          if (controller.isPartialAccess)
            Container(
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
                ],
              ),
            ),
          SpaceMeterBar(totals: controller.meter),
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
