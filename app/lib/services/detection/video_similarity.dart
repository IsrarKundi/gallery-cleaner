// Similar-videos matching (fix plan Stage 6, requirements §7):
// Cleanup's recovered sampling numbers (teardown
// notes/algorithms.md §6) as wipe.'s own pure Dart — the frame
// arithmetic, the size gate and the pair predicate. Frame
// extraction and fingerprinting live elsewhere (the native
// frame channel and thumbnail_analysis.dart); this file only
// decides WHICH frames to take from a video and WHEN two
// videos count as similar, so every rule here is unit-testable
// without a device.
//
// The rules, exactly as recovered:
// - Only videos of 400 MB or smaller are checked at all
//   (maxAllowedFileMB = 400).
// - Frames are spread evenly across the video INCLUDING both
//   ends (the teardown's `ih/b.a()` shape): normally 7 frames,
//   at most 13, with the gap between neighbouring frames kept
//   inside 2 s..10 s (minInterval / maxInterval). The count
//   follows from the duration: 7 while 7 frames keep the gap in
//   bounds; more (up to 13) when the gap would exceed 10 s;
//   fewer when the gap would fall under 2 s. See ADR-021 for
//   the derivation — the settings carry the three numbers, not
//   a formula, so this is the simplest reading that honours
//   all of them at once.
// - Each frame is fingerprinted from its 9x8 raster with the
//   Stage 4 two-part fingerprint and compared with the
//   NORMAL-PHOTO compare rule (photo_assessment.dart) — never
//   the screenshot rule.
// - Two videos are similar when enough frame pairs match:
//   minMatchedFrameCount = 2, capped by the smaller frame list
//   and floored at 1 (the teardown's `ch/d` formula). A frame
//   counts at most once on each side: matching consumes the
//   counterpart, so one static frame cannot satisfy the count
//   against many counterparts.
// - Unreadable / zero-duration videos produce no frame list
//   and never match (Cleanup's invalid-hash sentinel: hash -1
//   with an empty colour matrix matches nothing, and
//   [areSimilar] enforces the same validity gate per pair).
//
// Grouping mirrors the stills seed rule (grouping.dart): date
// order, a video joins only if it is similar to the SEED
// itself, groups of 1 are dropped. No frame fingerprint is
// persisted anywhere — the scan persists memberships only
// (scan_memberships.dart, ADR-021).

import '../media/media_asset.dart';
import 'photo_assessment.dart';

/// Largest video (bytes) the similarity check reads at all:
/// Cleanup's maxAllowedFileMB = 400 (binary MB, the repo's
/// convention — see smart_decks.dart's large threshold).
const int maxSimilarVideoBytes = 400 * 1024 * 1024;

/// Cleanup's bigFileThresholdMB = 100. Observed in their
/// settings only; where (or whether) it gates their pipeline
/// is UNKNOWN in the teardown, and the fix plan builds no UI
/// or behaviour for it (ADR-021). Carried here so the number
/// has exactly one home if that ever changes.
const int bigFileThresholdBytes = 100 * 1024 * 1024;

/// Frame count for a video whose duration keeps 7 frames
/// inside the interval bounds (Cleanup's frameCount).
const int videoFrameCount = 7;

/// Most frames ever sampled from one video (Cleanup's
/// maxFrameCount).
const int videoMaxFrameCount = 13;

/// Smallest allowed gap between sampled frames (Cleanup's
/// minInterval, 2.0 s).
const Duration videoMinFrameInterval = Duration(seconds: 2);

/// Largest allowed gap between sampled frames (Cleanup's
/// maxInterval, 10.0 s).
const Duration videoMaxFrameInterval = Duration(seconds: 10);

/// Matching frame pairs required for two videos to be similar
/// (Cleanup's minMatchedFrameCount), before the smaller-list
/// cap / 1 floor in [requiredMatchedFrames].
const int videoMinMatchedFrames = 2;

/// True when [asset] may enter the similarity check at all:
/// a video at or under the size cap. Bigger videos are skipped
/// entirely — no duration read, no frame extraction.
bool isSimilarVideoCandidate(MediaAsset asset) {
  return asset.type == MediaAssetType.video &&
      asset.sizeBytes <= maxSimilarVideoBytes;
}

/// The timestamps to sample from a video of [duration],
/// evenly spread including both ends (see file doc). Empty
/// for a zero/negative duration (an unreadable video yields
/// no frames). Integer-microsecond math throughout, so the
/// returned list is exact and stable across runs.
List<Duration> videoFrameTimestamps(Duration duration) {
  final int totalUs = duration.inMicroseconds;
  if (totalUs <= 0) {
    return const <Duration>[];
  }
  final int minGapUs = videoMinFrameInterval.inMicroseconds;
  final int maxGapUs = videoMaxFrameInterval.inMicroseconds;
  // The gap 7 frames would leave: totalUs / (7 - 1). Compare
  // cross-multiplied to stay in integers.
  int count = videoFrameCount;
  if (totalUs > maxGapUs * (videoFrameCount - 1)) {
    // 7 frames would spread thinner than the 10 s cap: add
    // frames (smallest count whose gap fits), at most 13. When
    // the 13 cap binds, the gap stays above 10 s — unavoidable,
    // and exactly what "at most 13" means.
    final int intervals = (totalUs + maxGapUs - 1) ~/ maxGapUs;
    count = intervals + 1;
    if (count > videoMaxFrameCount) {
      count = videoMaxFrameCount;
    }
  } else if (totalUs < minGapUs * (videoFrameCount - 1)) {
    // 7 frames would crowd under the 2 s floor: drop frames
    // (largest count whose gap still fits). A video shorter
    // than 2 s cannot honour the floor at all; it still gets
    // both ends (2 frames), the smallest useful set.
    count = totalUs ~/ minGapUs + 1;
    if (count < 2) {
      count = 2;
    }
  }
  return <Duration>[
    for (int i = 0; i < count; i++)
      Duration(microseconds: (totalUs * i) ~/ (count - 1)),
  ];
}

/// Frame pairs required for a similarity verdict between lists
/// of [sizeA] and [sizeB] frames: the teardown's formula —
/// minMatchedFrameCount capped by the smaller list, floored
/// at 1. With two full lists (the normal case: every readable
/// video samples at least 2 timestamps) this is simply 2.
int requiredMatchedFrames(int sizeA, int sizeB) {
  final int smaller = sizeA < sizeB ? sizeA : sizeB;
  final int required = videoMinMatchedFrames < smaller
      ? videoMinMatchedFrames
      : smaller;
  return required < 1 ? 1 : required;
}

/// How many frame pairs match between two videos' frame
/// fingerprints, under the normal-photo compare rule. Greedy
/// in timestamp order: each frame of [a] takes the first
/// still-unmatched frame of [b] it is similar to, and a frame
/// of [b] can be consumed only once — so the count is a count
/// of DISTINCT pairs, never one frame matching many.
int countMatchingFrames(List<PhotoFingerprint> a, List<PhotoFingerprint> b) {
  final List<bool> consumed = List<bool>.filled(b.length, false);
  int matches = 0;
  for (final PhotoFingerprint frameA in a) {
    for (int j = 0; j < b.length; j++) {
      if (consumed[j]) {
        continue;
      }
      if (areSimilar(frameA, b[j], FingerprintClass.photo)) {
        consumed[j] = true;
        matches++;
        break;
      }
    }
  }
  return matches;
}

/// Cleanup's video-pair predicate: similar when the matching
/// frame pairs reach [requiredMatchedFrames]. An empty list
/// on either side (unreadable video) never matches.
bool videosAreSimilar(List<PhotoFingerprint> a, List<PhotoFingerprint> b) {
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  return countMatchingFrames(a, b) >= requiredMatchedFrames(a.length, b.length);
}

/// Date order for grouping: createDate ascending, asset id as
/// the deterministic tie-break (the stills rule, grouping.dart).
int _byDate(MediaAsset a, MediaAsset b) {
  final int byDate = a.createDate.compareTo(b.createDate);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

/// Similar-video grouping, the stills seed rule with the video
/// predicate: candidates (size gate + a non-empty frame list)
/// in date order; the first remaining video is the SEED; a
/// video joins only if it is similar to the SEED itself (never
/// to another member — no transitivity); the next ungrouped
/// video becomes the next seed; groups of 1 are dropped.
/// Returns member lists, seed first, in date order.
List<List<MediaAsset>> groupSimilarVideos({
  required List<MediaAsset> assets,
  required Map<String, List<PhotoFingerprint>> framesById,
}) {
  final List<MediaAsset> pool =
      assets
          .where(
            (MediaAsset a) =>
                isSimilarVideoCandidate(a) &&
                (framesById[a.id]?.isNotEmpty ?? false),
          )
          .toList()
        ..sort(_byDate);
  final List<List<MediaAsset>> out = <List<MediaAsset>>[];
  final List<MediaAsset> remaining = List<MediaAsset>.of(pool);
  while (remaining.isNotEmpty) {
    final MediaAsset seed = remaining.first;
    final List<PhotoFingerprint> seedFrames = framesById[seed.id]!;
    final List<MediaAsset> members = <MediaAsset>[seed];
    remaining.removeAt(0);
    remaining.removeWhere((MediaAsset candidate) {
      if (videosAreSimilar(seedFrames, framesById[candidate.id]!)) {
        members.add(candidate);
        return true;
      }
      return false;
    });
    if (members.length >= 2) {
      out.add(members);
    }
  }
  return out;
}
