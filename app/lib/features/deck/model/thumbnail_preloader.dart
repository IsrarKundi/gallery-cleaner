// Deck thumbnail window over the shared thumbnail service (Phase 2.3).
//
// Extracted from [DeckController] so the controller stays under its
// ~400-line budget: this is a distinct concern (which window to
// fetch) from deck state orchestration (marks, undo, filters,
// session resume). The bytes themselves live in [ThumbnailService],
// shared with review, smart decks, duplicates and hub previews —
// this class owns no cache anymore (Phase 1's 64-entry FIFO is
// superseded by the service's 512-entry / 32 MiB LRU).
//
// Behaviour: the current card plus the next 3 preload; when the
// window slides, out-of-window flights are cancelled (their bytes
// are dropped, never painted stale). The view keeps observing the
// same reactive objects, now owned by the service.
//
// Filter-change note: [clear] cancels in-flight deck fetches but
// deliberately does NOT drop cached bytes or failed marks — the
// cache is shared, so one screen's filter change must not nuke
// another screen's thumbnails. A failed card retries via window
// re-entry or the explicit retry (2.5).

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';

/// Thumbnail window manager for the deck (requirements §7:
/// thumbnail preloading for large libraries).
class ThumbnailPreloader {
  ThumbnailPreloader({required this.media, ThumbnailService? service})
    : _service = service ?? ThumbnailServiceImpl(media: media);

  final MediaService media;
  final ThumbnailService _service;

  /// Phase 4.4: while paused (app backgrounded) no new preload
  /// fetches start, and pausing cancels in-flight deck fetches
  /// (cached bytes and failed marks survive — see [clear]).
  /// Resume re-runs [preloadAround] for the current window.
  bool _paused = false;

  bool get isPaused => _paused;

  void setPaused(bool paused) {
    if (_paused == paused) {
      return;
    }
    _paused = paused;
    if (paused) {
      _service.cancelOutside(<ThumbnailKey>{});
    }
  }

  /// Thumbnail edge in pixels for deck preloading (solutions 3.1:
  /// deck-card surface = card width × DPR, capped at 1080 px).
  /// Fixed at the cap so the service key is stable across devices;
  /// decode stays display-bound via decodeSide (Phase 1.6), so the
  /// larger fetch buys sharpness on high-DPR phones, not decode
  /// memory. The 3×-DPR sharpness question stays a device check
  /// (whether 1080 vs full 1290 px matters visibly).
  static const int thumbnailSize = 1080;

  /// Cards preloaded ahead of the current card (current + next 3).
  static const int preloadAhead = 3;

  /// Service-owned bytes for the deck size; the view observes these
  /// same reactive objects.
  RxMap<String, Uint8List> get thumbnails =>
      _service.thumbnailsFor(thumbnailSize);

  /// Service-owned failed ids for the deck size.
  RxSet<String> get failedThumbnails => _service.failedFor(thumbnailSize);

  /// Prefetches thumbnails for [queue] from [start] through
  /// [start] + [preloadAhead], and cancels flights outside that
  /// window. Loads run in the background and never block swiping.
  /// Safe to call on every mark/undo: cached, in-flight and
  /// still-window failed ids are all no-ops inside the service.
  void preloadAround(List<MediaAsset> queue, int start) {
    if (_paused) {
      return;
    }
    final List<String> ids = <String>[
      for (int i = start; i < queue.length && i <= start + preloadAhead; i++)
        queue[i].id,
    ];
    _service.prefetch(ids, thumbnailSize);
    _service.cancelOutside(<ThumbnailKey>{
      for (final String id in ids) (id: id, size: thumbnailSize, quality: 85),
    });
  }

  /// Explicit retry for one failed card (2.5): clears the failed
  /// mark so the next [preloadAround] re-fetches it. Callers must
  /// re-run [preloadAround] after this — clearing alone fetches
  /// nothing.
  void retry(String id) {
    _service.retry(id, thumbnailSize);
  }

  /// Cancels in-flight deck fetches (filter change). Cached bytes
  /// and failed marks survive — see the file doc comment.
  void clear() {
    _service.cancelOutside(<ThumbnailKey>{});
  }
}
