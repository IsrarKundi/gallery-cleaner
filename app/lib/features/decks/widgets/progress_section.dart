// Phase 2B retention sections for the hub (requirements §7).
// Layout only: numbers and callbacks arrive from DecksController.
// Goal presets are the retention defaults (500 MB / 1 GB / 2 GB);
// progress is freed MB this week ONLY (never trashed, never
// marked). The projection bar shows device free storage now and
// projected free after emptying Trash; when device storage is
// unknown it shows the labelled library projection instead and
// never invents device numbers.

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../deck/model/retention.dart';

class ProgressSection extends StatelessWidget {
  const ProgressSection({
    super.key,
    required this.goalTargetMb,
    required this.weekFreedMb,
    required this.goalProgress,
    required this.streakCurrent,
    required this.streakBest,
    required this.onGoalSelected,
  });

  final double goalTargetMb;
  final double weekFreedMb;
  final double goalProgress;
  final int streakCurrent;
  final int streakBest;
  final ValueChanged<double> onGoalSelected;

  @override
  Widget build(BuildContext context) {
    final bool reached = goalProgress >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(AppIcons.goal, size: context.sizes.iconMd),
            SizedBox(width: context.sizes.sm),
            Text(
              AppStrings.tr(AppStrings.retentionProgressTitle),
              style: context.textStyles.titleMedium,
            ),
          ],
        ),
        SizedBox(height: context.sizes.sm),
        Text(
          reached
              ? AppStrings.tr(AppStrings.retentionGoalReached)
              : AppStrings.tr(
                  AppStrings.retentionGoalProgress,
                  <String, String>{
                    'freed': Formatters.formatMb(weekFreedMb),
                    'target': Formatters.formatBytes(
                      (goalTargetMb * 1048576).round(),
                    ),
                  },
                ),
          style: context.textStyles.bodyMedium,
        ),
        SizedBox(height: context.sizes.sm),
        LinearProgressIndicator(value: goalProgress),
        SizedBox(height: context.sizes.sm),
        Row(
          children: <Widget>[
            for (final double preset in goalPresetsMb)
              Padding(
                padding: EdgeInsets.only(right: context.sizes.sm),
                child: ChoiceChip(
                  label: Text(
                    AppStrings.tr(
                      AppStrings.retentionGoalPreset,
                      <String, String>{
                        'target': Formatters.formatBytes(
                          (preset * 1048576).round(),
                        ),
                      },
                    ),
                  ),
                  selected: goalTargetMb == preset,
                  onSelected: (bool selected) {
                    if (selected) {
                      onGoalSelected(preset);
                    }
                  },
                ),
              ),
          ],
        ),
        SizedBox(height: context.sizes.md),
        Row(
          children: <Widget>[
            Icon(AppIcons.streak, size: context.sizes.iconMd),
            SizedBox(width: context.sizes.sm),
            Expanded(
              child: Text(
                streakCurrent > 0
                    ? AppStrings.tr(
                        AppStrings.retentionStreak,
                        <String, String>{'count': streakCurrent.toString()},
                      )
                    : AppStrings.tr(AppStrings.retentionStreakNone),
                style: context.textStyles.bodyMedium,
              ),
            ),
          ],
        ),
        if (streakBest > 0)
          Padding(
            padding: EdgeInsets.only(top: context.sizes.xs),
            child: Text(
              AppStrings.tr(AppStrings.retentionStreakBest, <String, String>{
                'count': streakBest.toString(),
              }),
              style: context.textStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class ProjectionBar extends StatelessWidget {
  const ProjectionBar({
    super.key,
    required this.freeMb,
    required this.projectedFreeMb,
    required this.inTrashMb,
    required this.markedMb,
  });

  /// Device free storage now, or null when unknown.
  final double? freeMb;

  /// Projected free after emptying Trash, or null when unknown.
  final double? projectedFreeMb;

  /// MB in Trash (recoverable, never freed).
  final double inTrashMb;

  /// MB marked delete across sessions ("to be freed").
  final double markedMb;

  @override
  Widget build(BuildContext context) {
    final double? free = freeMb;
    final double? projected = projectedFreeMb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(AppIcons.photos, size: context.sizes.iconMd),
            SizedBox(width: context.sizes.sm),
            Text(
              AppStrings.tr(AppStrings.retentionProjectionTitle),
              style: context.textStyles.titleMedium,
            ),
          ],
        ),
        SizedBox(height: context.sizes.sm),
        if (free != null && projected != null)
          Text(
            AppStrings.tr(AppStrings.retentionProjection, <String, String>{
              'free': Formatters.formatBytes((free * 1048576).round()),
              'projected': Formatters.formatBytes(
                (projected * 1048576).round(),
              ),
            }),
            style: context.textStyles.bodyMedium,
          )
        else
          Text(
            AppStrings.tr(AppStrings.retentionProjectionLibrary),
            style: context.textStyles.bodyMedium,
          ),
        SizedBox(height: context.sizes.xs),
        Text(
          AppStrings.tr(AppStrings.retentionProjectionInTrash, <String, String>{
            'size': Formatters.formatBytes((inTrashMb * 1048576).round()),
          }),
          style: context.textStyles.bodySmall.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        Text(
          AppStrings.tr(AppStrings.retentionProjectionMarked, <String, String>{
            'size': Formatters.formatBytes((markedMb * 1048576).round()),
          }),
          style: context.textStyles.bodySmall.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
