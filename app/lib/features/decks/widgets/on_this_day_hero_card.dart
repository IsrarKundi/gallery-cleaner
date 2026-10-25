import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';

/// Hero banner card for "ON THIS DAY" with fanned preview cards (matching screenshot).
class OnThisDayHeroCard extends StatelessWidget {
  const OnThisDayHeroCard({
    super.key,
    required this.assets,
    required this.onTap,
    this.media,
  });

  final List<MediaAsset> assets;
  final VoidCallback onTap;
  final MediaService? media;

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
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.palette.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                            media: media,
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

class _FannedCard extends StatefulWidget {
  const _FannedCard({
    required this.index,
    required this.asset,
    required this.fallbackColor,
    required this.media,
  });

  final int index;
  final MediaAsset? asset;
  final Color fallbackColor;
  final MediaService? media;

  @override
  State<_FannedCard> createState() => _FannedCardState();
}

class _FannedCardState extends State<_FannedCard> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final asset = widget.asset;
    final media = widget.media;
    if (asset == null || media == null) return;
    final res = await media.getThumbnail(asset.id, 128);
    if (!mounted) return;
    res.fold(
      onSuccess: (bytes) => setState(() => _bytes = bytes),
      onFailure: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 58;
    const double cardHeight = 84;
    final double angle = widget.index * 0.08;
    final double xOffset = widget.index * 26.0;
    final double yOffset = (widget.index.abs()) * 3.5;

    return Transform.translate(
      offset: Offset(xOffset, yOffset),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: widget.fallbackColor,
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
          child: _bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.cover)
              : null,
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for the Hero Card.
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
