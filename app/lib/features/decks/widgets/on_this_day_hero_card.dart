import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../services/media/media_asset.dart';

/// Hero banner card for "ON THIS DAY" with fanned preview cards (matching screenshot).
class OnThisDayHeroCard extends StatelessWidget {
  const OnThisDayHeroCard({
    super.key,
    required this.assets,
    required this.onTap,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
  });

  final List<MediaAsset> assets;
  final VoidCallback onTap;

  /// Phase 2.3: shared thumbnail maps for the 320px fanned cards (solutions 3.1 grid standard),
  /// plus the idempotent request callback (no per-card fetching).
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;

  static const List<Color> _fallbackPastels = <Color>[
    Color(0xFFFBCFE8), // soft pink
    Color(0xFFFEF08A), // soft yellow
    Color(0xFFBBF7D0), // soft green
    Color(0xFFBFDBFE), // soft blue
    Color(0xFFE9D5FF), // soft purple
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String monthStr = Formatters.formatFullMonth(now.month).toUpperCase();
    final int count = assets.length;
    final String subtitle = '$monthStr · $count PHOTOS TO REVIEW';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.palette.primary,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        // boxShadow: <BoxShadow>[
        //   BoxShadow(
        //     color: context.palette.primary.withValues(alpha: 0.25),
        //     blurRadius: 16,
        //     offset: const Offset(0, 6),
        //   ),
        // ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.md,
              vertical: context.sizes.lg,
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'ON THIS DAY',
                  style: context.textStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: context.sizes.xxs),
                Text(
                  subtitle,
                  style: context.textStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: context.sizes.md),
                // Fanned Cards Visual
                SizedBox(
                  height: 100,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        for (int i = 0; i < 5; i++)
                          _FannedCard(
                            index: i - 2, // -2, -1, 0, 1, 2
                            asset: i < assets.length ? assets[i] : null,
                            fallbackColor:
                                _fallbackPastels[i % _fallbackPastels.length],
                            thumbnails: thumbnails,
                            failedThumbnails: failedThumbnails,
                            requestThumbnail: requestThumbnail,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 2.3: stateless fanned card. Renders from the shared
/// thumbnail maps; a missing, not-failed id warms the cache
/// idempotently. Failure keeps the pastel fallback (the pre-2.3
/// behaviour — no failed icon here).
class _FannedCard extends StatelessWidget {
  const _FannedCard({
    required this.index,
    required this.asset,
    required this.fallbackColor,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
  });

  final int index;
  final MediaAsset? asset;
  final Color fallbackColor;
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MediaAsset? cardAsset = asset;
      // Always read the map — even for a missing fan card — so Obx
      // has an observable to subscribe to (GetX throws on zero reads).
      final Uint8List? bytes = thumbnails[cardAsset?.id ?? ''];
      if (cardAsset != null &&
          bytes == null &&
          !failedThumbnails.contains(cardAsset.id)) {
        requestThumbnail(cardAsset.id);
      }
      const double cardWidth = 58;
      const double cardHeight = 84;
      // Phase 1.6: decode at display size, never larger than the
      // fetched thumbnail (see decode_size.dart). The card reads
      // the 320px shared map (solutions 3.1 grid standard).
      final int decode = decodeSide(
        width: cardWidth,
        height: cardHeight,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        sourceSize: 320,
      );
      final double angle = index * 0.08;
      final double xOffset = index * 26.0;
      final double yOffset = (index.abs()) * 3.5;

      return Transform.translate(
        offset: Offset(xOffset, yOffset),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: fallbackColor,
              borderRadius: BorderRadius.circular(context.sizes.radiusMd),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: decode,
                    cacheHeight: decode,
                  )
                : null,
          ),
        ),
      );
    });
  }
}

class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Bone(
        width: double.infinity,
        height: 180,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
      ),
    );
  }
}
