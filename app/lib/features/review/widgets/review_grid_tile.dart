import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../controller/review_controller.dart';
import '../../../services/media/media_asset.dart';

/// One cell of the review grid: the photo thumbnail with a delete-mark
/// badge. Tapping unmarks the photo (it leaves the grid and returns
/// to the deck as undecided). A failed thumbnail shows placeholder
/// art, never a stale image.
///
/// Phase 3A private blur: when [blurred] is true the thumbnail
/// renders through an [ImageFiltered] blur (sigma from AppSizes, so
/// the subject is not recognisable at grid size) with a tap-to-reveal
/// affordance; tapping calls [onReveal] instead of [onTap]. Once
/// revealed, the tile behaves exactly as before until blur is
/// toggled or the screen is left.
///
/// Phase 3.3: the blur filter is one shared instance (the old code
/// allocated a new ImageFilter per tile per build), pending tiles
/// use a static placeholder (no per-tile shimmer), and a failed
/// tile with [onRetry] shows a retry button — tapping the tile
/// itself still unmarks.
class ReviewGridTile extends StatelessWidget {
  const ReviewGridTile({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onTap,
    this.blurred = false,
    this.onReveal,
    this.onRetry,
  });

  final MediaAsset asset;
  final Uint8List? thumbnail;
  final bool thumbnailFailed;
  final VoidCallback onTap;

  /// True when this tile must render blurred (blur ON, not revealed).
  final bool blurred;

  /// Called instead of [onTap] while [blurred] is true.
  final VoidCallback? onReveal;

  /// Called by the retry button on a failed tile. Null hides the
  /// button (the tile still shows placeholder art).
  final VoidCallback? onRetry;

  static final ImageFilter _blurFilter = ImageFilter.blur(
    sigmaX: const AppSizes().privateBlurSigma,
    sigmaY: const AppSizes().privateBlurSigma,
  );

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
    final bool blurred = this.blurred;
    Widget image;
    if (thumbnail != null) {
      // Phase 1.6: decode at display size, never larger than the
      // fetched thumbnail (see decode_size.dart).
      image = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int side = decodeSide(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            sourceSize: ReviewController.thumbnailSize,
          );
          return Image.memory(
            thumbnail,
            fit: BoxFit.cover,
            cacheWidth: side,
            cacheHeight: side,
          );
        },
      );
    } else if (thumbnailFailed) {
      image = Container(
        color: context.palette.surfaceVariant,
        child: Icon(
          AppIcons.photos,
          size: context.sizes.iconLg,
          color: context.palette.textSecondary,
        ),
      );
    } else {
      image = Container(color: context.palette.surfaceVariant);
    }
    if (blurred) {
      image = ImageFiltered(imageFilter: _blurFilter, child: image);
    }
    // Phase 3B accessibility (design.md §9): a photo tile with no
    // text gave TalkBack nothing to announce. The label names the
    // photo (or "Photo" untitled) and its action; while blurred,
    // the tap-to-reveal text below is the visible affordance and
    // the label still describes the tile's action.
    final String label = asset.title.isEmpty
        ? AppStrings.tr(AppStrings.a11yReviewTileUntitled)
        : AppStrings.tr(AppStrings.a11yReviewTile, <String, String>{
            'name': asset.title,
          });
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.sizes.radiusMd),
              border: Border.all(
                color: context.palette.border.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.sizes.radiusMd - 1),
              child: InkWell(
                onTap: blurred ? (onReveal ?? onTap) : onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    image,
                    if (blurred)
                      Positioned.fill(
                        child: Container(
                          color: context.palette.scrim.withValues(alpha: 0.45),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  AppIcons.eye,
                                  size: context.sizes.iconMd,
                                  color: context.palette.onScrim,
                                ),
                                SizedBox(height: context.sizes.xs),
                                Text(
                                  AppStrings.tr(AppStrings.blurTapToReveal),
                                  style: context.textStyles.labelSmall.copyWith(
                                    color: context.palette.onScrim,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: context.sizes.xs,
                      right: context.sizes.xs,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: context.palette.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          AppIcons.delete,
                          size: context.sizes.md,
                          color: context.palette.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Outside the tile's Semantics (which excludes children)
        // so TalkBack can reach it as its own action. Tapping it
        // retries the fetch; it does not unmark the tile.
        if (thumbnailFailed && onRetry != null)
          Positioned(
            top: context.sizes.xs,
            left: context.sizes.xs,
            child: Container(
              decoration: BoxDecoration(
                color: context.palette.scrim.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onRetry,
                icon: Icon(AppIcons.retry, color: context.palette.onScrim),
                iconSize: context.sizes.iconMd,
                tooltip: AppStrings.tr(AppStrings.errorRetry),
              ),
            ),
          ),
      ],
    );
  }
}
