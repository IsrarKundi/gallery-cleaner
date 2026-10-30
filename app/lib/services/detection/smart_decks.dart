// Smart-deck predicates (requirements §7, Phase 2).
//
// Pure functions: given an asset they answer which decks it
// belongs to by its own metadata. The detection decks (blurry,
// dark) and duplicates are NOT predicates here — since fix plan
// Stage 4 they are scan memberships (scan_memberships.dart),
// applied by the hub from the completed scan's persisted
// product; a per-asset predicate cannot know them anymore
// because fingerprints and blur scores are no longer cached.
//
// Exact rules:
// - screenshots: Stage 2's file-name marking
//   (MediaAsset.isScreenshot — the Cleanup name rules), NOT the
//   old album/folder-name guess. Stage 4 item 8: membership now
//   follows the pass marking, so a screenshot-named file in any
//   folder joins, and a folder named "Screenshots" no longer
//   pulls in files whose names do not match.
// - whatsapp: album/folder name contains "whatsapp".
// - downloads: album/folder name contains "download".
// - videos: asset type is video.
// - large: sizeBytes at or over 10 MB (10 * 1024 * 1024).
// - old: createDate older than 90 days before [now].
// - bursts: computed over a date-sorted list, not per asset — see
//   [burstAssetIds]. A burst is a run of 3+ photos where every
//   consecutive gap is at most 5 seconds.
// - duplicates / blurry / dark: scan memberships — see above.
// - similarVideos: scan memberships too (fix plan Stage 6) —
//   the union of the scan's similar-video groups, applied by
//   the hub like blurry/dark. Never a per-asset predicate: it
//   needs frame fingerprints only the scan computes.

import 'dart:isolate';

import '../media/media_asset.dart';

/// Smart decks shown on the hub, in display order.
enum SmartDeckId {
  screenshots,
  whatsapp,
  downloads,
  videos,
  large,
  old,
  bursts,
  blurry,
  dark,
  duplicates,
  similarVideos,
  onThisDay,
  camera,
}

/// Size at or over which a photo counts as "large".
const int largePhotoThresholdBytes = 10 * 1024 * 1024;

/// Age beyond which a photo counts as "old".
const Duration oldPhotoAge = Duration(days: 90);

/// Max gap between consecutive photos in a burst run.
const Duration burstMaxGap = Duration(seconds: 5);

/// Min photos in a burst run.
const int burstMinCount = 3;

/// Decks a single asset belongs to by its own metadata. Bursts,
/// duplicates, blurry and dark are list-level (scan results) and
/// are NOT included here.
Set<SmartDeckId> decksForAsset(MediaAsset asset, DateTime now) {
  final Set<SmartDeckId> decks = <SmartDeckId>{};
  final String album = asset.albumName.toLowerCase();
  final String title = asset.title.toLowerCase();

  if (asset.isScreenshot) {
    decks.add(SmartDeckId.screenshots);
  }
  if (album.contains('whatsapp') ||
      title.contains('-wa') ||
      title.contains('whatsapp')) {
    decks.add(SmartDeckId.whatsapp);
  }
  if (album.contains('camera') ||
      album == 'dcim' ||
      title.startsWith('img_') ||
      title.startsWith('pxl_')) {
    decks.add(SmartDeckId.camera);
  }
  if (album.contains('download') || title.contains('download')) {
    decks.add(SmartDeckId.downloads);
  }
  if (asset.type == MediaAssetType.video) {
    decks.add(SmartDeckId.videos);
  }
  if (asset.type == MediaAssetType.image &&
      asset.sizeBytes >= largePhotoThresholdBytes) {
    decks.add(SmartDeckId.large);
  }
  if (now.difference(asset.createDate) > oldPhotoAge) {
    decks.add(SmartDeckId.old);
  }
  // On This Day / Memories (Phase 2B): same month as today from past
  // years, or photos taken today.
  final bool isSameMonthPreviousYear =
      asset.createDate.month == now.month && asset.createDate.year != now.year;
  final bool isToday =
      asset.createDate.year == now.year &&
      asset.createDate.month == now.month &&
      asset.createDate.day == now.day;
  if (isSameMonthPreviousYear || isToday) {
    decks.add(SmartDeckId.onThisDay);
  }
  return decks;
}

/// Ids of assets that belong to a burst: sort [assets] by createDate
/// ascending, split into runs where consecutive gaps exceed
/// [burstMaxGap], and keep every asset in runs of [burstMinCount]
/// or more. Videos are excluded — a burst is a photo-shoot run.
/// Ties in createDate (gap 0) count as consecutive: same-second
/// shots are exactly what burst mode produces.
Set<String> burstAssetIds(List<MediaAsset> assets) {
  final List<MediaAsset> photos =
      assets.where((MediaAsset a) => a.type == MediaAssetType.image).toList()
        ..sort((MediaAsset a, MediaAsset b) {
          final int byDate = a.createDate.compareTo(b.createDate);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
  final Set<String> burstIds = <String>{};
  List<MediaAsset> run = <MediaAsset>[];
  void flush() {
    if (run.length >= burstMinCount) {
      for (final MediaAsset asset in run) {
        burstIds.add(asset.id);
      }
    }
    run = <MediaAsset>[];
  }

  for (final MediaAsset asset in photos) {
    if (run.isNotEmpty &&
        asset.createDate.difference(run.last.createDate) > burstMaxGap) {
      flush();
    }
    run.add(asset);
  }
  flush();
  return burstIds;
}

/// A burst runner of this shape, so the hub can inject a gated
/// runner in tests to prove stale-result drops.
typedef BurstRunner = Future<Set<String>> Function(List<MediaAsset> assets);

/// The production burst runner: [burstAssetIds] on a worker
/// isolate (it sorts the whole library; the hub must not pay
/// that on the UI thread).
Future<Set<String>> burstAssetIdsOnIsolate(List<MediaAsset> assets) {
  return Isolate.run(() => burstAssetIds(assets));
}
