// Smart-deck hub (requirements §7, Phase 2).
// Layout + Obx only: scanning, per-deck counts and navigation live in DecksController.
//
// Screen structure (matches redesigned mock):
// - Top Bar: App title ("Klara") + storage/streak badge pill + circular settings button.
// - On This Day hero banner card with 5 fanned-out preview stack.
// - Timeline: header with total size, sort button + year chips, horizontal month cards.
// - Smart decks: header with 'See all (N) ›', horizontal 2x2 thumbnail grid cards in user priority order.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/media/media_asset.dart';
import '../controller/decks_controller.dart';
import '../model/decks_status.dart';
import '../model/smart_deck_meta.dart';
import '../widgets/decks_loading_skeleton.dart';
// import '../widgets/decks_scanning_banner.dart';
// import '../widgets/decks_top_header.dart';
import '../widgets/on_this_day_hero_card.dart';
import '../widgets/smart_deck_grid_card.dart';
import '../widgets/timeline_section.dart';

class DecksView extends GetView<DecksController> {
  const DecksView({super.key, this.showBottomNav = true});

  /// Phase 7.1: the shell renders the one bottom nav, so shell
  /// tabs hide their own. Standalone use keeps the nav.
  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.tr(AppStrings.screenDecks),
      bottomNav: showBottomNav ? const AppBottomNav(currentIndex: 1) : null,
      body: _Body(controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DecksController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (controller.status.value) {
        case DecksStatus.loading:
          return const DecksLoadingSkeleton();
        case DecksStatus.denied:
          return EmptyView(
            icon: AppIcons.photos,
            title: AppStrings.tr(AppStrings.permissionDeniedTitle),
            message: AppStrings.tr(AppStrings.permissionDeniedMessage),
            ctaLabel: AppStrings.tr(AppStrings.permissionAllowAccess),
            onCta: controller.retry,
            secondaryCtaLabel: AppStrings.tr(AppStrings.permissionOpenSettings),
            onSecondaryCta: controller.openPermissionSettings,
          );
        case DecksStatus.error:
          return ErrorView(
            message: AppStrings.tr(
              controller.errorKey.value.isEmpty
                  ? AppStrings.errorGeneric
                  : controller.errorKey.value,
            ),
            onRetry: controller.retry,
          );
        case DecksStatus.scanning:
        case DecksStatus.ready:
          return _HubBody(controller: controller);
      }
    });
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.controller});

  final DecksController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool scanning = controller.isScanning;
      final List<MediaAsset> onThisDayAssets = controller.assetsFor(
        SmartDeckId.onThisDay,
      );

      // Filter: only show decks with photos, in priority order, excluding onThisDay (which has hero card)
      final List<SmartDeckId> visibleDecks = smartDeckOrder.where((
        SmartDeckId id,
      ) {
        return id != SmartDeckId.onThisDay &&
            controller.assetsFor(id).isNotEmpty;
      }).toList();

      final bool allEmpty =
          !scanning &&
          visibleDecks.isEmpty &&
          onThisDayAssets.isEmpty &&
          controller.allAssets.isEmpty;

      if (allEmpty) {
        return EmptyView(
          icon: AppIcons.decks,
          title: AppStrings.tr(AppStrings.decksEmpty),
          message: AppStrings.tr(AppStrings.decksEmptyMessage),
          ctaLabel: AppStrings.tr(AppStrings.scanAgain),
          onCta: controller.retry,
        );
      }

      return ListView(
        padding: EdgeInsets.symmetric(vertical: context.sizes.sm),
        children: <Widget>[
          // Top Header: App Title ("Klara") + Badge Pill (Target + Streak) + Settings button
          // DecksTopHeader(
          //   controller: controller,
          //   totalBytes: totalStorageBytes,
          //   visibleDecksCount: visibleDecks.length,
          //   readyBytes: readyBytes,
          //   scanning: scanning,
          // ),
          // if (scanning) ...<Widget>[
          //   SizedBox(height: context.sizes.xs),
          //   DecksScanningBanner(controller: controller),
          // ],
          if (onThisDayAssets.isNotEmpty) ...<Widget>[
            // SizedBox(height: context.sizes.sm),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              child: OnThisDayHeroCard(
                assets: onThisDayAssets,
                onTap: () => controller.openDeck(SmartDeckId.onThisDay),
                thumbnails: controller.thumbnailsFor(320),
                failedThumbnails: controller.failedFor(320),
                requestThumbnail: (String id) =>
                    controller.requestThumbnail(id, 320),
              ),
            ),
          ] else if (scanning) ...<Widget>[
            SizedBox(height: context.sizes.sm),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              child: const HeroCardSkeleton(),
            ),
          ],
          // Phase 5.1: visible "scanning slower" state, only while
          // the degraded scan is still running. The flag resets on
          // the next scan, so this never lingers after it ends.
          if (scanning && controller.scanDegraded.value)
            InfoBanner(message: AppStrings.tr(AppStrings.scanSlower)),
          SizedBox(height: context.sizes.md),
          // Timeline Section
          TimelineSection(
            totalBytes: controller.timelineTotalBytes,
            years: controller.timelineYears,
            months: controller.monthsForYear(
              controller.selectedYear.value,
              ascending: controller.timelineAscending.value,
            ),
            selectedYear: controller.selectedYear.value,
            ascending: controller.timelineAscending.value,
            onYearSelected: (int y) => controller.selectedYear.value = y,
            onToggleSort: () => controller.timelineAscending.toggle(),
            onMonthTap: controller.openMonth,
            thumbnails: controller.thumbnailsFor(320),
            failedThumbnails: controller.failedFor(320),
            requestThumbnail: (String id) =>
                controller.requestThumbnail(id, 320),
            isScanning: scanning,
          ),
          SizedBox(height: context.sizes.lg),
          // Smart Decks Section
          _SmartDecksSection(
            controller: controller,
            visibleDecks: visibleDecks,
            scanning: scanning,
          ),
          SizedBox(height: context.sizes.lg),
        ],
      );
    });
  }
}

class _SmartDecksSection extends StatelessWidget {
  const _SmartDecksSection({
    required this.controller,
    required this.visibleDecks,
    required this.scanning,
  });

  final DecksController controller;
  final List<SmartDeckId> visibleDecks;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final bool showSkeletons = scanning && visibleDecks.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header Row: Smart decks + See all (N) ›
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.screenPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.tr(AppStrings.decksTitle),
                  style: context.textStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.sizes.xs),
              Text(
                AppStrings.tr(AppStrings.seeAllDecks, <String, String>{
                  'count': visibleDecks.length.toString(),
                }),
                style: context.textStyles.labelMedium.copyWith(
                  color: context.palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sizes.md),
        // Horizontal list of 2x2 grid cards
        SizedBox(
          height: 235,
          child: showSkeletons
              ? AppSkeleton(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sizes.screenPadding,
                    ),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: 2,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: context.sizes.md),
                    itemBuilder: (_, _) => const DeckGridSkeleton(),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sizes.screenPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: visibleDecks.length,
                  separatorBuilder: (_, _) => SizedBox(width: context.sizes.md),
                  itemBuilder: (BuildContext context, int index) {
                    final SmartDeckId id = visibleDecks[index];
                    final List<MediaAsset> assets = controller.assetsFor(id);
                    return SmartDeckGridCard(
                      deckId: id,
                      count: assets.length,
                      totalBytes: controller.totalBytesFor(id),
                      assets: assets,
                      thumbnails: controller.thumbnailsFor(320),
                      failedThumbnails: controller.failedFor(320),
                      requestThumbnail: (String id) =>
                          controller.requestThumbnail(id, 320),
                      onTap: () => controller.openDeck(id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
