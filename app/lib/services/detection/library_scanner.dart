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
// hash cache in batches (every page) so an interrupted scan still
// keeps what it computed.
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

/// Result of a completed (or page-failed) scan.
class LibraryScan {
  const LibraryScan({
    required this.assets,
    required this.analyses,
    required this.scanned,
    required this.pageFailed,
  });

  /// Every asset seen, in scan order (newest first per page).
  final List<MediaAsset> assets;

  /// Cached + newly computed analyses by asset id.
  final Map<String, PhotoAnalysis> analyses;

  /// Assets scanned (== assets.length unless a page failed early).
  final int scanned;

  /// True when a page failed and the scan stopped early.
  final bool pageFailed;
}

class LibraryScanner {
  LibraryScanner({required this.media, required this.local});

  final MediaService media;
  final LocalService local;

  static const int pageSize = 50;

  /// Runs the scan. [onPage] fires per page with that page's assets
  /// and the running analysis map; [onProgress] fires per page with
  /// (scanned, estimatedTotalOrNull).
  Future<LibraryScan> scan({
    void Function(List<MediaAsset> page, Map<String, PhotoAnalysis> analyses)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
  }) async {
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

    final List<MediaAsset> all = <MediaAsset>[];
    bool pageFailed = false;
    int page = 0;
    while (true) {
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
      final List<PhotoAnalysis> fresh = <PhotoAnalysis>[];
      for (final MediaAsset asset in pageAssets) {
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
          fresh.add(analysis);
        }
      }
      if (fresh.isNotEmpty) {
        // Best-effort batch save: a cache-write failure must not
        // fail the scan; the analyses stay in memory for this run.
        await local.saveAnalyses(fresh);
      }
      all.addAll(pageAssets);
      onPage?.call(pageAssets, analyses);
      onProgress?.call(all.length, estimatedTotal);
      if (pageAssets.length < pageSize) {
        break;
      }
      page++;
    }
    return LibraryScan(
      assets: all,
      analyses: analyses,
      scanned: all.length,
      pageFailed: pageFailed,
    );
  }
}
