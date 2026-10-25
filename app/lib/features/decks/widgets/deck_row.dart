import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/smart_deck_meta.dart';

/// Minimalist smart deck card (matching the reference design):
/// rounded surface, deck icon block, title + descriptive subtitle,
/// badge pill with size/chevron, and a visual preview strip of 3 items + overflow count.
class DeckRow extends StatelessWidget {
  const DeckRow({
    super.key,
    required this.deckId,
    required this.count,
    required this.totalBytes,
    required this.ready,
    required this.onTap,
    this.assets = const <MediaAsset>[],
    this.media,
  });

  final SmartDeckId deckId;
  final int count;
  final int totalBytes;
  final bool ready;
  final VoidCallback? onTap;
  final List<MediaAsset> assets;
  final MediaService? media;

  String _buildSubtitle() {
    if (!ready) {
      return AppStrings.tr(AppStrings.decksRowScanning);
    }
    final String countStr = Formatters.formatCount(count);
    switch (deckId) {
      case SmartDeckId.videos:
        final int largest = assets.isEmpty
            ? 0
            : assets
                  .map((MediaAsset a) => a.sizeBytes)
                  .reduce((int a, int b) => a > b ? a : b);
        return '$countStr videos · Largest: ${Formatters.formatBytes(largest)}';
      case SmartDeckId.large:
        return '$countStr photos · Over 10 MB each';
      case SmartDeckId.old:
        return '$countStr photos · Over 1 year old';
      case SmartDeckId.duplicates:
        return '$countStr photos · Identical & similar';
      case SmartDeckId.bursts:
        return '$countStr photos · Rapid series';
      case SmartDeckId.screenshots:
        return '$countStr screenshots · ${Formatters.formatBytes(totalBytes)}';
      case SmartDeckId.camera:
        return '$countStr camera photos';
      default:
        return AppStrings.tr(AppStrings.decksRowCount, <String, String>{
          'count': countStr,
          'size': Formatters.formatBytes(totalBytes),
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String subtitle = _buildSubtitle();
    final List<MediaAsset> previewAssets = assets.take(3).toList();
    final int overflow = count > 3 ? count - 3 : 0;
    final String semanticsLabel =
        '${AppStrings.tr(smartDeckTitleKey(deckId))} · '
        '${AppStrings.tr(AppStrings.decksRowCount, <String, String>{'count': Formatters.formatCount(count), 'size': Formatters.formatBytes(totalBytes)})}';

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
          border: Border.all(color: context.palette.border, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(context.sizes.radiusLg),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(context.sizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Top Row: Icon + Title/Subtitle + Badge Pill
                  Row(
                    children: <Widget>[
                      Container(
                        width: context.sizes.giant,
                        height: context.sizes.giant,
                        decoration: BoxDecoration(
                          color: context.palette.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            context.sizes.radiusMd,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            smartDeckIcon(deckId),
                            size: context.sizes.iconMd,
                            color: count > 0 && ready
                                ? context.palette.primary
                                : context.palette.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: context.sizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.tr(smartDeckTitleKey(deckId)),
                              style: context.textStyles.titleMedium,
                            ),
                            SizedBox(height: context.sizes.xxs),
                            Text(
                              subtitle,
                              style: context.textStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sizes.sm),
                      if (!ready)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.sizes.sm,
                            vertical: context.sizes.xs,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              context.sizes.pill,
                            ),
                          ),
                          child: Text(
                            'Scanning…',
                            style: context.textStyles.labelSmall.copyWith(
                              color: context.palette.textTertiary,
                            ),
                          ),
                        )
                      else if (count > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.sizes.md,
                            vertical: context.sizes.xs,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              context.sizes.pill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                Formatters.formatBytes(totalBytes),
                                style: context.textStyles.labelMedium.copyWith(
                                  color: context.palette.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: context.sizes.xxs),
                              Icon(
                                AppIcons.forward,
                                size: context.sizes.xs * 3, // 12dp
                                color: context.palette.primary,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Bottom Row: 3 preview tiles + overflow tile
                  if (previewAssets.isNotEmpty) ...<Widget>[
                    SizedBox(height: context.sizes.md),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            const int slots = 4;
                            final double spacing = context.sizes.sm;
                            final double tileWidth =
                                (constraints.maxWidth -
                                    (spacing * (slots - 1))) /
                                slots;
                            final double tileHeight = tileWidth * 0.9;

                            return Row(
                              children: <Widget>[
                                for (
                                  int i = 0;
                                  i < previewAssets.length;
                                  i++
                                ) ...<Widget>[
                                  _PreviewTile(
                                    asset: previewAssets[i],
                                    width: tileWidth,
                                    height: tileHeight,
                                    media: media,
                                    isVideo: deckId == SmartDeckId.videos,
                                  ),
                                  SizedBox(width: spacing),
                                ],
                                if (overflow > 0)
                                  Container(
                                    width: tileWidth,
                                    height: tileHeight,
                                    decoration: BoxDecoration(
                                      color: context.palette.surfaceVariant,
                                      borderRadius: BorderRadius.circular(
                                        context.sizes.radiusMd,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+$overflow',
                                        style: context.textStyles.titleMedium
                                            .copyWith(
                                              color:
                                                  context.palette.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatefulWidget {
  const _PreviewTile({
    required this.asset,
    required this.width,
    required this.height,
    required this.media,
    required this.isVideo,
  });

  final MediaAsset asset;
  final double width;
  final double height;
  final MediaService? media;
  final bool isVideo;

  @override
  State<_PreviewTile> createState() => _PreviewTileState();
}

class _PreviewTileState extends State<_PreviewTile> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _PreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _bytes = null;
      _failed = false;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final MediaService? media = widget.media;
    if (media == null) {
      return;
    }
    final result = await media.getThumbnail(widget.asset.id, 128);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (Uint8List bytes) => setState(() => _bytes = bytes),
      onFailure: (_) => setState(() => _failed = true),
    );
  }

  String _badgeLabel() {
    return Formatters.formatBytes(widget.asset.sizeBytes);
  }

  @override
  Widget build(BuildContext context) {
    // Phase 1.6: decode at display size, never larger than the
    // fetched thumbnail (see decode_size.dart). The tile fetches
    // at 128px (see _fetch).
    final int decode = decodeSide(
      width: widget.width,
      height: widget.height,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      sourceSize: 128,
    );
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.palette.surfaceVariant,
        borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_bytes != null)
            Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              cacheWidth: decode,
              cacheHeight: decode,
            )
          else if (_failed)
            Center(
              child: Icon(
                AppIcons.photos,
                size: context.sizes.iconSm,
                color: context.palette.textTertiary,
              ),
            )
          else
            Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.palette.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          // Subtle size pill at bottom left
          Positioned(
            left: context.sizes.xs,
            bottom: context.sizes.xs,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.xs,
                vertical: context.sizes.xxs,
              ),
              decoration: BoxDecoration(
                color: context.palette.scrim.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(context.sizes.xs),
              ),
              child: Text(
                _badgeLabel(),
                style: context.textStyles.labelSmall.copyWith(
                  color: context.palette.onPrimary,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
