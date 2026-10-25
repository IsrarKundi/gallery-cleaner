import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../controller/history_controller.dart';
import '../widgets/history_row.dart';

/// History screen (requirements §4): deletion-history records,
/// newest first. Layout + Obx only: loading lives in
/// [HistoryController]. No action other than back to the deck.
///
/// Navigation contract (see the controller): every exit resets the
/// stack with [Get.offAllNamed] — the AppBar back control, the system
/// back gesture (via [PopScope]) and the empty-state CTA all go to
/// the deck, never [Get.back] into a stale deck controller.
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.goToDeck();
        }
      },
      child: AppScaffold(
        title: AppStrings.tr(AppStrings.screenHistory),
        leading: IconButton(
          icon: Icon(AppIcons.back, size: context.sizes.iconMd),
          tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
          onPressed: controller.goToDeck,
        ),
        body: _Body(controller: controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.records.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorKey.value.isNotEmpty && controller.records.isEmpty) {
        return ErrorView(
          message: AppStrings.tr(controller.errorKey.value),
          onRetry: controller.init,
        );
      }
      if (controller.records.isEmpty) {
        return EmptyView(
          icon: AppIcons.history,
          title: AppStrings.tr(AppStrings.historyEmptyTitle),
          message: AppStrings.tr(AppStrings.historyEmptyMessage),
          ctaLabel: AppStrings.tr(AppStrings.actionBackToDeck),
          onCta: controller.goToDeck,
        );
      }
      return ListView.builder(
        itemCount: controller.records.length,
        itemBuilder: (BuildContext context, int index) {
          return HistoryRow(record: controller.records[index]);
        },
      );
    });
  }
}
