// Paged, background-friendly library scan shared by the smart-deck
// hub and the Duplicates screen (requirements §7, Phase 2).
//
// The scan never blocks the UI thread on a full-library pass: it
// pages through MediaService (50 assets per page), reports each
// page through [onPage] so the hub shows decks as their counts
// become known, and reports progress through [onProgress] (assets
// scanned + an estimated total). Analysis runs per image asset:
// cached analyses are reused, uncached ones get one thumbnail
// download + decode, and new analyses are saved to the LocalService
// hash cache at checkpoints (every [checkpointEveryPages] pages,
// plus a final write) so an interrupted scan still keeps what it
// computed without paying a full rewrite per page (solutions 4.2).
//
// Phase 4.2: [onPage] passes ONLY the page's fresh analyses, not
// the cumulative map (the hub used to copy the whole map per page).
// The scan is cancellable ([isCancelled] checked per page and per
// asset) and pausable ([waitIfPaused] awaited per page): a
// cancelled scan stops at the next boundary with no checkpoint
// save and no onPage for the partial page, and reports
// [LibraryScan.cancelled]. A paused scan resumes from the next
// page, never restarts.
//
// Performance limitation, stated honestly (50,000+ tuning is
// Phase 3): the scan holds the full asset list in memory, fetches
// one thumbnail per uncached image, and decodes each on the UI
// isolate. On a very large library the first scan takes a while
// and uses memory proportional to the library; later scans are
// cheap because the cache covers everything already analysed.
// A single failed page stops the scan with an error (the hub
// keeps whatever pages arrived); a single failed thumbnail only
// skips analysis for that asset, never the page.
//
// The total is an estimate: the largest album count (the
// whole-library album is normally the largest). When albums fail,
// progress reports the scanned count with no total.

import 'dart:typed_data';

import '../../core/utils/result.dart';
import '../local/local_service.dart';
import '../media/media_asset.dart';
import '../media/media_service.dart';
import 'photo_analysis.dart';
import 'thumbnail_analysis.dart';

/// Result of a completed (or page-failed / cancelled) scan.
class LibraryScan {
  const LibraryScan({
    required this.assets,
    required this.analyses,
    required this.scanned,
    required this.pageFailed,
    this.cancelled = false,
  });

  /// Every asset seen, in scan order (newest first per page).
  final List<MediaAsset> assets;

  /// Cached + newly computed analyses by asset id.
  final Map<String, PhotoAnalysis> analyses;

  /// Assets scanned (== assets.length unless a page failed early).
  final int scanned;

  /// True when a page failed and the scan stopped early.
  final bool pageFailed;

  /// True when the scan was cancelled before finishing: [assets]
  /// holds only fully delivered pages, and no checkpoint save was
  /// made for the partial page.
  final bool cancelled;
}

class LibraryScanner {
  LibraryScanner({required this.media, required this.local});

  final MediaService media;
  final LocalService local;

  static const int pageSize = 50;

  /// Pages between analysis-cache checkpoints (solutions 4.2).
  static const int checkpointEveryPages = 20;

  /// Runs the scan. [onPage] fires per page with that page's assets
  /// and ONLY that page's fresh analyses (never the cumulative
  /// map); [onProgress] fires per page with (scanned,
  /// estimatedTotalOrNull). [isCancelled] is checked per page and
  /// per asset; [waitIfPaused] is awaited per page and returns
  /// false when cancelled while paused — either way a cancelled
  /// scan returns a [LibraryScan.cancelled] result with no
  /// checkpoint save and no onPage for the partial page.
  Future<LibraryScan> scan({
    void Function(List<MediaAsset> page, Map<String, PhotoAnalysis> fresh)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function()? waitIfPaused,
    int checkpointEveryPages = checkpointEveryPages,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
    final Result<Map<String, PhotoAnalysis>> cached = await local
        .loadAnalyses();
    cached.fold(onSuccess: analyses.addAll, onFailure: (_) {});

    int? estimatedTotal;
    final Result<List<MediaAlbum>> albums = await media.getAlbums();
    albums.fold(
      onSuccess: (List<MediaAlbum> list) {
        int max = 0;
        for (final MediaAlbum album in list) {
          if (album.count > max) {
            max = album.count;
          }
        }
        estimatedTotal = max > 0 ? max : null;
      },
      onFailure: (_) {},
    );

    LibraryScan cancelledResult(List<MediaAsset> done) {
      return LibraryScan(
        assets: done,
        analyses: analyses,
        scanned: done.length,
        pageFailed: false,
        cancelled: true,
      );
    }

    final List<MediaAsset> all = <MediaAsset>[];
    final List<PhotoAnalysis> unsavedFresh = <PhotoAnalysis>[];
    bool pageFailed = false;
    int page = 0;
    while (true) {
      if (cancelled()) {
        return cancelledResult(all);
      }
      if (waitIfPaused != null && !await waitIfPaused()) {
        return cancelledResult(all);
      }
      final Result<List<MediaAsset>> result = await media.getAssets(
        page: page,
        pageSize: pageSize,
      );
      final List<MediaAsset>? pageAssets = result.fold(
        onSuccess: (List<MediaAsset> value) => value,
        onFailure: (_) => null,
      );
      if (pageAssets == null) {
        pageFailed = true;
        break;
      }
      final Map<String, PhotoAnalysis> fresh = <String, PhotoAnalysis>{};
      for (final MediaAsset asset in pageAssets) {
        if (cancelled()) {
          // Partial page: no checkpoint, no onPage, no stale write.
          return cancelledResult(all);
        }
        if (asset.type != MediaAssetType.image) {
          continue;
        }
        if (analyses.containsKey(asset.id)) {
          continue;
        }
        // Phase 1.5: analysis keeps q100 — cached analyses were
        // hashed from q100 thumbnails, and display quality (q85)
        // must not silently mix hash versions (issues file F-12).
        final Result<Uint8List> thumb = await media.getThumbnail(
          asset.id,
          analysisThumbnailSize,
          quality: 100,
        );
        final PhotoAnalysis? analysis = thumb.fold(
          onSuccess: (Uint8List bytes) => analyzeThumbnail(
            assetId: asset.id,
            bytes: bytes,
            width: asset.width,
            height: asset.height,
          ),
          onFailure: (_) => null,
        );
        if (analysis != null) {
          analyses[asset.id] = analysis;
          fresh[asset.id] = analysis;
          unsavedFresh.add(analysis);
        }
      }
      if (cancelled()) {
        return cancelledResult(all);
      }
      // Checkpoint roughly every N pages, plus a final write
      // below: a cache-write failure must not fail the scan; the
      // analyses stay in memory for this run.
      if (unsavedFresh.isNotEmpty && (page + 1) % checkpointEveryPages == 0) {
        await local.saveAnalyses(unsavedFresh);
        unsavedFresh.clear();
      }
      all.addAll(pageAssets);
      onPage?.call(pageAssets, fresh);
      onProgress?.call(all.length, estimatedTotal);
      if (pageAssets.length < pageSize) {
        break;
      }
      page++;
    }
    // Final write for completed AND page-failed runs: the analyses
    // are valid even when a later page fetch failed. Cancelled
    // runs never reach here (they return early above).
    if (unsavedFresh.isNotEmpty) {
      await local.saveAnalyses(unsavedFresh);
      unsavedFresh.clear();
    }
    return LibraryScan(
      assets: all,
      analyses: analyses,
      scanned: all.length,
      pageFailed: pageFailed,
    );
  }
}
