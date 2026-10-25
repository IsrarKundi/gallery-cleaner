import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/timeline_grouping.dart';

/// Timeline section matching the screenshot:
/// Header ("Timeline" + "XX GB total"), year filter pills with sort button,
/// and horizontal scrolling month cards.
class TimelineSection extends StatelessWidget {
  const TimelineSection({
    super.key,
    required this.assets,
    required this.selectedYear,
    required this.ascending,
    required this.onYearSelected,
    required this.onToggleSort,
    required this.onMonthTap,
    this.media,
    this.isScanning = false,
  });

  final List<MediaAsset> assets;
  final int selectedYear;
  final bool ascending;
  final ValueChanged<int> onYearSelected;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onMonthTap;
  final MediaService? media;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final int totalBytes = assets.fold<int>(
      0,
      (int s, MediaAsset a) => s + a.sizeBytes,
    );
    final List<int> years = availableYearsFor(assets);
    final List<MonthSummary> months = groupAssetsByMonth(
      assets: assets,
      targetYear: selectedYear,
      ascending: ascending,
    );

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
                  media: media,
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

class _MonthCard extends StatefulWidget {
  const _MonthCard({
    required this.summary,
    required this.media,
    required this.onTap,
  });

  final MonthSummary summary;
  final MediaService? media;
  final VoidCallback onTap;

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _MonthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.monthKey != widget.summary.monthKey) {
      _bytes = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final MediaAsset? asset = widget.summary.coverAsset;
    final MediaService? media = widget.media;
    if (asset == null || media == null) return;
    final result = await media.getThumbnail(asset.id, 256);
    if (!mounted) return;
    result.fold(
      onSuccess: (bytes) => setState(() => _bytes = bytes),
      onFailure: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onTap: widget.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Cover Photo
              if (_bytes != null)
                Image.memory(_bytes!, fit: BoxFit.cover)
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
                      widget.summary.monthName,
                      style: context.textStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: context.sizes.xxs),
                    Text(
                      '${widget.summary.count} Items · ${Formatters.formatBytes(widget.summary.totalBytes)}',
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
  }
}
