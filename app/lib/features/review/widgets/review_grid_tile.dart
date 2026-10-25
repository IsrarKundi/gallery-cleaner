import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/media/media_asset.dart';

/// One cell of the review grid: the photo thumbnail with a delete-mark
/// badge. Tapping unmarks the photo (it leaves the grid and returns
/// to the deck as undecided). A failed thumbnail shows placeholder
/// art, never a stale image.
class ReviewGridTile extends StatelessWidget {
  const ReviewGridTile({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onTap,
  });

  final MediaAsset asset;
  final Uint8List? thumbnail;
  final bool thumbnailFailed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (thumbnail != null)
              Image.memory(thumbnail, fit: BoxFit.cover)
            else
              Container(
                color: context.palette.surfaceVariant,
                child: Icon(
                  AppIcons.photos,
                  size: context.sizes.iconLg,
                  color: context.palette.textSecondary,
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
