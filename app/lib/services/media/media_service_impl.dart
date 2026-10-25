// photo_manager implementation of [MediaService].
//
// This is a media service implementation file: it never deletes,
// trashes or writes anything — read access only. All failures are
// converted to string-keyed [AppFailure]s; no exception text, stack
// trace or photo content ever leaves this file.
//
// Phase 2.1 query pattern (performance-issues RC-A, solutions 2.1):
// path lists are cached per (type, month, albums) key, album counts
// are cached per path id, and entities resolved by [getAssets] are
// kept in a bounded cache so [getThumbnail] skips `fromId` on a hit.
// Counts and file sizes run in bounded-parallel chunks (8 / 16), so a
// page still returns populated sizes without serial awaits. Caches
// are invalidated only when the granted permission state changes —
// a grant expansion must not reuse limited-grant paths. Library
// changes mid-session are picked up on the next launch; the Phase 4
// change observer is the proper fix, not cache-busting here.

import 'dart:collection';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'media_asset.dart';
import 'media_mappings.dart';
import 'media_plugin_gateway.dart';
import 'media_service.dart';

class MediaServiceImpl implements MediaService {
  MediaServiceImpl({MediaPluginGateway? gateway})
    : _gateway = gateway ?? PhotoManagerGateway();

  final MediaPluginGateway _gateway;

  /// Path lists by query shape. Album listings and asset pages use
  /// different filter options, so they never share an entry: reusing
  /// a no-filter path for a month-filtered page would silently drop
  /// the month filter.
  final Map<
    ({RequestType type, String? monthKey, bool albums}),
    List<AssetPathEntity>
  >
  _pathLists =
      <
        ({RequestType type, String? monthKey, bool albums}),
        List<AssetPathEntity>
      >{};

  /// Album counts by path id, filled on the first [getAlbums] call.
  final Map<String, int> _counts = <String, int>{};

  /// Entities by id, in access order (bounded LRU). Populated by
  /// [getAssets] and by [getThumbnail] misses; a hit skips `fromId`.
  final LinkedHashMap<String, AssetEntity> _entities =
      LinkedHashMap<String, AssetEntity>();

  /// Last permission state seen, for cache invalidation.
  MediaPermission? _lastPermission;

  /// Bounded parallelism for count and size queries (solutions 2.1).
  static const int _countParallelism = 8;
  static const int _sizeParallelism = 16;

  /// Entity-cache bound: far above any page or window, far below a
  /// whole-library map (solutions 2.1).
  static const int _entityCacheMax = 2048;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    try {
      final PermissionState state = await _gateway.requestPermission();
      final MediaPermission permission = mapPermissionState(state);
      if (_lastPermission != null && _lastPermission != permission) {
        _invalidateCaches();
      }
      _lastPermission = permission;
      return Success<MediaPermission>(permission);
    } catch (_) {
      return const Failure<MediaPermission>(
        AppFailure(messageKey: AppStrings.errorMediaPermission),
      );
    }
  }

  @override
  Future<Result<void>> presentLimitedSelection() async {
    try {
      await _gateway.presentLimited();
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorMediaPermission),
      );
    }
  }

  @override
  Future<Result<void>> openAppSettings() async {
    try {
      await _gateway.openSettings();
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        AppFailure(messageKey: AppStrings.errorGeneric),
      );
    }
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    try {
      final List<AssetPathEntity> paths = await _paths(
        type: RequestType.common,
        albums: true,
      );
      final List<int> counts = await _countsFor(paths);
      final List<MediaAlbum> albums = <MediaAlbum>[];
      for (int i = 0; i < paths.length; i++) {
        albums.add(
          MediaAlbum(id: paths[i].id, name: paths[i].name, count: counts[i]),
        );
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
      final List<AssetPathEntity> paths = await _paths(
        type: mapFilterType(type),
        monthKey: monthKey,
      );
      final AssetPathEntity? path = albumId == null
          ? paths.where((AssetPathEntity p) => p.isAll).firstOrNull
          : paths.where((AssetPathEntity p) => p.id == albumId).firstOrNull;
      if (path == null) {
        return const Failure<List<MediaAsset>>(
          AppFailure(messageKey: AppStrings.errorMediaAlbum),
        );
      }
      final List<AssetEntity> entities = await _gateway.getPaged(
        path,
        page,
        pageSize,
      );
      for (final AssetEntity entity in entities) {
        _rememberEntity(entity);
      }
      // Keep only kinds the deck shows, before sizing, so skipped
      // kinds never pay a fileSize call (same set as before 2.1).
      final List<({AssetEntity entity, MediaAssetType type})> kept =
          <({AssetEntity entity, MediaAssetType type})>[];
      for (final AssetEntity entity in entities) {
        final MediaAssetType? assetType = mapAssetType(entity.type);
        if (assetType != null) {
          kept.add((entity: entity, type: assetType));
        }
      }
      final List<int> sizes = await _sizesFor(
        kept
            .map((({AssetEntity entity, MediaAssetType type}) e) => e.entity)
            .toList(),
      );
      final List<MediaAsset> assets = <MediaAsset>[];
      for (int i = 0; i < kept.length; i++) {
        final AssetEntity entity = kept[i].entity;
        final String album = _resolveAlbumName(entity.relativePath, path.name);
        assets.add(
          MediaAsset(
            id: entity.id,
            type: kept[i].type,
            width: entity.width,
            height: entity.height,
            sizeBytes: sizes[i],
            createDate: entity.createDateTime,
            title: entity.title ?? '',
            albumName: album,
            isSystemFavourite: entity.isFavorite,
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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    try {
      final AssetEntity? entity =
          _entities[assetId] ?? await _gateway.getEntity(assetId);
      if (entity == null) {
        return const Failure<Uint8List>(
          AppFailure(messageKey: AppStrings.errorMediaLoad),
        );
      }
      _rememberEntity(entity);
      // Phase 1.5: explicit format + quality (was implicit JPEG q100).
      final Uint8List? bytes = await _gateway.getThumbnailBytes(
        entity,
        size,
        quality,
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

  /// Cached path list for one query shape, or one gateway call on a
  /// miss. The album-listing shape and asset-page shapes are distinct
  /// keys, so a month filter is never silently dropped by reuse.
  Future<List<AssetPathEntity>> _paths({
    required RequestType type,
    String? monthKey,
    bool albums = false,
  }) async {
    final ({RequestType type, String? monthKey, bool albums}) key = (
      type: type,
      monthKey: monthKey,
      albums: albums,
    );
    final List<AssetPathEntity>? cached = _pathLists[key];
    if (cached != null) {
      return cached;
    }
    final List<AssetPathEntity> paths = await _gateway.getPathList(
      type: type,
      filterOption: albums ? null : _filterOption(monthKey),
    );
    _pathLists[key] = paths;
    return paths;
  }

  /// Counts for [paths], cached per path id, computed in bounded
  /// parallel chunks instead of one serial await per path.
  Future<List<int>> _countsFor(List<AssetPathEntity> paths) async {
    final List<int> results = List<int>.filled(paths.length, 0);
    for (int start = 0; start < paths.length; start += _countParallelism) {
      final int end = start + _countParallelism > paths.length
          ? paths.length
          : start + _countParallelism;
      final List<int> chunk = await Future.wait(<Future<int>>[
        for (int i = start; i < end; i++) _countFor(paths[i]),
      ]);
      for (int i = 0; i < chunk.length; i++) {
        results[start + i] = chunk[i];
      }
    }
    return results;
  }

  Future<int> _countFor(AssetPathEntity path) async {
    final int? cached = _counts[path.id];
    if (cached != null) {
      return cached;
    }
    final int count = await _gateway.getCount(path);
    _counts[path.id] = count;
    return count;
  }

  /// File sizes for [entities] in bounded parallel chunks, in order.
  /// A single unreadable size must not fail the whole page; the
  /// review meter treats it as unknown (0) for that asset.
  Future<List<int>> _sizesFor(List<AssetEntity> entities) async {
    final List<int> sizes = List<int>.filled(entities.length, 0);
    for (int start = 0; start < entities.length; start += _sizeParallelism) {
      final int end = start + _sizeParallelism > entities.length
          ? entities.length
          : start + _sizeParallelism;
      final List<int> chunk = await Future.wait(<Future<int>>[
        for (int i = start; i < end; i++) _sizeFor(entities[i]),
      ]);
      for (int i = 0; i < chunk.length; i++) {
        sizes[start + i] = chunk[i];
      }
    }
    return sizes;
  }

  Future<int> _sizeFor(AssetEntity entity) async {
    try {
      return await _gateway.getFileSize(entity);
    } catch (_) {
      return 0;
    }
  }

  void _rememberEntity(AssetEntity entity) {
    _entities.remove(entity.id);
    _entities[entity.id] = entity;
    while (_entities.length > _entityCacheMax) {
      _entities.remove(_entities.keys.first);
    }
  }

  void _invalidateCaches() {
    _pathLists.clear();
    _counts.clear();
    _entities.clear();
  }

  static String _resolveAlbumName(String? relativePath, String fallback) {
    if (relativePath != null && relativePath.trim().isNotEmpty) {
      final String trimmed = relativePath.trim();
      final List<String> segments = trimmed
          .split(RegExp(r'[/\\]'))
          .where((String s) => s.isNotEmpty)
          .toList();
      if (segments.isNotEmpty) {
        return segments.last;
      }
    }
    return fallback;
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
