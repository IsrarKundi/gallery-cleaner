// Duplicates screen (requirements §7, Phase 2). Layout + Obx only:
// scanning, grouping, keeper choice and review navigation live in
// DuplicatesController.
//
// Stage 4: the groups are the scan's exact-duplicate memberships
// (fixed Cleanup rules) — the similarity slider is removed
// (owner-approved, ADR-019); Stage 7 owns this screen's layout
// redesign. The keeper badge marks the suggested keeper; tapping
// any thumbnail changes it before "mark others for deletion" is
// pressed.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_banner.dart';
import '../controller/duplicates_controller.dart';
import '../model/decks_status.dart';
import '../widgets/duplicate_group_card.dart';

class DuplicatesView extends GetView<DuplicatesController> {
  const DuplicatesView({super.key});

  @override
  Widget build(BuildContext context) {
    // No Obx here: _Body owns the only Obx (see DecksView for why
    // an observable-free outer Obx is not used).
    return AppScaffold(
      title: AppStrings.tr(AppStrings.screenDuplicates),
      body: _Body(controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DuplicatesController controller;

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
            secondaryCtaLabel: AppStrings.tr(AppStrings.permissionOpenSettings),
            onSecondaryCta: controller.openPermissionSettings,
          );
        case DecksStatus.error:
        case DecksStatus.scanning:
          if (controller.status.value == DecksStatus.error) {
            return ErrorView(
              message: AppStrings.tr(
                controller.errorKey.value.isEmpty
                    ? AppStrings.errorGeneric
                    : controller.errorKey.value,
              ),
              onRetry: controller.retry,
            );
          }
          return const Center(child: CircularProgressIndicator());
        case DecksStatus.ready:
          return _ReadyBody(controller: controller);
      }
    });
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.controller});

  final DuplicatesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.groups.isEmpty) {
        return EmptyView(
          icon: AppIcons.duplicates,
          title: AppStrings.tr(AppStrings.duplicatesEmptyTitle),
          message: AppStrings.tr(AppStrings.duplicatesEmptyMessage),
        );
      }
      return Column(
        children: <Widget>[
          if (controller.protectedExcludedCount.value > 0)
            InfoBanner(
              message: AppStrings.tr(
                AppStrings.protectionDuplicatesExcluded,
                <String, String>{
                  'count': '${controller.protectedExcludedCount.value}',
                },
              ),
              onDismiss: () => controller.protectedExcludedCount.value = 0,
            ),
          if (controller.errorKey.value.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(context.sizes.screenPadding),
              child: Text(
                AppStrings.tr(controller.errorKey.value),
                // Phase 3B: same 4.29:1 light-error fix as the
                // deck's share error text (design.md §9).
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              itemCount: controller.groups.length,
              separatorBuilder: (BuildContext context, int index) =>
                  SizedBox(height: context.sizes.lg),
              itemBuilder: (BuildContext context, int index) {
                final group = controller.groups[index];
                return DuplicateGroupCard(
                  group: group,
                  thumbnails: controller.thumbnails,
                  failedThumbnails: controller.failedThumbnails,
                  onKeeperTap: (String id) =>
                      controller.changeKeeper(index, id),
                  onMarkNonKeepers: () => controller.markNonKeepers(index),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
