import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
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
class ReviewGridTile extends StatelessWidget {
  const ReviewGridTile({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onTap,
    this.blurred = false,
    this.onReveal,
  });

  final MediaAsset asset;
  final Uint8List? thumbnail;
  final bool thumbnailFailed;
  final VoidCallback onTap;

  /// True when this tile must render blurred (blur ON, not revealed).
  final bool blurred;

  /// Called instead of [onTap] while [blurred] is true.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
    final bool blurred = this.blurred;
    Widget image;
    if (thumbnail != null) {
      image = Image.memory(thumbnail, fit: BoxFit.cover);
    } else {
      image = Container(
        color: context.palette.surfaceVariant,
        child: Icon(
          AppIcons.photos,
          size: context.sizes.iconLg,
          color: context.palette.textSecondary,
        ),
      );
    }
    if (blurred) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: context.sizes.privateBlurSigma,
          sigmaY: context.sizes.privateBlurSigma,
        ),
        child: image,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      child: InkWell(
        onTap: blurred ? (onReveal ?? onTap) : onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image,
            if (blurred)
              Center(
                child: Container(
                  padding: EdgeInsets.all(context.sizes.sm),
                  decoration: BoxDecoration(
                    color: context.palette.scrim,
                    borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                  ),
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
                        style: context.textStyles.labelMedium.copyWith(
                          color: context.palette.onScrim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: context.sizes.xs,
              right: context.sizes.xs,
              child: Container(
                padding: EdgeInsets.all(context.sizes.xs),
                decoration: BoxDecoration(
                  color: context.palette.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.delete,
                  size: context.sizes.iconSm,
                  color: context.palette.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
