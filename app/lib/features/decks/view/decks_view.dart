// Smart-deck hub (requirements §7, Phase 2). Layout + Obx only:
// scanning, per-deck counts and navigation live in DecksController.
//
// The hub never blocks on the scan: rows appear and fill in as
// pages arrive, with a determinate progress bar (count + %) on top
// while scanning. Rows with zero photos are not tappable — tapping
// an empty deck would open an empty swipe screen with no action.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/detection/smart_decks.dart';
import '../controller/decks_controller.dart';
import '../model/decks_status.dart';
import '../model/smart_deck_meta.dart';
import '../widgets/deck_row.dart';

class DecksView extends GetView<DecksController> {
  const DecksView({super.key});

  @override
  Widget build(BuildContext context) {
    // No Obx here: _Body owns the only Obx, and an Obx whose builder
    // reads no observable is an improper GetX use (it throws when
    // any observable notifies). The scaffold frame never changes.
    return AppScaffold(
      title: AppStrings.tr(AppStrings.screenDecks),
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
          return const Center(child: CircularProgressIndicator());
        case DecksStatus.denied:
          return EmptyView(
            icon: AppIcons.photos,
            title: AppStrings.tr(AppStrings.permissionDeniedTitle),
            message: AppStrings.tr(AppStrings.permissionDeniedMessage),
            ctaLabel: AppStrings.tr(AppStrings.permissionAllowAccess),
            onCta: controller.retry,
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
      final bool allEmpty =
          !scanning &&
          smartDeckOrder.every(
            (SmartDeckId id) => controller.assetsFor(id).isEmpty,
          );
      if (allEmpty) {
        return EmptyView(
          icon: AppIcons.decks,
          title: AppStrings.tr(AppStrings.decksEmpty),
          message: AppStrings.tr(AppStrings.decksEmptyMessage),
          ctaLabel: AppStrings.tr(AppStrings.scanAgain),
          onCta: controller.retry,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (scanning)
            Padding(
              padding: EdgeInsets.all(context.sizes.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.tr(
                      AppStrings.decksScanningCount,
                      <String, String>{
                        'count': Formatters.formatCount(
                          controller.scanned.value,
                        ),
                      },
                    ),
                    style: context.textStyles.bodySmall,
                  ),
                  SizedBox(height: context.sizes.sm),
                  LinearProgressIndicator(value: controller.progress),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: SectionHeader(
              title: AppStrings.tr(AppStrings.decksTitle),
              subtitle: AppStrings.tr(AppStrings.decksSubtitle),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: smartDeckOrder.length,
              itemBuilder: (BuildContext context, int index) {
                final SmartDeckId id = smartDeckOrder[index];
                final int count = controller.assetsFor(id).length;
                return DeckRow(
                  deckId: id,
                  count: count,
                  totalBytes: controller.totalBytesFor(id),
                  ready: controller.deckReady(id),
                  onTap: count > 0 ? () => controller.openDeck(id) : null,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
