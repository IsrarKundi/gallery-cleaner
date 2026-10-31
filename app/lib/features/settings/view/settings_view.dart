import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../services/local/local_service.dart';
import '../controller/settings_controller.dart';

/// Redesigned settings screen matching modern grouped-card aesthetics.
///
/// Layout + Obx only. Persistence and application live in [SettingsController].
/// Sections:
/// - Preferences: Themes (modal picker), Notifications (toggle), Sound & Haptics (toggle)
/// - Privacy & Security: Privacy Policy, Terms of Service
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key, this.showBottomNav = true});

  /// The shell renders the one bottom nav, so shell tabs hide their own.
  /// Standalone use keeps the nav.
  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return AppScaffold(
        title: AppStrings.tr(AppStrings.screenSettings),
        bottomNav: showBottomNav ? const AppBottomNav(currentIndex: 3) : null,
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.screenPadding,
            vertical: 0,
          ),
          children: <Widget>[
            if (controller.errorKey.value.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: context.sizes.md),
                child: ErrorBanner(
                  message: AppStrings.tr(controller.errorKey.value),
                  onDismiss: () => controller.errorKey.value = '',
                ),
              ),
            _SectionLabel(
              title: AppStrings.tr(AppStrings.settingsSectionPreferences),
            ),
            _SettingsCard(
              children: <Widget>[
                _SettingsTile(
                  icon: AppIcons.palette,
                  title: AppStrings.tr(AppStrings.settingsThemes),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppStrings.tr(switch (controller.theme) {
                          ThemePreference.system =>
                            AppStrings.settingsThemeSystem,
                          ThemePreference.light =>
                            AppStrings.settingsThemeLight,
                          ThemePreference.dark => AppStrings.settingsThemeDark,
                        }),
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      SizedBox(width: context.sizes.xs),
                      Icon(
                        AppIcons.forward,
                        size: 16,
                        color: context.palette.textSecondary,
                      ),
                    ],
                  ),
                  onTap: () => _showThemePicker(context, controller),
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: AppIcons.bell,
                  title: AppStrings.tr(AppStrings.settingsNotifications),
                  trailing: Switch.adaptive(
                    value: controller.reminders,
                    activeThumbColor: context.palette.primary,
                    activeTrackColor: context.palette.primaryContainer,
                    onChanged: (bool value) =>
                        _onRemindersToggled(controller, value),
                  ),
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: AppIcons.waveform,
                  title: AppStrings.tr(AppStrings.settingsSoundHaptics),
                  trailing: Switch.adaptive(
                    value: controller.haptics,
                    activeThumbColor: context.palette.primary,
                    activeTrackColor: context.palette.primaryContainer,
                    onChanged: controller.setHaptics,
                  ),
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: AppIcons.clean,
                  title: AppStrings.tr(AppStrings.settingsSwipeDirections),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppStrings.tr(switch (controller.swipeDirections) {
                          SwipeDirections.rightKeepLeftDelete =>
                            AppStrings.settingsSwipeRightKeepShort,
                          SwipeDirections.rightDeleteLeftKeep =>
                            AppStrings.settingsSwipeRightDeleteShort,
                        }),
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      SizedBox(width: context.sizes.xs),
                      Icon(
                        AppIcons.forward,
                        size: 16,
                        color: context.palette.textSecondary,
                      ),
                    ],
                  ),
                  onTap: () => _showSwipeDirectionsPicker(context, controller),
                ),
              ],
            ),
            SizedBox(height: context.sizes.xxl),
            _SectionLabel(
              title: AppStrings.tr(AppStrings.settingsSectionPrivacySecurity),
            ),
            _SettingsCard(
              children: <Widget>[
                _SettingsTile(
                  icon: AppIcons.shield,
                  title: AppStrings.tr(AppStrings.settingsPrivacyPolicy),
                  trailing: Icon(
                    AppIcons.forward,
                    size: 16,
                    color: context.palette.textSecondary,
                  ),
                  onTap: () {},
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: AppIcons.fileText,
                  title: AppStrings.tr(AppStrings.settingsTermsOfService),
                  trailing: Icon(
                    AppIcons.forward,
                    size: 16,
                    color: context.palette.textSecondary,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Reminders toggle: both directions go straight to the
  /// controller. Turning ON is the user's own deliberate action
  /// on this screen, so the controller requests the system
  /// permission directly — no in-app benefit sheet in between
  /// (owner decision 31 Oct 2026, ADR-016 addendum: a priming
  /// sheet only makes sense for an ask the user did not start).
  Future<void> _onRemindersToggled(
    SettingsController controller,
    bool value,
  ) async {
    await controller.setReminders(value);
  }

  void _showThemePicker(BuildContext context, SettingsController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizes.radiusSheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sizes.lg,
              horizontal: context.sizes.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: context.sizes.sm,
                    bottom: context.sizes.sm,
                  ),
                  child: Text(
                    AppStrings.tr(AppStrings.settingsThemes),
                    style: context.textStyles.titleMedium,
                  ),
                ),
                for (final ThemePreference option in ThemePreference.values)
                  ListTile(
                    title: Text(
                      AppStrings.tr(switch (option) {
                        ThemePreference.system =>
                          AppStrings.settingsThemeSystem,
                        ThemePreference.light => AppStrings.settingsThemeLight,
                        ThemePreference.dark => AppStrings.settingsThemeDark,
                      }),
                      style: context.textStyles.bodyLarge,
                    ),
                    trailing: controller.theme == option
                        ? Icon(
                            AppIcons.check,
                            color: context.palette.primary,
                            size: context.sizes.iconMd,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.sizes.radiusMd,
                      ),
                    ),
                    onTap: () {
                      controller.setTheme(option);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSwipeDirectionsPicker(
    BuildContext context,
    SettingsController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizes.radiusSheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sizes.lg,
              horizontal: context.sizes.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: context.sizes.sm,
                    bottom: context.sizes.sm,
                  ),
                  child: Text(
                    AppStrings.tr(AppStrings.settingsSwipeDirections),
                    style: context.textStyles.titleMedium,
                  ),
                ),
                for (final SwipeDirections option in SwipeDirections.values)
                  ListTile(
                    title: Text(
                      AppStrings.tr(switch (option) {
                        SwipeDirections.rightKeepLeftDelete =>
                          AppStrings.settingsSwipeRightKeep,
                        SwipeDirections.rightDeleteLeftKeep =>
                          AppStrings.settingsSwipeRightDelete,
                      }),
                      style: context.textStyles.bodyLarge,
                    ),
                    trailing: controller.swipeDirections == option
                        ? Icon(
                            AppIcons.check,
                            color: context.palette.primary,
                            size: context.sizes.iconMd,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.sizes.radiusMd,
                      ),
                    ),
                    onTap: () {
                      controller.setSwipeDirections(option);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.sizes.xs,
        bottom: context.sizes.sm,
      ),
      child: Text(
        title,
        style: context.textStyles.bodyMedium.copyWith(
          color: context.palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceVariant,
        borderRadius: BorderRadius.circular(context.sizes.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: context.sizes.listRowMin),
        padding: EdgeInsets.symmetric(
          horizontal: context.sizes.cardPadding,
          vertical: context.sizes.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: context.sizes.iconMd,
              color: context.palette.textSecondary,
            ),
            SizedBox(width: context.sizes.md),
            Expanded(
              child: Text(
                title,
                style: context.textStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent:
          context.sizes.cardPadding + context.sizes.iconMd + context.sizes.md,
      endIndent: 0,
      color: context.palette.border.withValues(alpha: 0.25),
    );
  }
}
