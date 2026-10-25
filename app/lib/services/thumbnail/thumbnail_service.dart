// Shared thumbnail service (Phase 2.3, performance-issues RC-C).
//
// ONE service owns every thumbnail byte in the app: a single byte
// LRU keyed (id, size, quality), shared by the deck, review, smart
// decks, duplicates and hub previews. Before this service, each
// controller owned its own map and each hub tile fetched in
// `initState`, so the same photo was fetched once per screen — and
// a hub build could issue the same (id, size) fetch many times.
//
// Rules the implementation guarantees (all proven by
// test/services/thumbnail/thumbnail_service_test.dart):
// - In-flight dedup is registered synchronously: two callers asking
//   for the same key before the first fetch completes share one
//   fetch. There is no check-then-await gap.
// - One automatic retry for a failed thumbnail, then a failed mark.
//   A failed thumbnail is never terminal for the session: the next
//   controller request retries it, and a prefetch window re-entry
//   retries it (a failed id sitting in an unchanged window does NOT
//   refetch on every prefetch call — no retry storm).
// - Cancellation when the window slides: `cancelOutside` marks
//   out-of-window flights cancelled, and their completions are
//   dropped (never cached, never marked failed, waiter gets a
//   failure). The native fetch still runs to completion — only its
//   effect is cancelled — because the media interface has no
//   cancellation token to thread through (a Phase 3 refinement if
//   profiling ever shows wasted native work matters).
// - Bounds: 512 entries / 32 MiB, LRU. Eviction removes the entry
//   from the observable map too, so a visible tile re-requests
//   instead of showing a stale byte.
// - Bytes are cached; entity resolution is NOT (that is the media
//   service's entity cache from 2.1). A byte-cache hit therefore
//   costs zero media calls; a miss costs one media call (plus the
//   single retry on failure).

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../core/utils/result.dart';

/// One thumbnail identity: asset id + requested edge + quality.
/// Records compare by value, so sets of keys work for window
/// cancellation.
typedef ThumbnailKey = ({String id, int size, int quality});

/// The single thumbnail cache for the whole app.
abstract class ThumbnailService {
  /// Observable bytes for one (size, quality). Views observe these
  /// maps through their controller's getters; the service owns them.
  RxMap<String, Uint8List> thumbnailsFor(int size, {int quality = 85});

  /// Observable failed ids for one (size, quality). Views render
  /// the failure state from these; they never trigger a fetch.
  RxSet<String> failedFor(int size, {int quality = 85});

  /// Controller path: cached bytes return immediately; an in-flight
  /// fetch is joined; a failed id is retried (its failed mark is
  /// cleared and the fetch runs again, with the one automatic retry
  /// on failure). Never throws: failures are [Failure] values.
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  });

  /// Widget path (hub previews): idempotent cache-warming. No-op
  /// when cached, failed, or already in flight; otherwise starts
  /// one fetch. Safe to call from build on every rebuild.
  void requestThumbnail(String assetId, int size, {int quality = 85});

  /// Window prefetch (deck / smart decks): fetches [ids] for one
  /// size, skipping cached, in-flight, and failed ids that are
  /// still in the previous window for this size. A failed id that
  /// left the window and re-enters retries.
  void prefetch(List<String> ids, int size, {int quality = 85});

  /// Marks every in-flight fetch outside [wanted] cancelled. Their
  /// completions are dropped, never cached or marked failed.
  void cancelOutside(Set<ThumbnailKey> wanted);

  /// Clears one failed mark so the next request refetches. Used by
  /// the deck's explicit retry on a failed card (2.5).
  void retry(String assetId, int size, {int quality = 85});

  /// Full reset (tests). Production callers prefer [cancelOutside]:
  /// clearing drops cached bytes other screens may still show.
  void clear();
}
