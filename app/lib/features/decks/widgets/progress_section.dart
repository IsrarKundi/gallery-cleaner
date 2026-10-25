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
        // Phase 3B accessibility (design.md §3, §9): the old Row
        // overflowed on narrow phones at the 1.30 text-scale cap
        // (three preset chips no longer fit one line). A Wrap
        // keeps every preset reachable at every scale instead of
        // clipping one off-screen.
        Wrap(
          spacing: context.sizes.sm,
          runSpacing: context.sizes.sm,
          children: <Widget>[
            for (final double preset in goalPresetsMb)
              ChoiceChip(
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

/// Clean, breathable progress card for the redesigned Smart Decks hub (matching reference design).
class CompactProgressCard extends StatelessWidget {
  const CompactProgressCard({
    super.key,
    required this.goalTargetMb,
    required this.weekFreedMb,
    required this.goalProgress,
    required this.streakCurrent,
    required this.streakBest,
    this.readyDecksCount = 0,
    this.readyBytes = 0,
    this.freeMb,
    this.inTrashMb = 0,
    this.isScanning = false,
  });

  final double goalTargetMb;
  final double weekFreedMb;
  final double goalProgress;
  final int streakCurrent;
  final int streakBest;
  final int readyDecksCount;
  final int readyBytes;
  final double? freeMb;
  final double inTrashMb;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final bool reached = goalProgress >= 1;
    final String targetStr = AppStrings.tr(
      AppStrings.retentionGoalPreset,
      <String, String>{
        'target': Formatters.formatBytes((goalTargetMb * 1048576).round()),
      },
    );
    final double clampedProgress = goalProgress.clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(context.sizes.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        border: Border.all(color: context.palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Icon + Title on left, streak on right.
          Row(
            children: <Widget>[
              Icon(
                AppIcons.goal,
                size: context.sizes.iconMd,
                color: context.palette.primary,
              ),
              SizedBox(width: context.sizes.sm),
              Text(
                AppStrings.tr(AppStrings.retentionProgressTitle),
                style: context.textStyles.titleMedium,
              ),
              const Spacer(),
              if (streakCurrent > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sizes.sm,
                    vertical: context.sizes.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(context.sizes.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        AppIcons.streak,
                        size: context.sizes.iconSm,
                        color: context.palette.primary,
                      ),
                      SizedBox(width: context.sizes.xxs),
                      Text(
                        '$streakCurrent d',
                        style: context.textStyles.labelSmall.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: context.sizes.md),
          if (readyBytes > 0)
            // Hero metric: e.g. "3.2 GB ready to review across 2 decks"
            RichText(
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: Formatters.formatBytes(readyBytes),
                    style: context.textStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' ready to review across $readyDecksCount ${readyDecksCount == 1 ? 'deck' : 'decks'}',
                    style: context.textStyles.bodyMedium.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (isScanning)
            Text(
              'Calculating space to review…',
              style: context.textStyles.titleMedium.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'All decks clean · No clutter found',
              style: context.textStyles.titleMedium.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          SizedBox(height: context.sizes.md),
          // Goal line + %
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                reached
                    ? AppStrings.tr(AppStrings.retentionGoalReached)
                    : '${Formatters.formatMb(weekFreedMb)} · $targetStr',
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: context.textStyles.labelSmall.copyWith(
                  color: context.palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sizes.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(context.sizes.pill),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 4,
              backgroundColor: context.palette.border,
            ),
          ),
          // Storage footer info
          if (freeMb != null || inTrashMb > 0) ...<Widget>[
            SizedBox(height: context.sizes.sm),
            Text(
              [
                if (freeMb != null)
                  '${Formatters.formatBytes((freeMb! * 1048576).round())} free on device',
                if (inTrashMb > 0)
                  '${Formatters.formatBytes((inTrashMb * 1048576).round())} in 30-day trash',
              ].join(' · '),
              style: context.textStyles.bodySmall.copyWith(
                color: context.palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
