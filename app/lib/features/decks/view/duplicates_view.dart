// Duplicates screen (requirements §7, Phase 2). Layout + Obx only:
// scanning, grouping, keeper choice, selection and review
// navigation live in DuplicatesController.
//
// Stage 4: the groups are the scan's exact-duplicate memberships
// (fixed Cleanup rules) — the similarity slider is removed
// (owner-approved, ADR-019).
//
// Stage 7 (ADR-022): Cleanup's layout in wipe.'s clothes — the
// screen opens with the results: a summary of the duplicate
// photos (the non-keepers across all groups) and their size, one
// explanation line, Select all / Deselect all, then the group
// cards with large two-per-row photos, a Keeper pill and a
// selection mark per non-keeper. One sticky bottom button marks
// the selected duplicates for review; this screen never deletes.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/duplicates_controller.dart';
import '../model/decks_status.dart';
import '../widgets/duplicate_group_card.dart';

class DuplicatesView extends GetView<DuplicatesController> {
  const DuplicatesView({super.key});

  @override
  Widget build(BuildContext context) {
    // No Obx here: _Body and _MarkBar own their Obx scopes (see
    // DecksView for why an observable-free outer Obx is not used).
    return AppScaffold(
      title: AppStrings.tr(AppStrings.screenDuplicates),
      body: _Body(controller: controller),
      bottomBar: _MarkBar(controller: controller),
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

/// The results header (Stage 7): the totals line, the one
/// explanation line for the whole screen, and the whole-list
/// selection controls — in that order, before any card.
///
/// The selection-derived states arrive as plain props: the
/// wrapping Obx reads them inside its own builder (the tracked
/// scope), so the controls never go stale when a mark flips.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.controller,
    required this.allSelected,
    required this.anySelected,
  });

  final DuplicatesController controller;
  final bool allSelected;
  final bool anySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sizes.screenPadding,
        context.sizes.lg,
        context.sizes.screenPadding,
        context.sizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.tr(AppStrings.duplicatesSummary, <String, String>{
              'count': '${controller.duplicateCount}',
              'size': Formatters.formatBytes(controller.duplicateBytes),
            }),
            style: context.textStyles.titleMedium,
          ),
          SizedBox(height: context.sizes.xs),
          Text(
            AppStrings.tr(AppStrings.duplicatesExplanation),
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          SizedBox(height: context.sizes.sm),
          Row(
            children: <Widget>[
              _TextAction(
                label: AppStrings.tr(AppStrings.actionSelectAll),
                enabled: !allSelected,
                onTap: controller.selectAll,
              ),
              SizedBox(width: context.sizes.lg),
              _TextAction(
                label: AppStrings.tr(AppStrings.actionDeselectAll),
                enabled: anySelected,
                onTap: controller.deselectAll,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tertiary text action in the app's existing style (the Review
/// selection bar's tappable label): primary colour, inert and
/// tertiary-coloured when it would change nothing.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.sizes.xs),
        child: Text(
          label,
          style: context.textStyles.labelMedium.copyWith(
            color: enabled
                ? context.palette.primary
                : context.palette.textTertiary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The one sticky action (Stage 7): live totals of the SELECTED
/// non-keepers. At zero selected it is disabled, with the caption
/// design.md §5 requires explaining why. Shown only over a ready,
/// non-empty list (the Finish screen's bottom-bar shape).
class _MarkBar extends StatelessWidget {
  const _MarkBar({required this.controller});

  final DuplicatesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.status.value != DecksStatus.ready ||
          controller.groups.isEmpty) {
        return const SizedBox.shrink();
      }
      final int count = controller.selectedCount;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (count == 0) ...<Widget>[
                Text(
                  AppStrings.tr(AppStrings.duplicatesSelectHint),
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.sizes.xs),
              ],
              PrimaryButton(
                label: AppStrings.tr(
                  AppStrings.duplicatesMarkSelected,
                  <String, String>{
                    'count': '$count',
                    'size': Formatters.formatBytes(controller.selectedBytes),
                  },
                ),
                icon: AppIcons.delete,
                onPressed: count == 0 ? null : () => controller.markSelected(),
              ),
            ],
          ),
        ),
      );
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
          Obx(
            () => _SummaryHeader(
              controller: controller,
              allSelected: controller.allSelected,
              anySelected: controller.anySelected,
            ),
          ),
          Expanded(
            // The cards read the selection inside the lazy list
            // builder — outside any Obx's tracked scope — so this
            // Obx snapshots the selection inside its own builder
            // (subscribing to it) and hands the cards a plain set
            // that is fresh on every selection change.
            child: Obx(() {
              final Set<String> selectedSnapshot = Set<String>.of(
                controller.selectedIds,
              );
              return ListView.separated(
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
                    selectedIds: selectedSnapshot,
                    onKeeperTap: (String id) =>
                        controller.changeKeeper(index, id),
                    onToggleSelection: controller.toggleSelection,
                  );
                },
              );
            }),
          ),
        ],
      );
    });
  }
}
