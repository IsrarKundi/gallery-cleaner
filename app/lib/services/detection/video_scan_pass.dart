// The scan's video pass (fix plan Stage 6, ADR-021): phase B4
// of the library scan, run after the photo phases and before
// the membership snapshot is saved — the scanner merges the
// groups returned here into that snapshot, so a cancelled pass
// (null) persists nothing, exactly like the photo phases.
//
// Work shape, chosen against the cost profile:
// - Candidates are the enumeration's videos at or under the
//   400 MB gate (video_similarity.dart). Bigger videos are
//   never even asked for a duration.
// - Duration read + frame extraction are NATIVE calls (the
//   frame channel's single executor serialises them) and run
//   strictly one video at a time: frame extraction is the
//   scan's expensive step and stays tightly bounded.
// - The extracted 9x8 PNGs are fingerprinted with the photo
//   fingerprint batch (the scanner's injectable runner, so the
//   degraded UI-thread fallback and its reporting are the
//   photo phases' own), in slices of one page of videos. The
//   fingerprints are transient — grouping consumes them and
//   they are discarded; only memberships persist (ADR-019's
//   rule, unchanged).
// - Cancellation is honoured between videos and between
//   fingerprint slices; the caller re-checks before saving.

import 'dart:isolate';
import 'dart:typed_data';

import '../media/media_asset.dart';
import '../media/video_frame_gateway.dart';
import 'analysis_worker.dart';
import 'photo_assessment.dart';
import 'scan_memberships.dart';
import 'thumbnail_analysis.dart';
import 'video_similarity.dart';

class VideoScanPass {
  VideoScanPass({
    required this.gateway,
    this.fingerprintBatch = fingerprintBatchOnIsolate,
  });

  /// The native frame source (duration + 9x8 frame PNGs).
  final VideoFrameGateway gateway;

  /// The fingerprint batch runner — the scanner's own, so a
  /// spawn failure degrades identically to the photo phases.
  final FingerprintBatchRunner fingerprintBatch;

  /// Videos fingerprinted per batch slice (the scanner's page
  /// size, so slice cost tracks the photo phases').
  static const int videosPerSlice = 50;

  /// Runs the pass over [assets] (the scan's full list; the
  /// pass picks its own candidates). Returns the similar-video
  /// groups to merge into the scan's memberships, or null when
  /// [isCancelled] fired mid-pass — the caller then abandons
  /// the whole scan result and persists nothing.
  Future<List<ScanGroup>?> run({
    required List<MediaAsset> assets,
    required bool Function() isCancelled,
    required void Function() onDegraded,
  }) async {
    final List<MediaAsset> candidates = assets
        .where(isSimilarVideoCandidate)
        .toList();
    if (candidates.isEmpty) {
      return const <ScanGroup>[];
    }

    // Extraction phase: sequential per video. Successful frame
    // PNGs accumulate per video, in timestamp order; a video
    // whose duration or frames cannot be read simply never
    // enters the fingerprint map (unreadable — it can still be
    // listed and swiped in the Videos deck, it just never
    // groups).
    final Map<String, List<Uint8List>> pngsById = <String, List<Uint8List>>{};
    for (final MediaAsset video in candidates) {
      if (isCancelled()) {
        return null;
      }
      final Duration? duration = await gateway.videoDuration(video.id);
      if (isCancelled()) {
        return null;
      }
      if (duration == null) {
        continue;
      }
      final List<Duration> timestamps = videoFrameTimestamps(duration);
      if (timestamps.isEmpty) {
        continue;
      }
      final List<Uint8List?> frames = await gateway.extractFrames(
        video.id,
        timestamps,
      );
      final List<Uint8List> pngs = <Uint8List>[
        for (final Uint8List? frame in frames) ?frame,
      ];
      if (pngs.isNotEmpty) {
        pngsById[video.id] = pngs;
      }
    }

    // Fingerprint phase: one worker batch per slice of videos,
    // over the SAME inputs the photo phases use — the frames
    // are 9x8 PNGs, so computeFingerprint's output IS the
    // frame fingerprint (its colour summary over the 9x8
    // raster, its dHash over the same raster).
    final Map<String, List<PhotoFingerprint>> framesById =
        <String, List<PhotoFingerprint>>{};
    final List<MediaAsset> readable = candidates
        .where((MediaAsset v) => pngsById.containsKey(v.id))
        .toList();
    for (int start = 0; start < readable.length; start += videosPerSlice) {
      if (isCancelled()) {
        return null;
      }
      final List<MediaAsset> slice = readable.sublist(
        start,
        start + videosPerSlice > readable.length
            ? readable.length
            : start + videosPerSlice,
      );
      // Raw bytes stay with this method: a batch input's
      // transferable data may be materialised exactly once, so
      // the degraded fallback rebuilds its own inputs (the
      // scanner's phase-B pattern).
      final List<String> inputVideoIds = <String>[];
      final List<Uint8List> inputBytes = <Uint8List>[];
      for (final MediaAsset video in slice) {
        for (final Uint8List png in pngsById[video.id]!) {
          inputVideoIds.add(video.id);
          inputBytes.add(png);
        }
      }
      List<AnalysisBatchInput> buildInputs() {
        return <AnalysisBatchInput>[
          for (int i = 0; i < inputBytes.length; i++)
            AnalysisBatchInput(
              assetId: inputVideoIds[i],
              bytes: TransferableTypedData.fromList(<Uint8List>[inputBytes[i]]),
            ),
        ];
      }

      List<FingerprintComputation?> results;
      try {
        results = await fingerprintBatch(buildInputs());
      } catch (_) {
        onDegraded();
        results = fingerprintBatchSync(buildInputs());
      }
      for (int i = 0; i < inputVideoIds.length && i < results.length; i++) {
        final PhotoFingerprint? print = results[i]?.fingerprint;
        if (print != null) {
          (framesById[inputVideoIds[i]] ??= <PhotoFingerprint>[]).add(print);
        }
      }
    }

    if (isCancelled()) {
      return null;
    }

    // Grouping is cheap pairwise arithmetic over at most 13
    // fingerprints per video; it runs here, on the caller's
    // isolate, like the membership build's inputs assembly.
    final List<List<MediaAsset>> grouped = groupSimilarVideos(
      assets: candidates,
      framesById: framesById,
    );
    return <ScanGroup>[
      for (final List<MediaAsset> members in grouped)
        ScanGroup(
          kind: ScanGroupKind.similarVideos,
          memberIds: <String>[for (final MediaAsset a in members) a.id],
          seedId: members.first.id,
        ),
    ];
  }
}
