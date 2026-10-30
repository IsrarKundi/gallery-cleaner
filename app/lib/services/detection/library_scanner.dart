// Library scan (requirements §7, Phase 2; fix plan Stages 2+4).
//
// One shared scan, two phases:
//
// Phase A — enumeration. Pages of assets arrive through [onPage]
// (the hub shows metadata decks as pages land) with progress
// through [onProgress]. With a [LibraryEnumerationService] wired
// (production, Stage 2) the page source is ONE fresh enumeration
// pass per run, sliced into pages; otherwise the paged plugin
// source remains (unit tests, degraded setups). Cancellation and
// pause are honoured at page boundaries exactly as before.
//
// Phase B — matching (Stage 4). Only a COMPLETE enumeration gets
// here. The scanner first compares the live asset-info facts
// against the persisted membership snapshot: when every fact
// matches and the algorithm version is current, the saved
// memberships are reused and NO photo is read again (Cleanup's
// rule — memberships persist, fingerprints do not). Otherwise
// the scan recomputes, in the background, never on the UI
// thread when the workers spawn:
//   1. fingerprints — one worker batch per page of images, from
//      128 px thumbnails (Cleanup's cap is 1024 px);
//   2. blur — a SEPARATE second pass, one worker batch per 8
//      photos (Cleanup's parallelism cap), from 512 px
//      thumbnails;
//   3. grouping + duplicate keys + membership build on a worker.
// The finished memberships REPLACE the persisted snapshot
// wholesale (which is also the prune: memberships for deleted
// assets simply are not in the new snapshot). A cancelled or
// page-failed scan NEVER overwrites the persisted memberships —
// a partial library must not mint phantom groups or erase real
// ones. A failed thumbnail only skips that asset's values, never
// the page; a worker isolate that fails to spawn degrades to the
// identical sync batch on the UI thread and reports
// [LibraryScan.degraded], never a hang.
//
// Memory note, stated honestly (unchanged): the scan holds the
// full asset list in memory, so memory stays proportional to
// the library.

import 'dart:isolate';
import 'dart:typed_data';

import '../../core/utils/result.dart';
import '../local/local_service.dart';
import '../media/enumerated_asset.dart';
import '../media/library_enumeration_service.dart';
import '../media/media_asset.dart';
import '../media/media_mappings.dart';
import '../media/media_service.dart';
import 'analysis_worker.dart';
import 'blur_detection.dart';
import 'grouping.dart';
import 'photo_assessment.dart';
import 'scan_memberships.dart';
import 'thumbnail_analysis.dart';

/// Result of a completed (or page-failed / cancelled) scan.
class LibraryScan {
  const LibraryScan({
    required this.assets,
    required this.assessments,
    required this.memberships,
    required this.scanned,
    required this.pageFailed,
    this.cancelled = false,
    this.degraded = false,
  });

  /// Every asset seen, in scan order (newest first per page).
  final List<MediaAsset> assets;

  /// This run's transient per-asset values (fingerprints, blur,
  /// luminance) by asset id. Empty when the persisted
  /// memberships were reused without reading any photo, and on
  /// cancelled / page-failed runs. Never persisted.
  final Map<String, PhotoAssessment> assessments;

  /// The scan's membership product: freshly built on a complete
  /// recompute, the reused persisted snapshot when the library
  /// is unchanged, or the previous snapshot (untouched) on a
  /// cancelled / page-failed run.
  final ScanMemberships memberships;

  /// Assets scanned (== assets.length unless a page failed early).
  final int scanned;

  /// True when a page failed and the scan stopped early.
  final bool pageFailed;

  /// True when the scan was cancelled before finishing: [assets]
  /// holds only fully delivered pages.
  final bool cancelled;

  /// True when any worker batch fell back to the UI thread
  /// because the worker isolate could not spawn. The scan still
  /// completes with identical results; it was only slower.
  final bool degraded;
}

class LibraryScanner {
  LibraryScanner({
    required this.media,
    required this.local,
    this.enumeration,
    this.fingerprintBatch = fingerprintBatchOnIsolate,
    this.blurBatch = blurBatchOnIsolate,
    this.membershipsRunner = buildScanMembershipsOnIsolate,
  });

  final MediaService media;
  final LocalService local;

  /// The one-pass enumeration (Stage 2), when wired: each scan
  /// run forces one fresh pass and pages over its list. Null
  /// keeps the original paged plugin source.
  final LibraryEnumerationService? enumeration;

  /// Batch runners, injectable so tests can prove the degraded
  /// fallback with throwing runners. Production uses the worker
  /// isolates.
  final FingerprintBatchRunner fingerprintBatch;
  final BlurBatchRunner blurBatch;
  final MembershipsRunner membershipsRunner;

  static const int pageSize = 50;

  /// Thumbnail fetches in flight at once (also Cleanup's blur
  /// parallelism cap, Stage 4).
  static const int fetchConcurrency = 8;

  /// Runs the scan. [onPage] fires per enumerated page with that
  /// page's assets (phase B values arrive only in the final
  /// result, so the fresh map is always empty — the parameter
  /// keeps the repository's replay shape). [onProgress] fires per
  /// page with (scanned, estimatedTotalOrNull). [isCancelled] is
  /// checked per page and between phase-B chunks; [waitIfPaused]
  /// is awaited per page and returns false when cancelled while
  /// paused — either way a cancelled scan returns a
  /// [LibraryScan.cancelled] result and persists nothing.
  /// [onDegraded] fires the moment a worker batch falls back to
  /// the UI thread; the final result also carries
  /// [LibraryScan.degraded].
  Future<LibraryScan> scan({
    void Function(List<MediaAsset> page, Map<String, PhotoAssessment> fresh)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function()? waitIfPaused,
    void Function()? onDegraded,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;

    // The persisted membership snapshot: this run either reuses
    // it, replaces it (complete recompute), or leaves it
    // untouched (cancelled / page-failed).
    ScanMemberships snapshot = ScanMemberships.empty;
    final Result<ScanMemberships> saved = await local.loadScanMemberships();
    saved.fold(
      onSuccess: (ScanMemberships value) => snapshot = value,
      onFailure: (_) {},
    );

    int? estimatedTotal;
    if (enumeration == null) {
      // The album-count estimate belongs to the paged source;
      // the enumeration source knows its exact total (below).
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
    }

    bool degraded = false;
    void markDegraded() {
      if (!degraded) {
        degraded = true;
        onDegraded?.call();
      }
    }

    LibraryScan cancelledResult(List<MediaAsset> done) {
      return LibraryScan(
        assets: done,
        assessments: const <String, PhotoAssessment>{},
        memberships: snapshot,
        scanned: done.length,
        pageFailed: false,
        cancelled: true,
        degraded: degraded,
      );
    }

    final List<MediaAsset> all = <MediaAsset>[];
    bool pageFailed = false;

    // Stage 2 (ADR-017): the enumeration page source. One fresh
    // pass, forced per run; the loop below then slices it into
    // pages. A failed pass returns the page-0-failure shape
    // directly (no pages delivered, nothing persisted).
    List<MediaAsset>? enumeratedAssets;
    if (enumeration != null) {
      if (cancelled()) {
        return cancelledResult(all);
      }
      final Result<LibraryEnumeration> enumerated = await enumeration!
          .enumerate(forceRefresh: true);
      enumeratedAssets = enumerated.fold(
        onSuccess: (LibraryEnumeration data) => data.rows
            .where(
              (EnumeratedAsset row) => row.fileExists && isPluginListRow(row),
            )
            .map(
              (EnumeratedAsset row) => mediaAssetFromEnumerated(
                row,
                albumNameFallback: wholeLibraryAlbumName,
              ),
            )
            .toList(),
        onFailure: (_) => null,
      );
      if (enumeratedAssets == null) {
        return LibraryScan(
          assets: const <MediaAsset>[],
          assessments: const <String, PhotoAssessment>{},
          memberships: snapshot,
          scanned: 0,
          pageFailed: true,
          degraded: degraded,
        );
      }
      estimatedTotal = enumeratedAssets.isEmpty
          ? null
          : enumeratedAssets.length;
    }

    // ---- Phase A: enumeration pages. ----
    int page = 0;
    while (true) {
      if (cancelled()) {
        return cancelledResult(all);
      }
      if (waitIfPaused != null && !await waitIfPaused()) {
        return cancelledResult(all);
      }
      final List<MediaAsset>? pageAssets;
      if (enumeratedAssets != null) {
        final int start = page * pageSize;
        pageAssets = start >= enumeratedAssets.length
            ? <MediaAsset>[]
            : enumeratedAssets.sublist(
                start,
                start + pageSize > enumeratedAssets.length
                    ? enumeratedAssets.length
                    : start + pageSize,
              );
      } else {
        final Result<List<MediaAsset>> result = await media.getAssets(
          page: page,
          pageSize: pageSize,
        );
        pageAssets = result.fold(
          onSuccess: (List<MediaAsset> value) => value,
          onFailure: (_) => null,
        );
      }
      if (pageAssets == null) {
        pageFailed = true;
        break;
      }
      all.addAll(pageAssets);
      onPage?.call(pageAssets, const <String, PhotoAssessment>{});
      onProgress?.call(all.length, estimatedTotal);
      if (pageAssets.length < pageSize) {
        break;
      }
      page++;
    }

    if (pageFailed) {
      // A partial library never rewrites memberships (see file
      // doc): the previous snapshot stands, and this run's
      // callers see it alongside the partial asset list.
      return LibraryScan(
        assets: all,
        assessments: const <String, PhotoAssessment>{},
        memberships: snapshot,
        scanned: all.length,
        pageFailed: true,
        degraded: degraded,
      );
    }

    // ---- Phase B: matching. ----
    final Map<String, AssetInfo> currentInfos = <String, AssetInfo>{
      for (final MediaAsset asset in all) asset.id: AssetInfo.fromAsset(asset),
    };
    if (snapshot.isFreshFor(currentInfos)) {
      // Unchanged library + current algorithm: reuse the saved
      // memberships; no photo is read again at all.
      return LibraryScan(
        assets: all,
        assessments: const <String, PhotoAssessment>{},
        memberships: snapshot,
        scanned: all.length,
        pageFailed: false,
        degraded: degraded,
      );
    }

    final List<MediaAsset> images = all
        .where((MediaAsset a) => a.type == MediaAssetType.image)
        .toList();

    // B1: fingerprints, one worker batch per page of images.
    final Map<String, FingerprintComputation> fingerprints =
        <String, FingerprintComputation>{};
    for (int start = 0; start < images.length; start += pageSize) {
      if (cancelled()) {
        return cancelledResult(all);
      }
      final List<MediaAsset> chunk = images.sublist(
        start,
        start + pageSize > images.length ? images.length : start + pageSize,
      );
      final List<Uint8List?> fetched = await _fetchThumbnails(
        chunk,
        analysisThumbnailSize,
        cancelled,
      );
      if (cancelled()) {
        return cancelledResult(all);
      }
      final List<String> inputIds = <String>[];
      final List<Uint8List> inputBytes = <Uint8List>[];
      for (int i = 0; i < chunk.length; i++) {
        final Uint8List? bytes = fetched[i];
        if (bytes == null) {
          continue;
        }
        inputIds.add(chunk[i].id);
        inputBytes.add(bytes);
      }
      if (inputIds.isEmpty) {
        continue;
      }
      List<FingerprintComputation?> results;
      try {
        results = await fingerprintBatch(_batchInputs(inputIds, inputBytes));
      } catch (_) {
        markDegraded();
        results = fingerprintBatchSync(_batchInputs(inputIds, inputBytes));
      }
      for (int i = 0; i < inputIds.length && i < results.length; i++) {
        final FingerprintComputation? computed = results[i];
        if (computed != null) {
          fingerprints[inputIds[i]] = computed;
        }
      }
    }

    // B2: blur, a separate second pass — one worker batch per
    // [fetchConcurrency] photos, from 512 px thumbnails.
    final Map<String, BlurAssessment> blurResults = <String, BlurAssessment>{};
    for (int start = 0; start < images.length; start += fetchConcurrency) {
      if (cancelled()) {
        return cancelledResult(all);
      }
      final List<MediaAsset> chunk = images.sublist(
        start,
        start + fetchConcurrency > images.length
            ? images.length
            : start + fetchConcurrency,
      );
      final List<Uint8List?> fetched = await _fetchThumbnails(
        chunk,
        blurThumbnailSize,
        cancelled,
      );
      if (cancelled()) {
        return cancelledResult(all);
      }
      final List<String> inputIds = <String>[];
      final List<Uint8List> inputBytes = <Uint8List>[];
      for (int i = 0; i < chunk.length; i++) {
        final Uint8List? bytes = fetched[i];
        if (bytes == null) {
          continue;
        }
        inputIds.add(chunk[i].id);
        inputBytes.add(bytes);
      }
      if (inputIds.isEmpty) {
        continue;
      }
      List<BlurAssessment?> results;
      try {
        results = await blurBatch(_batchInputs(inputIds, inputBytes));
      } catch (_) {
        markDegraded();
        results = blurBatchSync(_batchInputs(inputIds, inputBytes));
      }
      for (int i = 0; i < inputIds.length && i < results.length; i++) {
        final BlurAssessment? computed = results[i];
        if (computed != null) {
          blurResults[inputIds[i]] = computed;
        }
      }
    }

    if (cancelled()) {
      return cancelledResult(all);
    }

    final Map<String, PhotoAssessment> assessments = <String, PhotoAssessment>{
      for (final MediaAsset asset in images)
        asset.id: PhotoAssessment(
          assetId: asset.id,
          fingerprint: fingerprints[asset.id]?.fingerprint,
          blur: blurResults[asset.id],
          meanLuminance: fingerprints[asset.id]?.meanLuminance,
        ),
    };

    // B3: grouping + membership build, on a worker.
    ScanMemberships memberships;
    try {
      memberships = await membershipsRunner(
        List<MediaAsset>.of(all),
        Map<String, PhotoAssessment>.of(assessments),
      );
    } catch (_) {
      markDegraded();
      memberships = buildScanMemberships(assets: all, assessments: assessments);
    }

    // Persist the finished product. A save failure must not fail
    // the scan: the memberships are valid for this run, and the
    // next scan retries the write.
    await local.saveScanMemberships(memberships);

    return LibraryScan(
      assets: all,
      assessments: assessments,
      memberships: memberships,
      scanned: all.length,
      pageFailed: false,
      degraded: degraded,
    );
  }

  /// Fetches thumbnails for [assets] in bounded-parallel chunks
  /// of [fetchConcurrency], in order. A failed fetch yields null
  /// for that asset (skipped, never a failed page). Cancellation
  /// is checked between chunks; the caller re-checks afterwards.
  Future<List<Uint8List?>> _fetchThumbnails(
    List<MediaAsset> assets,
    int size,
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
        // Quality 100 for analysis fetches (Phase 1.5: display
        // quality q85 must not silently mix into analysis).
        futures.add(media.getThumbnail(assets[i].id, size, quality: 100));
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

  /// Wraps parallel [ids]/[bytes] into transferable batch
  /// inputs. Built fresh for each attempt: a transferred input
  /// may be materialized exactly once, so the degraded fallback
  /// rebuilds its own inputs from the same raw bytes.
  List<AnalysisBatchInput> _batchInputs(
    List<String> ids,
    List<Uint8List> bytes,
  ) {
    return <AnalysisBatchInput>[
      for (int i = 0; i < ids.length; i++)
        AnalysisBatchInput(
          assetId: ids[i],
          bytes: TransferableTypedData.fromList(<Uint8List>[bytes[i]]),
        ),
    ];
  }
}
