// photo_manager implementation of [MediaService].
//
// This is the ONLY media file importing photo_manager. It never
// deletes, trashes or writes anything — read access only. All
// failures are converted to string-keyed [AppFailure]s; no exception
// text, stack trace or photo content ever leaves this file.

import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'media_asset.dart';
import 'media_service.dart';

class MediaServiceImpl implements MediaService {
  @override
  Future<Result<MediaPermission>> requestPermission() async {
    try {
      final PermissionState state = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
      return Success<MediaPermission>(mapPermissionState(state));
    } catch (_) {
      return const Failure<MediaPermission>(
        AppFailure(messageKey: AppStrings.errorMediaPermission),
      );
    }
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        hasAll: true,
        type: RequestType.common,
      );
      final List<MediaAlbum> albums = <MediaAlbum>[];
      for (final AssetPathEntity path in paths) {
        final int count = await path.assetCountAsync;
        albums.add(MediaAlbum(id: path.id, name: path.name, count: count));
      }
      return Success<List<MediaAlbum>>(albums);
    } catch (_) {
      return const Failure<List<MediaAlbum>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      final FilterOptionGroup? filterOption = _filterOption(monthKey);
      if (filterOption == null) {
        // Invalid month key: fail, never silently widen to all dates.
        return const Failure<List<MediaAsset>>(
          AppFailure(messageKey: AppStrings.errorMediaLoad),
        );
      }
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        hasAll: true,
        type: mapFilterType(type),
        filterOption: filterOption,
      );
      final AssetPathEntity? path = albumId == null
          ? paths.where((AssetPathEntity p) => p.isAll).firstOrNull
          : paths.where((AssetPathEntity p) => p.id == albumId).firstOrNull;
      if (path == null) {
        return const Failure<List<MediaAsset>>(
          AppFailure(messageKey: AppStrings.errorMediaAlbum),
        );
      }
      final List<AssetEntity> entities = await path.getAssetListPaged(
        page: page,
        size: pageSize,
      );
      final List<MediaAsset> assets = <MediaAsset>[];
      for (final AssetEntity entity in entities) {
        final MediaAssetType? assetType = mapAssetType(entity.type);
        if (assetType == null) {
          continue;
        }
        int sizeBytes = 0;
        try {
          sizeBytes = await entity.fileSize;
        } catch (_) {
          // A single unreadable size must not fail the whole page;
          // the review meter treats it as unknown (0) for that asset.
          sizeBytes = 0;
        }
        assets.add(
          MediaAsset(
            id: entity.id,
            type: assetType,
            width: entity.width,
            height: entity.height,
            sizeBytes: sizeBytes,
            createDate: entity.createDateTime,
            title: entity.title ?? '',
            albumName: path.name,
          ),
        );
      }
      return Success<List<MediaAsset>>(assets);
    } catch (_) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
  }

  /// Builds the query filter. A month key becomes a create-time
  /// condition; without one the condition is ignored (all dates).
  /// Returns null for an invalid month key. `needTitle` is on so
  /// [MediaAsset.title] is populated.
  FilterOptionGroup? _filterOption(String? monthKey) {
    DateTimeCond createTimeCond = DateTimeCond.def().copyWith(ignore: true);
    if (monthKey != null) {
      final ({DateTime start, DateTime end})? range = parseMonthKey(monthKey);
      if (range == null) {
        return null;
      }
      createTimeCond = DateTimeCond(min: range.start, max: range.end);
    }
    return FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(needTitle: true),
      createTimeCond: createTimeCond,
    );
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    try {
      final AssetEntity? entity = await AssetEntity.fromId(assetId);
      if (entity == null) {
        return const Failure<Uint8List>(
          AppFailure(messageKey: AppStrings.errorMediaLoad),
        );
      }
      final Uint8List? bytes = await entity.thumbnailDataWithSize(
        ThumbnailSize.square(size),
      );
      if (bytes == null) {
        return const Failure<Uint8List>(
          AppFailure(messageKey: AppStrings.errorMediaLoad),
        );
      }
      return Success<Uint8List>(bytes);
    } catch (_) {
      return const Failure<Uint8List>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final E element in this) {
      return element;
    }
    return null;
  }
}

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
