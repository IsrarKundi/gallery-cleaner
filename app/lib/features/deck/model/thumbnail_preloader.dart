import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';

/// Thumbnail preloading + bounded cache for the deck (requirements §7:
/// thumbnail preloading for large libraries).
///
/// Extracted from [DeckController] so the controller stays under its
/// ~400-line budget: this is a distinct concern (fetch + cache +
/// eviction) from deck state orchestration (marks, undo, filters,
/// session resume). Behaviour is unchanged: the current card plus
/// the next 3 preload, failures are remembered so they are never
/// retried in-session, and the oldest entry drops first once the
/// cache bound is hit, so a huge library cannot grow it unbounded.
/// The [RxMap]/[RxSet] instances are owned here and exposed
/// directly, so the deck view keeps observing the same reactive
/// objects it observed when they lived on the controller.
class ThumbnailPreloader {
  ThumbnailPreloader({required this.media});

  final MediaService media;

  /// Thumbnail edge in pixels for deck preloading.
  static const int thumbnailSize = 512;

  /// Cards preloaded ahead of the current card (current + next 3).
  static const int preloadAhead = 3;

  /// Thumbnail cache bound: oldest entries drop first.
  static const int maxThumbnailCache = 64;

  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxSet<String> failedThumbnails = <String>{}.obs;

  /// Preloads thumbnails for [queue] from [start] through
  /// [start] + [preloadAhead]. Already-cached and already-failed
  /// ids are skipped; loads run in the background and never block
  /// swiping.
  void preloadAround(List<MediaAsset> queue, int start) {
    for (int i = start; i < queue.length && i <= start + preloadAhead; i++) {
      _loadThumbnail(queue[i].id);
    }
  }

  /// Drops every cached and failed entry (filter change).
  void clear() {
    thumbnails.clear();
    failedThumbnails.clear();
  }

  Future<void> _loadThumbnail(String assetId) async {
    if (thumbnails.containsKey(assetId) || failedThumbnails.contains(assetId)) {
      return;
    }
    final Result<Uint8List> result = await media.getThumbnail(
      assetId,
      thumbnailSize,
    );
    result.fold(
      onSuccess: (Uint8List bytes) {
        if (thumbnails.length >= maxThumbnailCache) {
          thumbnails.remove(thumbnails.keys.first);
        }
        thumbnails[assetId] = bytes;
      },
      onFailure: (_) => failedThumbnails.add(assetId),
    );
  }
}
