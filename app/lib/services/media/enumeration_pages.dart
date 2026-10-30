// Pure reads over a completed enumeration pass (fix plan
// Stage 2, ADR-017): the page and id lookups MediaServiceImpl
// serves from the pass. Split out of the implementation file
// (as media_mappings.dart was in Phase 2.1) to keep it near its
// line guide — and because these functions touch no platform
// channel, which is why they are unit-testable against canned
// passes without a MediaStore.

import 'enumerated_asset.dart';
import 'library_enumeration_service.dart';
import 'media_asset.dart';
import 'media_mappings.dart';

/// One page served from the enumeration pass, or null when the
/// pass cannot serve it (unknown album — see below) and the
/// plugin path must run. Filters mirror the plugin query
/// exactly:
/// - type: the covered kinds only (rows are only ever image or
///   video, as the plugin's kind skip produced);
/// - album: bucket id equality; the whole-library album id
///   ([wholeLibraryAlbumId]) means no bucket filter, as the
///   plugin's `isAll` path did. An album is KNOWN when any row
///   of a covered kind names its bucket — file-gone rows
///   included, because the plugin's typed path list (which
///   decided album existence) never checked backing files;
/// - month: DATE_ADDED within the month key's range, both ends
///   inclusive — the plugin's create-time condition compared
///   in whole seconds, identically. The caller validated the
///   key already (an invalid key fails the call before the
///   pass is consulted);
/// - gone files are skipped, as the plugin skipped them;
/// - stored-dimension-zero images are skipped: the plugin's
///   paged lists carried MediaStore WIDTH > 0 AND HEIGHT > 0
///   for images (see [isPluginListRow]). Id resolution below
///   does NOT skip them — the plugin's per-id path carried no
///   list filter.
List<MediaAsset>? pageFromEnumeration(
  LibraryEnumeration data, {
  required String? albumId,
  required String? monthKey,
  required MediaFilterType type,
  required int page,
  required int pageSize,
}) {
  final MediaAssetType? wanted = switch (type) {
    MediaFilterType.all => null,
    MediaFilterType.image => MediaAssetType.image,
    MediaFilterType.video => MediaAssetType.video,
  };
  final bool wholeLibrary = albumId == null || albumId == wholeLibraryAlbumId;
  if (!wholeLibrary) {
    final bool known = data.rows.any(
      (EnumeratedAsset row) =>
          row.bucketId == albumId && (wanted == null || row.type == wanted),
    );
    if (!known) {
      return null;
    }
  }
  int? startSec;
  int? endSec;
  if (monthKey != null) {
    final ({DateTime start, DateTime end}) range = parseMonthKey(monthKey)!;
    startSec = range.start.millisecondsSinceEpoch ~/ 1000;
    endSec = range.end.millisecondsSinceEpoch ~/ 1000;
  }
  final String fallback = wholeLibrary
      ? wholeLibraryAlbumName
      : (data.bucketNames[albumId] ?? '');
  final List<MediaAsset> filtered = <MediaAsset>[];
  for (final EnumeratedAsset row in data.rows) {
    if (!row.fileExists) {
      continue;
    }
    if (!isPluginListRow(row)) {
      continue;
    }
    if (wanted != null && row.type != wanted) {
      continue;
    }
    if (!wholeLibrary && row.bucketId != albumId) {
      continue;
    }
    if (startSec != null &&
        (row.dateAddedSec < startSec || row.dateAddedSec > endSec!)) {
      continue;
    }
    filtered.add(mediaAssetFromEnumerated(row, albumNameFallback: fallback));
  }
  final int start = page * pageSize;
  if (start >= filtered.length) {
    return <MediaAsset>[];
  }
  final int end = start + pageSize > filtered.length
      ? filtered.length
      : start + pageSize;
  return filtered.sublist(start, end);
}

/// Id resolution from the enumeration pass: kept ids map in
/// request order, gone ids are skipped, and the result is
/// sorted exactly as the plugin resolution sorted it
/// (createDate descending, id tiebreak). The list-level
/// dimension rule is deliberately NOT applied here: the
/// plugin's per-id path was unfiltered, so a
/// stored-dimension-zero image resolves by id exactly as it
/// did before the enumeration existed.
List<MediaAsset> assetsByIdsFromEnumeration(
  LibraryEnumeration data,
  List<String> ids,
) {
  final Map<String, EnumeratedAsset> byId = <String, EnumeratedAsset>{};
  for (final EnumeratedAsset row in data.rows) {
    if (row.fileExists) {
      byId[row.id] = row;
    }
  }
  final List<MediaAsset> assets = <MediaAsset>[];
  for (final String id in ids) {
    final EnumeratedAsset? row = byId[id];
    if (row != null) {
      assets.add(mediaAssetFromEnumerated(row, albumNameFallback: ''));
    }
  }
  assets.sort((MediaAsset a, MediaAsset b) {
    final int byDate = b.createDate.compareTo(a.createDate);
    if (byDate != 0) {
      return byDate;
    }
    return a.id.compareTo(b.id);
  });
  return assets;
}
