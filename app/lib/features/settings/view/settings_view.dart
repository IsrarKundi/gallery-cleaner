// Settings screen (Phase 3A, requirements §7).
//
// Layout + Obx only: persistence, theme application, nudge
// scheduling and haptics gating live in [SettingsController].
// Sections: Appearance (theme), Privacy (private blur,
// protection), Feedback (weekly nudge, haptics, reduced motion),
// Trash (auto-empty prompt — see the trust-rule resolution in
// AppSettings: it only prompts, it never silently deletes), About
// (app name, runtime version, trust-flow note).
//
// Every toggle is a SwitchListTile at a 48dp hit area; the theme
// picker is three radio rows. No row is a dead button: every
// control persists and applies immediately.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/local/local_service.dart';
import '../controller/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return AppScaffold(
        title: AppStrings.tr(AppStrings.screenSettings),
        bottomNav: const AppBottomNav(currentIndex: 3),
        body: ListView(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          children: <Widget>[
            if (controller.errorKey.value.isNotEmpty)
              ErrorBanner(
                message: AppStrings.tr(controller.errorKey.value),
                onDismiss: () => controller.errorKey.value = '',
              ),
            SectionHeader(
              title: AppStrings.tr(AppStrings.settingsSectionDisplay),
            ),
            _ThemePicker(controller: controller),
            SectionHeader(
              title: AppStrings.tr(AppStrings.settingsSectionPrivacy),
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsPrivateBlurTitle),
              message: AppStrings.tr(AppStrings.settingsPrivateBlurMessage),
              value: controller.privateBlur,
              onChanged: controller.setPrivateBlur,
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsProtectionTitle),
              message: AppStrings.tr(AppStrings.settingsProtectionMessage),
              value: controller.protection,
              onChanged: controller.setProtection,
            ),
            SectionHeader(
              title: AppStrings.tr(AppStrings.settingsSectionFeedback),
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsNotificationsTitle),
              message: AppStrings.tr(AppStrings.settingsNotificationsMessage),
              value: controller.weeklyNudge,
              onChanged: controller.setWeeklyNudge,
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsHapticsTitle),
              message: AppStrings.tr(AppStrings.settingsHapticsMessage),
              value: controller.haptics,
              onChanged: controller.setHaptics,
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsReducedMotionTitle),
              message: AppStrings.tr(AppStrings.settingsReducedMotionMessage),
              value: controller.reducedMotion,
              onChanged: controller.setReducedMotion,
            ),
            SectionHeader(
              title: AppStrings.tr(AppStrings.settingsSectionTrash),
            ),
            _ToggleRow(
              title: AppStrings.tr(AppStrings.settingsAutoEmptyTitle),
              message: AppStrings.tr(AppStrings.settingsAutoEmptyMessage),
              value: controller.trashAutoEmptyPrompt,
              onChanged: controller.setTrashAutoEmptyPrompt,
            ),
            SectionHeader(
              title: AppStrings.tr(AppStrings.settingsSectionAbout),
            ),
            ListTile(
              title: Text(AppStrings.tr(AppStrings.appTitle)),
              subtitle: Text(controller.version.value),
            ),
            Padding(
              padding: EdgeInsets.only(top: context.sizes.sm),
              child: Text(
                AppStrings.tr(AppStrings.settingsTrustNote),
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Theme picker: System (default, follows the OS), Light, Dark.
/// The controller applies the choice via Get.changeThemeMode the
/// moment it is picked — no restart, no Apply button.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.tr(AppStrings.settingsThemeTitle),
          style: context.textStyles.titleMedium,
        ),
        RadioGroup<ThemePreference>(
          groupValue: controller.theme,
          onChanged: (ThemePreference? value) {
            if (value != null) {
              controller.setTheme(value);
            }
          },
          child: Column(
            children: <Widget>[
              for (final ThemePreference option in ThemePreference.values)
                RadioListTile<ThemePreference>(
                  title: Text(
                    AppStrings.tr(switch (option) {
                      ThemePreference.system => AppStrings.settingsThemeSystem,
                      ThemePreference.light => AppStrings.settingsThemeLight,
                      ThemePreference.dark => AppStrings.settingsThemeDark,
                    }),
                  ),
                  value: option,
                  activeColor: context.palette.primary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One labelled toggle with its explanation underneath, so a
/// setting's effect is never a mystery (design.md §9: meaning is
/// never carried by the switch alone).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.message,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String message;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(message),
      value: value,
      activeThumbColor: context.palette.primary,
      onChanged: onChanged,
    );
  }
}
