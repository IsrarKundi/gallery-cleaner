import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../controller/decks_controller.dart';
import '../widgets/progress_section.dart';

/// Top header for DecksView:
/// App title ("Klara") on left, storage + streak badge pill and settings button on right.
class DecksTopHeader extends StatelessWidget {
  const DecksTopHeader({
    super.key,
    required this.controller,
    required this.totalBytes,
    required this.visibleDecksCount,
    required this.readyBytes,
    required this.scanning,
  });

  final DecksController controller;
  final int totalBytes;
  final int visibleDecksCount;
  final int readyBytes;
  final bool scanning;

  void _showProgressSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizes.radiusLg),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.all(context.sizes.md),
          child: CompactProgressCard(
            goalTargetMb: controller.goalTargetMb.value,
            weekFreedMb: controller.weekFreedMbValue,
            goalProgress: controller.goalProgress,
            streakCurrent: controller.streak.current,
            streakBest: controller.streak.best,
            readyDecksCount: visibleDecksCount,
            readyBytes: readyBytes,
            freeMb: controller.freeMb.value,
            inTrashMb: controller.inTrashMb,
            isScanning: scanning,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sizes.screenPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              AppStrings.tr(AppStrings.appTitle),
              style: context.textStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
                fontSize: 26,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: context.sizes.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Metric pill: 🎯 52.6 GB · 🏆 1d
              Semantics(
                button: true,
                label: 'Storage and streak info',
                child: Material(
                  key: const Key('decks_metric_pill'),
                  color: context.palette.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(context.sizes.pill),
                    onTap: () => _showProgressSheet(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sizes.md,
                        vertical: context.sizes.xs,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(context.sizes.pill),
                        border: Border.all(
                          color: context.palette.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text('🎯', style: TextStyle(fontSize: 12)),
                          SizedBox(width: context.sizes.xxs),
                          Text(
                            Formatters.formatBytes(totalBytes),
                            style: context.textStyles.labelMedium.copyWith(
                              color: context.palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: context.textStyles.labelMedium.copyWith(
                              color: context.palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text('🏆', style: TextStyle(fontSize: 12)),
                          SizedBox(width: context.sizes.xxs),
                          Text(
                            '${controller.streak.current}d',
                            style: context.textStyles.labelMedium.copyWith(
                              color: context.palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.sizes.xs),
              // Circular Settings Button
              Material(
                color: context.palette.surfaceVariant.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Get.toNamed<dynamic>(AppRoutes.settings),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.palette.border,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        AppIcons.settings,
                        size: context.sizes.iconSm,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
