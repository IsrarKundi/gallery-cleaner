// Duplicates screen (requirements §7, Phase 2). Layout + Obx only:
// scanning, grouping, keeper choice and review navigation live in
// DuplicatesController.
//
// The similarity slider regroups live from cached hashes: moving it
// never re-downloads thumbnails, so groups update instantly. The
// keeper badge marks the suggested keeper; tapping any thumbnail
// changes it before "mark others for deletion" is pressed.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
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
          Padding(
            padding: EdgeInsets.all(context.sizes.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      AppStrings.tr(AppStrings.duplicatesSliderLabel),
                      style: context.textStyles.labelLarge,
                    ),
                    Text(
                      AppStrings.tr(
                        AppStrings.duplicatesSliderValue,
                        <String, String>{
                          'value': controller.threshold.value.toString(),
                        },
                      ),
                      style: context.textStyles.labelLarge,
                    ),
                  ],
                ),
                Slider(
                  value: controller.threshold.value.toDouble(),
                  min: DuplicatesController.sliderMin.toDouble(),
                  max: DuplicatesController.sliderMax.toDouble(),
                  divisions:
                      DuplicatesController.sliderMax -
                      DuplicatesController.sliderMin,
                  label: controller.threshold.value.toString(),
                  onChanged: (double value) =>
                      controller.setThreshold(value.round()),
                ),
                Text(
                  AppStrings.tr(AppStrings.duplicatesSliderHint),
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                if (controller.errorKey.value.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: context.sizes.sm),
                    child: Text(
                      AppStrings.tr(controller.errorKey.value),
                      style: context.textStyles.bodySmall.copyWith(
                        color: context.palette.error,
                      ),
                    ),
                  ),
              ],
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
