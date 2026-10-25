import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../services/media/media_asset.dart';
import '../model/timeline_grouping.dart';

/// Timeline section matching the screenshot:
/// Header ("Timeline" + "XX GB total"), year filter pills with sort button,
/// and horizontal scrolling month cards.
class TimelineSection extends StatelessWidget {
  const TimelineSection({
    super.key,
    required this.totalBytes,
    required this.years,
    required this.months,
    required this.selectedYear,
    required this.ascending,
    required this.onYearSelected,
    required this.onToggleSort,
    required this.onMonthTap,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
    this.isScanning = false,
  });

  /// Precomputed by the controller per scan page (solutions
  /// 4.3) — the widget never folds the whole library itself,
  /// so a hub rebuild costs O(months), not O(library).
  final int totalBytes;
  final List<int> years;
  final List<MonthSummary> months;
  final int selectedYear;
  final bool ascending;
  final ValueChanged<int> onYearSelected;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onMonthTap;

  /// Phase 2.3: shared thumbnail maps for the 256px month covers,
  /// plus the idempotent request callback (no per-card fetching).
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header: Timeline + Total GB
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.screenPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.tr(AppStrings.timelineTitle),
                  style: context.textStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.sizes.xs),
              Text(
                AppStrings.tr(AppStrings.timelineTotal, <String, String>{
                  'size': Formatters.formatBytes(totalBytes),
                }),
                style: context.textStyles.labelMedium.copyWith(
                  color: context.palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sizes.sm),
        // Filter Row: Sort button + Year chips
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.screenPadding,
          ),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: <Widget>[
              // Sort toggle button (matches ⇅ in pill)
              Material(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(context.sizes.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                  onTap: onToggleSort,
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
                    child: Center(
                      child: Text(
                        '⇅',
                        style: context.textStyles.labelMedium.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.sizes.xs),
              for (final int y in years) ...<Widget>[
                _YearChip(
                  year: y,
                  selected: y == selectedYear,
                  onTap: () => onYearSelected(y),
                ),
                SizedBox(width: context.sizes.xs),
              ],
            ],
          ),
        ),
        SizedBox(height: context.sizes.md),
        // Horizontal Month Cards
        if (months.isEmpty && isScanning)
          SizedBox(
            height: 180,
            child: AppSkeleton(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sizes.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, _) => SizedBox(width: context.sizes.md),
                itemBuilder: (_, _) => Bone(
                  width: 140,
                  height: 180,
                  borderRadius: BorderRadius.circular(context.sizes.radiusLg),
                ),
              ),
            ),
          )
        else if (months.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(context.sizes.radiusLg),
                border: Border.all(color: context.palette.border, width: 1),
              ),
              child: Text(
                'No photos in $selectedYear',
                style: context.textStyles.bodyMedium.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: months.length,
              separatorBuilder: (_, _) => SizedBox(width: context.sizes.md),
              itemBuilder: (BuildContext context, int index) {
                final MonthSummary month = months[index];
                return _MonthCard(
                  summary: month,
                  thumbnails: thumbnails,
                  failedThumbnails: failedThumbnails,
                  requestThumbnail: requestThumbnail,
                  onTap: () => onMonthTap(month.monthKey),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.primary : context.palette.surface,
      borderRadius: BorderRadius.circular(context.sizes.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.sizes.pill),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.lg,
            vertical: context.sizes.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.sizes.pill),
            border: Border.all(
              color: selected
                  ? context.palette.primary
                  : context.palette.border,
              width: 1,
            ),
          ),
          child: Text(
            year.toString(),
            style: context.textStyles.labelMedium.copyWith(
              color: selected ? Colors.white : context.palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 2.3: stateless month card. Renders from the shared
/// thumbnail maps; a missing, not-failed cover warms the cache
/// idempotently. Failure keeps the placeholder icon (the pre-2.3
/// behaviour).
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.summary,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
    required this.onTap,
  });

  final MonthSummary summary;
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MediaAsset? coverAsset = summary.coverAsset;
      // Always read the map — even for a month without a cover —
      // so Obx has an observable to subscribe to (GetX throws on
      // zero reads). '' is never a real asset id.
      final Uint8List? bytes = thumbnails[coverAsset?.id ?? ''];
      if (coverAsset != null &&
          bytes == null &&
          !failedThumbnails.contains(coverAsset.id)) {
        requestThumbnail(coverAsset.id);
      }
      const double cardWidth = 140;
      return Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant,
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
          border: Border.all(color: context.palette.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Cover Photo
                // Phase 1.6: decode at display size, never larger
                // than the fetched thumbnail (see decode_size.dart).
                // The card fetches at 256px (see _fetch).
                if (bytes != null)
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final int side = decodeSide(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                            sourceSize: 320,
                          );
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth: side,
                            cacheHeight: side,
                          );
                        },
                  )
                else
                  Container(
                    color: context.palette.surfaceVariant,
                    child: Center(
                      child: Icon(
                        AppIcons.photos,
                        size: context.sizes.iconLg,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ),
                // Gradient Overlay for Text Readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const <double>[0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Bottom Left: Month title + item count & size
                Positioned(
                  left: context.sizes.md,
                  right: context.sizes.md,
                  bottom: context.sizes.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        summary.monthName,
                        style: context.textStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: context.sizes.xxs),
                      Text(
                        '${summary.count} Items · ${Formatters.formatBytes(summary.totalBytes)}',
                        style: context.textStyles.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
