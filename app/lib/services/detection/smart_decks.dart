// Smart-deck predicates (requirements §7, Phase 2).
//
// Pure functions: given an asset (and, for blurry/dark, its cached
// analysis) they answer which decks it belongs to. Detection decks
// (blurry, dark) are the surface for the detection results — the
// spec lists detection separately from the deck list, and these two
// decks are where those results become actionable.
//
// Exact rules (frozen for Phase 2A):
// - screenshots: album/folder name contains "screenshot"
//   (case-insensitive). Missing/empty names never match.
// - whatsapp: album/folder name contains "whatsapp".
// - downloads: album/folder name contains "download".
// - videos: asset type is video.
// - large: sizeBytes at or over 10 MB (10 * 1024 * 1024).
// - old: createDate older than 90 days before [now].
// - bursts: computed over a date-sorted list, not per asset — see
//   [burstAssetIds]. A burst is a run of 3+ photos where every
//   consecutive gap is at most 5 seconds.
// - blurry: image with a cached analysis whose blur score is at or
//   under the blur threshold (see photo_analysis.dart). Videos are
//   never blurry-flagged: a video thumbnail frame is not the video.
// - dark: image with a cached analysis whose mean luminance is
//   under the dark threshold. Videos excluded for the same reason.
// - duplicates: not a predicate — it is the grouping result (see
//   grouping.dart) and lives on its own screen, linked from the hub.

import '../media/media_asset.dart';
import 'photo_analysis.dart';

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
  onThisDay,
}

/// Size at or over which a photo counts as "large".
const int largePhotoThresholdBytes = 10 * 1024 * 1024;

/// Age beyond which a photo counts as "old".
const Duration oldPhotoAge = Duration(days: 90);

/// Max gap between consecutive photos in a burst run.
const Duration burstMaxGap = Duration(seconds: 5);

/// Min photos in a burst run.
const int burstMinCount = 3;

/// Decks a single asset belongs to by its own metadata/analysis.
/// Bursts and duplicates are list-level and are NOT included here.
Set<SmartDeckId> decksForAsset(
  MediaAsset asset,
  Map<String, PhotoAnalysis> analyses,
  DateTime now,
) {
  final Set<SmartDeckId> decks = <SmartDeckId>{};
  final String album = asset.albumName.toLowerCase();
  if (album.contains('screenshot')) {
    decks.add(SmartDeckId.screenshots);
  }
  if (album.contains('whatsapp')) {
    decks.add(SmartDeckId.whatsapp);
  }
  if (album.contains('download')) {
    decks.add(SmartDeckId.downloads);
  }
  if (asset.type == MediaAssetType.video) {
    decks.add(SmartDeckId.videos);
  }
  if (asset.sizeBytes >= largePhotoThresholdBytes) {
    decks.add(SmartDeckId.large);
  }
  if (now.difference(asset.createDate) > oldPhotoAge) {
    decks.add(SmartDeckId.old);
  }
  if (asset.type == MediaAssetType.image) {
    final PhotoAnalysis? analysis = analyses[asset.id];
    if (analysis != null) {
      if (analysis.isBlurry) {
        decks.add(SmartDeckId.blurry);
      }
      if (analysis.isDark) {
        decks.add(SmartDeckId.dark);
      }
    }
  }
  // On This Day (Phase 2B): same month + day as today, previous
  // years only, so today's just-taken photos never dominate.
  // Feb 29 assets match only in leap years (see retention.dart).
  if (asset.createDate.month == now.month &&
      asset.createDate.day == now.day &&
      asset.createDate.year != now.year) {
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
