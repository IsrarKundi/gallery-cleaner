import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../model/thumbnail_preloader.dart';
import 'swipe_card.dart';

/// Card stack (solutions 3.1): the current card on top, with the next
/// 1–2 cards pre-decoded underneath it, so a swipe reveals the next
/// photo with no blank flash and no UI-isolate decode at swipe time.
///
/// The underneath cards are plain photos (no gestures, no exit
/// logic): they exist only to decode early. When the top card swipes
/// away, the next card is already built with the same image provider
/// key (same bytes, same decode size), so the image cache serves it
/// instead of decoding again. The previous card needs no widget: its
/// bytes stay warm in the shared thumbnail service cache, so undo
/// shows it instantly.
///
/// Thumbnail arrivals rebuild only this stack (its own Obx): the
/// parent view reads the queue and index, never the thumbnail maps,
/// so a preload insertion no longer rebuilds the whole deck body.
class DeckCardStack extends StatelessWidget {
  const DeckCardStack({
    super.key,
    required this.current,
    required this.next,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.onSwiped,
    this.onRetry,
  });

  /// The top, interactive card.
  final MediaAsset current;

  /// The next cards, nearest first; at most 2 are rendered.
  final List<MediaAsset> next;

  /// Service-owned bytes for the deck size; read inside the Obx.
  final RxMap<String, Uint8List> thumbnails;

  /// Service-owned failed ids for the deck size.
  final RxSet<String> failedThumbnails;

  /// Top-card swipe commit (see [SwipeCard.onSwiped]).
  final ValueChanged<DeckMark> onSwiped;

  /// Tap-to-retry for a failed top card (see [SwipeCard.onRetry]).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MediaAsset? second = next.isNotEmpty ? next.first : null;
      final MediaAsset? third = next.length > 1 ? next[1] : null;
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Deepest first: the second-next card, then the next card,
          // then the interactive top card. Underneath cards are
          // fully behind the top card (same size, no offset) so the
          // reveal is gapless and no layout shifts on slot swaps.
          if (third != null)
            _StackPhoto(
              thumbnail: thumbnails[third.id],
              failed: failedThumbnails.contains(third.id),
            ),
          if (second != null)
            _StackPhoto(
              thumbnail: thumbnails[second.id],
              failed: failedThumbnails.contains(second.id),
            ),
          SwipeCard(
            key: ValueKey<String>(current.id),
            thumbnail: thumbnails[current.id],
            thumbnailFailed: failedThumbnails.contains(current.id),
            onSwiped: onSwiped,
            onRetry: onRetry,
          ),
        ],
      );
    });
  }
}

/// One pre-decoded card underneath the top card: the photo only, no
/// gestures, no spinner animation (it is hidden behind the top card
/// until revealed). A failed underneath card shows the same static
/// placeholder the top card's failure state uses, minus the retry
/// affordance — retry belongs to the top card once it is revealed.
class _StackPhoto extends StatelessWidget {
  const _StackPhoto({required this.thumbnail, required this.failed});

  final Uint8List? thumbnail;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.sizes.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (thumbnail != null)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int side = decodeSide(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  sourceSize: ThumbnailPreloader.thumbnailSize,
                );
                return Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  cacheWidth: side,
                  cacheHeight: side,
                );
              },
            )
          else
            Container(color: context.palette.surfaceVariant),
        ],
      ),
    );
  }
}
