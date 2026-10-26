import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_icons.dart';
import '../routes/app_routes.dart';
import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import 'app_svg_icon.dart';

/// App bottom navigation bar (design.md §6).
///
/// 4 destinations:
/// 0: Clean (DeckView)
/// 1: Albums (DecksView)
/// 2: Trash (TrashView)
/// 3: Settings (SettingsView)
///
/// Material 3 NavigationBar with 24dp icons + labels and pill selection.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onDestinationSelected,
  });

  final int currentIndex;

  /// Phase 7.1: when the shell (or Review/Trash) drives navigation,
  /// taps delegate to it instead of the legacy off-all mapping
  /// below. Null keeps the legacy behaviour for standalone views
  /// and tests that pump a tab view directly.
  final void Function(int index)? onDestinationSelected;

  void _onDestinationSelected(int index) {
    if (index == currentIndex) {
      return;
    }
    final void Function(int index)? handler = onDestinationSelected;
    if (handler != null) {
      handler(index);
      return;
    }
    switch (index) {
      case 0:
        Get.offAllNamed<dynamic>(AppRoutes.deck);
      case 1:
        Get.offAllNamed<dynamic>(AppRoutes.decks);
      case 2:
        Get.offAllNamed<dynamic>(AppRoutes.review);
      case 3:
        Get.offAllNamed<dynamic>(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colours match what NavigationBar gave the old font icons:
    // selected = onSecondaryContainer, unselected = onSurfaceVariant.
    Color navColor(int index) => index == currentIndex
        ? context.palette.textPrimary
        : context.palette.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(
          top: BorderSide(color: context.palette.border, width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: context.palette.surface,
        indicatorColor: context.palette.primaryContainer,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: AppSvgIcon(
              asset: AppIcons.navCleanAsset,
              size: context.sizes.iconMd,
              color: navColor(0),
            ),
            label: AppStrings.tr(AppStrings.navClean),
          ),
          NavigationDestination(
            icon: AppSvgIcon(
              asset: AppIcons.navAlbumsAsset,
              size: context.sizes.iconMd,
              color: navColor(1),
            ),
            label: AppStrings.tr(AppStrings.navDecks),
          ),
          NavigationDestination(
            icon: AppSvgIcon(
              asset: AppIcons.navTrashAsset,
              size: context.sizes.iconMd,
              color: navColor(2),
            ),
            label: AppStrings.tr(AppStrings.navTrash),
          ),
          NavigationDestination(
            icon: AppSvgIcon(
              asset: AppIcons.navSettingsAsset,
              size: context.sizes.iconMd,
              color: navColor(3),
            ),
            label: AppStrings.tr(AppStrings.navSettings),
          ),
        ],
      ),
    );
  }
}
