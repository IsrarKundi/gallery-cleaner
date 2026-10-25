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
// Performance limitation, stated honestly: the scan holds the
// full asset list in memory, so memory stays proportional to the
// library. Decode/scoring no longer runs on the UI isolate
// (solutions 5.1: one worker batch per page, bounded-parallel
// fetch); later scans are cheap because the cache covers
// everything already analysed.
// A single failed page stops the scan with an error (the hub
// keeps whatever pages arrived); a single failed thumbnail only
// skips analysis for that asset, never the page.
//
// The total is an estimate: the largest album count (the
// whole-library album is normally the largest). When albums fail,
// progress reports the scanned count with no total.

import 'dart:isolate';
import 'dart:typed_data';

import '../../core/utils/result.dart';
import '../local/local_service.dart';
import '../media/media_asset.dart';
import '../media/media_service.dart';
import 'analysis_worker.dart';
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
    this.degraded = false,
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

  /// True when any page's analysis fell back to the UI thread
  /// because the worker isolate could not spawn (solutions 5.1).
  /// The scan still completes with identical results; it was only
  /// slower, and the hub shows that state while it lasts.
  final bool degraded;
}

class LibraryScanner {
  LibraryScanner({
    required this.media,
    required this.local,
    this.analyzeBatch = analyzeBatchOnIsolate,
  });

  final MediaService media;
  final LocalService local;

  /// Batch analysis runner, injectable so tests can prove the
  /// degraded fallback with a throwing runner. Production uses
  /// the worker isolate ([analyzeBatchOnIsolate]).
  final AnalyzeBatchRunner analyzeBatch;

  static const int pageSize = 50;

  /// Thumbnail fetches in flight at once per page (solutions 5.1).
  static const int fetchConcurrency = 8;

  /// Pages between analysis-cache checkpoints (solutions 4.2).
  static const int checkpointEveryPages = 20;

  /// Runs the scan. [onPage] fires per page with that page's assets
  /// and ONLY that page's fresh analyses (never the cumulative
  /// map); [onProgress] fires per page with (scanned,
  /// estimatedTotalOrNull). [isCancelled] is checked per page and
  /// between fetch chunks; [waitIfPaused] is awaited per page and
  /// returns false when cancelled while paused — either way a
  /// cancelled scan returns a [LibraryScan.cancelled] result with
  /// no checkpoint save and no onPage for the partial page.
  /// [onDegraded] fires the moment the worker isolate fails and
  /// the scan falls back to UI-thread analysis (solutions 5.1);
  /// the final result also carries [LibraryScan.degraded].
  Future<LibraryScan> scan({
    void Function(List<MediaAsset> page, Map<String, PhotoAnalysis> fresh)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function()? waitIfPaused,
    void Function()? onDegraded,
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

    // Phase 5.1: set once, the first time a page's analysis falls
    // back to the UI thread. A cancelled scan still reports it:
    // the fallback already happened, even if the run stops early.
    bool degraded = false;

    LibraryScan cancelledResult(List<MediaAsset> done) {
      return LibraryScan(
        assets: done,
        analyses: analyses,
        scanned: done.length,
        pageFailed: false,
        cancelled: true,
        degraded: degraded,
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
      // Phase 5.1: thumbnails still arrive on the main isolate
      // (platform channels live there), but every decode and
      // score runs in ONE worker batch per page — never per
      // photo, and never on the UI thread when the worker spawns.
      // Phase 5.3: a cached entry is reused only when it is
      // still fresh for this exact file (version + dimensions +
      // size + modified date). An edited photo's stale entry is
      // re-analysed, and the fresh result overwrites it below.
      bool needsAnalysis(MediaAsset asset) {
        if (asset.type != MediaAssetType.image) {
          return false;
        }
        final PhotoAnalysis? cached = analyses[asset.id];
        return cached == null || !isAnalysisFresh(cached, asset);
      }

      final List<MediaAsset> toAnalyse = pageAssets
          .where(needsAnalysis)
          .toList();
      if (toAnalyse.isNotEmpty) {
        if (cancelled()) {
          // Partial page: no checkpoint, no onPage, no stale write.
          return cancelledResult(all);
        }
        final List<Uint8List?> fetched = await _fetchThumbnails(
          toAnalyse,
          cancelled,
        );
        if (cancelled()) {
          return cancelledResult(all);
        }
        final List<MediaAsset> inputAssets = <MediaAsset>[];
        final List<Uint8List> inputBytes = <Uint8List>[];
        for (int i = 0; i < toAnalyse.length && i < fetched.length; i++) {
          final Uint8List? bytes = fetched[i];
          if (bytes == null) {
            continue;
          }
          inputAssets.add(toAnalyse[i]);
          inputBytes.add(bytes);
        }
        List<PhotoAnalysis?> results;
        try {
          results = await analyzeBatch(_inputsFor(inputAssets, inputBytes));
        } catch (_) {
          // Worker isolate failed to spawn (or died): degrade to
          // the identical batch on the UI thread and keep
          // scanning — never a hang. The slower state is reported
          // once, on the first fallback page of this scan.
          if (!degraded) {
            degraded = true;
            onDegraded?.call();
          }
          results = analyzeBatchSync(_inputsFor(inputAssets, inputBytes));
        }
        for (int i = 0; i < inputAssets.length && i < results.length; i++) {
          final PhotoAnalysis? analysis = results[i];
          if (analysis != null) {
            analyses[analysis.assetId] = analysis;
            fresh[analysis.assetId] = analysis;
            unsavedFresh.add(analysis);
          }
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
    if (!pageFailed) {
      // Phase 5.3: prune only after a FULL enumeration. A
      // page-failed scan never prunes: assets beyond the failure
      // were never seen and must not be mistaken for deleted.
      // A prune failure is ignored — the scan still succeeds,
      // the analyses stay in memory for this run, and the next
      // full scan retries.
      await local.pruneAnalyses(
        all.map((MediaAsset asset) => asset.id).toSet(),
      );
    }
    return LibraryScan(
      assets: all,
      analyses: analyses,
      scanned: all.length,
      pageFailed: pageFailed,
      degraded: degraded,
    );
  }

  /// Fetches thumbnails for [assets] in bounded-parallel chunks of
  /// [fetchConcurrency], in order. A failed fetch yields null for
  /// that asset (skipped, never a failed page). Cancellation is
  /// checked between chunks; the caller re-checks afterwards, so
  /// a short return here is never applied to a live page.
  Future<List<Uint8List?>> _fetchThumbnails(
    List<MediaAsset> assets,
    bool Function() cancelled,
  ) async {
    final List<Uint8List?> out = <Uint8List?>[];
    for (int start = 0; start < assets.length; start += fetchConcurrency) {
      if (cancelled()) {
        break;
      }
      final int end = (start + fetchConcurrency) < assets.length
          ? start + fetchConcurrency
          : assets.length;
      final List<Future<Result<Uint8List>>> futures =
          <Future<Result<Uint8List>>>[];
      for (int i = start; i < end; i++) {
        // Phase 1.5: analysis keeps q100 — cached analyses were
        // hashed from q100 thumbnails, and display quality (q85)
        // must not silently mix hash versions (issues file F-12).
        futures.add(
          media.getThumbnail(assets[i].id, analysisThumbnailSize, quality: 100),
        );
      }
      final List<Result<Uint8List>> results = await Future.wait(futures);
      for (final Result<Uint8List> result in results) {
        out.add(
          result.fold(
            onSuccess: (Uint8List bytes) => bytes,
            onFailure: (_) => null,
          ),
        );
      }
    }
    return out;
  }

  /// Wraps parallel [assets]/[bytes] into transferable batch
  /// inputs. Built fresh for each attempt: a transferred input
  /// may be materialized exactly once, so the degraded fallback
  /// rebuilds its own inputs from the same raw bytes.
  List<AnalysisBatchInput> _inputsFor(
    List<MediaAsset> assets,
    List<Uint8List> bytes,
  ) {
    final List<AnalysisBatchInput> inputs = <AnalysisBatchInput>[];
    for (int i = 0; i < assets.length; i++) {
      inputs.add(
        AnalysisBatchInput(
          assetId: assets[i].id,
          bytes: TransferableTypedData.fromList(<Uint8List>[bytes[i]]),
          width: assets[i].width,
          height: assets[i].height,
          sizeBytes: assets[i].sizeBytes,
          modifiedDateMs: assets[i].modifiedDate?.millisecondsSinceEpoch,
        ),
      );
    }
    return inputs;
  }
}
