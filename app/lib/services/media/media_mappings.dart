// Pure photo_manager mappings for the media service.
//
// Split out of media_service_impl.dart in Phase 2.1 so the
// implementation file stays under the ~400-line cap. These helpers
// touch no platform channel, which is why they are unit-testable
// without a MediaStore (see test/services/media/media_mappings_test.dart).

import 'package:photo_manager/photo_manager.dart';

import 'media_asset.dart';

/// Maps photo_manager's permission state to Klara's three states.
///
/// `authorized` is full access; `limited` is Android 14 user-selected
/// partial access (requirements §5); everything else — denied,
/// restricted, not determined — is treated as denied by the caller,
/// which re-prompts or shows the denied message.
MediaPermission mapPermissionState(PermissionState state) {
  switch (state) {
    case PermissionState.authorized:
      return MediaPermission.grantedFull;
    case PermissionState.limited:
      return MediaPermission.grantedLimited;
    case PermissionState.denied:
    case PermissionState.restricted:
    case PermissionState.notDetermined:
      return MediaPermission.denied;
  }
}

/// Maps a deck filter to photo_manager's request type.
RequestType mapFilterType(MediaFilterType filter) {
  switch (filter) {
    case MediaFilterType.all:
      return RequestType.common;
    case MediaFilterType.image:
      return RequestType.image;
    case MediaFilterType.video:
      return RequestType.video;
  }
}

/// Maps a photo_manager asset type to Klara's type, or null for kinds
/// the deck never shows (audio/other). Callers skip null results.
MediaAssetType? mapAssetType(AssetType type) {
  switch (type) {
    case AssetType.image:
      return MediaAssetType.image;
    case AssetType.video:
      return MediaAssetType.video;
    case AssetType.audio:
    case AssetType.other:
      return null;
  }
}

/// MediaStore type int for a Klara type (AssetType index: image = 1,
/// video = 2). Used when rebuilding entities for a trash restore.
int typeIntFor(MediaAssetType type) {
  switch (type) {
    case MediaAssetType.image:
      return 1;
    case MediaAssetType.video:
      return 2;
  }
}

/// Parses a `yyyy-MM` month key into the half-open month range
/// [start, end), or null when the key is not a valid month.
///
/// Pure so month filtering is testable without MediaStore.
({DateTime start, DateTime end})? parseMonthKey(String monthKey) {
  final List<String> parts = monthKey.split('-');
  if (parts.length != 2) {
    return null;
  }
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return null;
  }
  final DateTime start = DateTime(year, month);
  final DateTime end = month == 12
      ? DateTime(year + 1, 1)
      : DateTime(year, month + 1);
  return (start: start, end: end);
}
