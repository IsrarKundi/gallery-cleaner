import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';

/// In-app notification permission sheet (fix plan Stage 1;
/// Cleanup's permission-priming pattern — teardown
/// notes/retention.md §1.2 — in wipe.'s own words and the
/// Settings sheet shape): a title, a one-line benefit, and the
/// two choices. Shown before the bare system popup, only when
/// the user turns reminders on while the system permission is
/// not yet granted.
///
/// Returns true only when the user taps the primary action;
/// "Not now" and dismissing the sheet both ask nothing.
class ReminderPermissionSheet {
  ReminderPermissionSheet._();

  static Future<bool> show(BuildContext context) async {
    final bool? result = await showModalBottomSheet<bool>(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: context.sizes.sm,
                    bottom: context.sizes.sm,
                  ),
                  child: Text(
                    AppStrings.tr(AppStrings.settingsNotificationsTitle),
                    style: context.textStyles.titleMedium,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: context.sizes.sm,
                    bottom: context.sizes.lg,
                  ),
                  child: Text(
                    AppStrings.tr(AppStrings.reminderPermissionBenefit),
                    style: context.textStyles.bodyLarge,
                  ),
                ),
                PrimaryButton(
                  label: AppStrings.tr(AppStrings.reminderPermissionTurnOn),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                SizedBox(height: context.sizes.sm),
                SecondaryButton(
                  label: AppStrings.tr(AppStrings.reminderPermissionNotNow),
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
