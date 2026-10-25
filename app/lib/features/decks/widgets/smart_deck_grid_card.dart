import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/smart_deck_meta.dart';

/// 2x2 Grid card for Smart Decks section (matching screenshot):
/// 2x2 thumbnail preview grid with overflow tile and video badge,
/// followed by title and total size below.
class SmartDeckGridCard extends StatelessWidget {
  const SmartDeckGridCard({
    super.key,
    required this.deckId,
    required this.count,
    required this.totalBytes,
    required this.assets,
    required this.onTap,
    this.media,
  });

  final SmartDeckId deckId;
  final int count;
  final int totalBytes;
  final List<MediaAsset> assets;
  final VoidCallback onTap;
  final MediaService? media;

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 158;
    const double cardHeight = 158;
    final int overflow = count > 3 ? count - 3 : 0;
    final List<MediaAsset> previews = assets.take(3).toList();

    return Semantics(
      button: true,
      label:
          '${AppStrings.tr(smartDeckTitleKey(deckId))} · ${Formatters.formatBytes(totalBytes)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 2x2 Container
              Container(
                width: cardWidth,
                height: cardHeight,
                padding: EdgeInsets.all(context.sizes.sm),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(context.sizes.radiusLg),
                  border: Border.all(color: context.palette.border, width: 1),
                ),
                child: Column(
                  children: <Widget>[
                    // Top Row: 2 items
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _GridSlot(
                              asset: previews.isNotEmpty ? previews[0] : null,
                              media: media,
                              isVideo: deckId == SmartDeckId.videos,
                            ),
                          ),
                          SizedBox(width: context.sizes.xs),
                          Expanded(
                            child: _GridSlot(
                              asset: previews.length > 1 ? previews[1] : null,
                              media: media,
                              isVideo: deckId == SmartDeckId.videos,
                              showVideoBadge: deckId == SmartDeckId.videos,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.sizes.xs),
                    // Bottom Row: 1 item + overflow (or 2 items)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _GridSlot(
                              asset: previews.length > 2 ? previews[2] : null,
                              media: media,
                              isVideo: deckId == SmartDeckId.videos,
                            ),
                          ),
                          SizedBox(width: context.sizes.xs),
                          Expanded(
                            child: overflow > 0
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: context.palette.surfaceVariant,
                                      borderRadius: BorderRadius.circular(
                                        context.sizes.radiusMd,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+$overflow',
                                        style: context.textStyles.labelLarge
                                            .copyWith(
                                              color: context.palette.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  )
                                : _GridSlot(
                                    asset: assets.length > 3 ? assets[3] : null,
                                    media: media,
                                    isVideo: deckId == SmartDeckId.videos,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sizes.xs),
              // Title below card
              Text(
                AppStrings.tr(smartDeckTitleKey(deckId)),
                style: context.textStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: context.sizes.xxs),
              // Size below title
              Text(
                Formatters.formatBytes(totalBytes),
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridSlot extends StatefulWidget {
  const _GridSlot({
    required this.asset,
    required this.media,
    required this.isVideo,
    this.showVideoBadge = false,
  });

  final MediaAsset? asset;
  final MediaService? media;
  final bool isVideo;
  final bool showVideoBadge;

  @override
  State<_GridSlot> createState() => _GridSlotState();
}

class _GridSlotState extends State<_GridSlot> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _GridSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset?.id != widget.asset?.id) {
      _bytes = null;
      _fetch();
    }
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
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceVariant,
        borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_bytes != null)
            // Phase 1.6: decode at display size, never larger than
            // the fetched thumbnail (see decode_size.dart). The
            // slot fetches at 128px (see _fetch).
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int side = decodeSide(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  sourceSize: 128,
                );
                return Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  cacheWidth: side,
                  cacheHeight: side,
                );
              },
            )
          else
            Container(color: context.palette.surfaceVariant),
          // Video Pill Badge (top right of video slot)
          if (widget.showVideoBadge)
            Positioned(
              top: context.sizes.xxs,
              right: context.sizes.xxs,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sizes.xxs * 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.palette.primary,
                  borderRadius: BorderRadius.circular(context.sizes.xs),
                ),
                child: Text(
                  AppStrings.tr(AppStrings.videoBadge),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
