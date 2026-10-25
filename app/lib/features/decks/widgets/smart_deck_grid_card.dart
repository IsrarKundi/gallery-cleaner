import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/media/media_asset.dart';
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
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
  });

  final SmartDeckId deckId;
  final int count;
  final int totalBytes;
  final List<MediaAsset> assets;
  final VoidCallback onTap;

  /// Phase 2.3: shared thumbnail maps for the 320px grid slots (solutions 3.1 grid standard),
  /// plus the idempotent request callback (no per-slot fetching).
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;

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
                              thumbnails: thumbnails,
                              failedThumbnails: failedThumbnails,
                              requestThumbnail: requestThumbnail,
                              isVideo: deckId == SmartDeckId.videos,
                            ),
                          ),
                          SizedBox(width: context.sizes.xs),
                          Expanded(
                            child: _GridSlot(
                              asset: previews.length > 1 ? previews[1] : null,
                              thumbnails: thumbnails,
                              failedThumbnails: failedThumbnails,
                              requestThumbnail: requestThumbnail,
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
                              thumbnails: thumbnails,
                              failedThumbnails: failedThumbnails,
                              requestThumbnail: requestThumbnail,
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
                                    thumbnails: thumbnails,
                                    failedThumbnails: failedThumbnails,
                                    requestThumbnail: requestThumbnail,
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

/// Phase 2.3: stateless grid slot. Renders from the shared
/// thumbnail maps; a missing, not-failed id warms the cache
/// idempotently. Failure renders the same plain tile as loading
/// (the pre-2.3 behaviour — no failed icon here).
class _GridSlot extends StatelessWidget {
  const _GridSlot({
    required this.asset,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.requestThumbnail,
    required this.isVideo,
    this.showVideoBadge = false,
  });

  final MediaAsset? asset;
  final RxMap<String, Uint8List> thumbnails;
  final RxSet<String> failedThumbnails;
  final void Function(String id) requestThumbnail;
  final bool isVideo;
  final bool showVideoBadge;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MediaAsset? slotAsset = asset;
      // Always read the map — even for an empty slot — so Obx has
      // an observable to subscribe to (GetX throws on zero reads).
      // '' is never a real asset id, so it always maps to null.
      final Uint8List? bytes = thumbnails[slotAsset?.id ?? ''];
      if (slotAsset != null &&
          bytes == null &&
          !failedThumbnails.contains(slotAsset.id)) {
        requestThumbnail(slotAsset.id);
      }
      return Container(
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant,
          borderRadius: BorderRadius.circular(context.sizes.radiusMd),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes != null)
              // Phase 1.6: decode at display size, never larger than
              // the fetched thumbnail (see decode_size.dart). The
              // slot reads the 320px shared map (solutions 3.1 grid standard).
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int side = decodeSide(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
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
              Container(color: context.palette.surfaceVariant),
            // Video Pill Badge (top right of video slot)
            if (showVideoBadge)
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
    });
  }
}
