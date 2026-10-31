import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../deck/view/deck_view.dart';
import '../../decks/view/decks_view.dart';
import '../../settings/view/settings_view.dart';
import '../controller/shell_controller.dart';

/// Bottom-nav shell (solutions 7.1, design.md §6): one route hosting
/// the retained tabs in an IndexedStack, with a single bottom nav.
/// Tabs build lazily on first visit and stay mounted afterwards, so
/// a tab switch is never a relaunch — the deck keeps its queue and
/// marks, the hub keeps its scan (shared since Phase 4.2) and its
/// lists. Each tab renders without its own nav (the shell renders
/// the one nav); Review/Trash are NOT shell children — Review is a
/// fresh route pushed over the shell by the nav's Trash action, and
/// returning from it pops back to the retained tabs (ADR-009).
///
/// Composition exception (AGENTS.md): like AppPages, the shell view
/// composes feature views; it owns no feature state. See ADR-007.
class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  /// App-exit guard (ADR-016 addendum; owner decision 31 Oct
  /// 2026): the shell is the root route, so a system back press
  /// here is an app exit. While items still wait in Trash the
  /// exit asks first — "Stay" (and dismissing the dialog)
  /// swallows the back press, "Exit" leaves. An empty Trash
  /// exits silently, exactly as the back press always did.
  /// Pushed routes above the shell keep their own back
  /// behaviour; this guard only ever sees the shell's own pop.
  Future<void> _onBack(BuildContext context) async {
    if (controller.exitPromptOpen) {
      return;
    }
    controller.exitPromptOpen = true;
    try {
      final int waiting = await controller.waitingInTrashCount();
      if (!context.mounted) {
        return;
      }
      if (waiting == 0) {
        await controller.exitApp();
        return;
      }
      final bool exit = await AppDialog.showConfirmation(
        context,
        title: AppStrings.tr(AppStrings.homeExitTitle),
        message: AppStrings.tr(AppStrings.homeExitMessage, <String, String>{
          'count': '$waiting',
        }),
        confirmLabel: AppStrings.tr(AppStrings.homeExitExit),
        cancelLabel: AppStrings.tr(AppStrings.homeExitStay),
      );
      if (exit) {
        await controller.exitApp();
      }
    } finally {
      controller.exitPromptOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_onBack(context));
        }
      },
      child: Obx(() {
        return Scaffold(
          backgroundColor: context.palette.background,
          body: IndexedStack(
            index: controller.stackIndex,
            children: <Widget>[
              if (controller.isTabVisited(0))
                const DeckView(showBottomNav: false)
              else
                const SizedBox.shrink(),
              if (controller.isTabVisited(1))
                const DecksView(showBottomNav: false)
              else
                const SizedBox.shrink(),
              if (controller.isTabVisited(2))
                const SettingsView(showBottomNav: false)
              else
                const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: controller.navIndex.value,
            onDestinationSelected: controller.selectTab,
          ),
        );
      }),
    );
  }
}
