// One row of the one-pass library enumeration (fix plan Stage 2,
// ADR-017): every field the old paged queries returned, plus the
// file size, from ONE MediaStore query per media type — no
// per-asset calls of any kind.
//
// Rows are raw platform facts (MediaStore units kept: date added /
// modified in seconds, date taken in milliseconds). The conversion
// to [MediaAsset] lives in media_mappings.dart and mirrors the
// photo_manager entity semantics the app was built on, so the
// same library produces the same assets as before the change.

import 'media_asset.dart';

class EnumeratedAsset {
  const EnumeratedAsset({
    required this.id,
    required this.type,
    required this.title,
    required this.bucketId,
    required this.bucketName,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.storeWidth,
    required this.storeHeight,
    required this.dateAddedSec,
    required this.dateTakenMs,
    required this.dateModifiedSec,
    required this.isFavorite,
    required this.relativePath,
    required this.fileExists,
  });

  /// MediaStore id, as a string (the same form [MediaAsset.id]
  /// carries and trash/restore use).
  final String id;
  final MediaAssetType type;

  /// Display name (file name); may be empty when MediaStore has
  /// none. Screenshot marking reads this and nothing else.
  final String title;

  /// MediaStore bucket id, as a string — the same id space
  /// [MediaAlbum.id] uses, so album filters match unchanged.
  final String bucketId;

  /// Bucket display name (the folder name as MediaStore reports
  /// it); the album-name fallback for this row's bucket.
  final String bucketName;

  /// File size in bytes, from the enumeration query itself.
  final int sizeBytes;

  /// Dimensions the consumers see: the MediaStore columns
  /// exactly as stored, zeroes included. The native pass takes
  /// cursor values as-is and never opens a file to repair them
  /// (ADR-026, following Cleanup's enumerator) — before ADR-026
  /// a zero was repaired from the file header, mirroring the
  /// plugin; that repair is what could stall the pass.
  final int width;
  final int height;

  /// The MediaStore WIDTH column exactly as stored. The plugin's
  /// paged lists excluded images whose stored width or height
  /// was 0 (see [isPluginListRow]); the rule is written on the
  /// raw columns, so they ride along under their own names.
  /// Since ADR-026 removed the header repair these always equal
  /// [width] / [height] in rows the native pass produces; both
  /// fields stay because the list rule is judged on them.
  final int storeWidth;

  /// The MediaStore HEIGHT column exactly as stored — see
  /// [storeWidth].
  final int storeHeight;

  /// MediaStore DATE_ADDED, seconds since epoch. The month
  /// filter compares against this, exactly as the plugin's
  /// create-time condition did.
  final int dateAddedSec;

  /// MediaStore DATE_TAKEN, milliseconds since epoch (0 when the
  /// file carries none).
  final int dateTakenMs;

  /// MediaStore DATE_MODIFIED, seconds since epoch.
  final int dateModifiedSec;

  /// MediaStore IS_FAVORITE (Android 11+; false below).
  final bool isFavorite;

  /// MediaStore RELATIVE_PATH (Android 10+; null below, where the
  /// plugin also reported none).
  final String? relativePath;

  /// False when the backing file no longer exists. The plugin
  /// skipped such rows in its paged lists; consumers of the
  /// enumeration apply the same skip (bucket bookkeeping does
  /// not: a bucket of only-missing files still exists as an
  /// album, as it did in the plugin's path list).
  final bool fileExists;
}

/// Whether this row belonged to the plugin's paged asset lists
/// (ADR-017 §4): photo_manager's list queries carried a size
/// condition — MediaStore `WIDTH > 0 AND HEIGHT > 0` for IMAGE
/// rows, no dimension condition for videos — and wipe. never
/// ignored it (default FilterOption), so an image whose STORED
/// width or height is 0 never appeared in a page or a scan,
/// even when its file header carries real dimensions.
/// List serving applies this rule; id resolution does NOT —
/// the plugin's per-id entity path was unfiltered, so a
/// stored-dimension-zero image still resolves by id.
bool isPluginListRow(EnumeratedAsset row) {
  if (row.type != MediaAssetType.image) {
    return true;
  }
  return row.storeWidth > 0 && row.storeHeight > 0;
}

/// Screenshot marking by file name only (fix plan Stage 2, the
/// Cleanup teardown's exact rule — pipeline notes Q1): a photo
/// is a screenshot when its lower-case name contains
/// `screenshot`, `screen_shot` or `screen-shot`, or starts with
/// `screenshot_` or `screen_`. No image content is ever read for
/// this. (The starts-with cases are already covered by the
/// contains cases; they are spelled out so the rule matches the
/// teardown text word for word and stays right if the contains
/// set is ever revisited.)
bool isScreenshotAssetName(String name) {
  final String lower = name.toLowerCase();
  return lower.contains('screenshot') ||
      lower.contains('screen_shot') ||
      lower.contains('screen-shot') ||
      lower.startsWith('screenshot_') ||
      lower.startsWith('screen_');
}
