import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../controller/review_controller.dart';
import '../../../services/media/media_asset.dart';

/// One cell of the review grid: the photo thumbnail with a delete-mark
/// badge. Photos are always shown revealed (owner decision 26 Oct
/// 2026: no blur, no tap-to-reveal).
///
/// Outside selection mode, tapping unmarks the photo (it leaves the
/// grid and returns to the deck as undecided). In selection mode
/// (entered by long-press or the header's Select button), tapping
/// toggles selection instead, and a checkbox marks the state:
/// filled check when selected, outlined circle when not (design.md
/// §9: selection always carries checkmark + border, never colour
/// alone). A failed thumbnail shows placeholder art, never a stale
/// image.
///
/// Phase 3.3: pending tiles use a static placeholder (no per-tile
/// shimmer), and a failed tile with [onRetry] shows a retry button
/// — tapping the tile itself still unmarks (or toggles).
class ReviewGridTile extends StatelessWidget {
  const ReviewGridTile({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onTap,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
    this.onRetry,
  });

  final MediaAsset asset;
  final Uint8List? thumbnail;
  final bool thumbnailFailed;
  final VoidCallback onTap;

  /// True when this tile is selected in selection mode.
  final bool selected;

  /// True while the grid is in selection mode (checkbox shown).
  final bool selectionMode;

  /// Long-press handler (enters selection mode / toggles in mode).
  final VoidCallback? onLongPress;

  /// Called by the retry button on a failed tile. Null hides the
  /// button (the tile still shows placeholder art).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
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
    // Phase 3B accessibility (design.md §9): a photo tile with no
    // text gave TalkBack nothing to announce. The label names the
    // photo (or "Photo" untitled) and its action; in selection
    // mode it also announces the selected state.
    final String label = asset.title.isEmpty
        ? AppStrings.tr(AppStrings.a11yReviewTileUntitled)
        : AppStrings.tr(AppStrings.a11yReviewTile, <String, String>{
            'name': asset.title,
          });
    final String semanticsLabel = selected
        ? '$label, ${AppStrings.tr(AppStrings.a11ySelected)}'
        : label;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          button: true,
          label: semanticsLabel,
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: selected
                    ? context.palette.primary
                    : context.palette.border.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              // borderRadius: BorderRadius.circular(context.sizes.radiusMd - 1),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    image,
                    if (selectionMode)
                      Positioned(
                        top: context.sizes.xs,
                        left: context.sizes.xs,
                        child: Container(
                          width: context.sizes.iconMd,
                          height: context.sizes.iconMd,
                          decoration: BoxDecoration(
                            color: selected
                                ? context.palette.primary
                                : context.palette.scrim.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: selected
                              ? Icon(
                                  AppIcons.check,
                                  size: context.sizes.md,
                                  color: context.palette.onPrimary,
                                )
                              : null,
                        ),
                      ),

                    // Positioned(
                    //   top: context.sizes.xs,
                    //   right: context.sizes.xs,
                    //   child: Container(
                    //     padding: const EdgeInsets.all(5),
                    //     decoration: BoxDecoration(
                    //       color: context.palette.error,
                    //       shape: BoxShape.circle,
                    //       border: Border.all(color: Colors.white, width: 1.5),
                    //       boxShadow: const <BoxShadow>[
                    //         BoxShadow(
                    //           color: Colors.black26,
                    //           blurRadius: 4,
                    //           offset: Offset(0, 1),
                    //         ),
                    //       ],
                    //     ),
                    //     child: Icon(
                    //       AppIcons.delete,
                    //       size: context.sizes.md,
                    //       color: context.palette.onPrimary,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Outside the tile's Semantics (which excludes children)
        // so TalkBack can reach it as its own action. Tapping it
        // retries the fetch; it does not unmark the tile. In
        // selection mode it moves to the bottom-left so it never
        // covers the top-left selection checkbox.
        if (thumbnailFailed && onRetry != null)
          Positioned(
            top: selectionMode ? null : context.sizes.xs,
            bottom: selectionMode ? context.sizes.xs : null,
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
