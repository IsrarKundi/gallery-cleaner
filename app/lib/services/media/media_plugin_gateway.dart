// Plugin boundary for the media service (Phase 2.1).
//
// MediaServiceImpl talks to photo_manager ONLY through this gateway
// for every platform call, so host tests can inject a counting fake
// and prove the query-pattern guarantees (one path-list call per key,
// one count per path, zero `fromId` on an entity-cache hit) without a
// platform channel. Production code uses [PhotoManagerGateway].
// (The implementation file still imports photo_manager for type names
// such as RequestType; types never touch the channel.)

import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// Every photo_manager call the media service makes, behind one seam.
abstract class MediaPluginGateway {
  Future<PermissionState> requestPermission();

  Future<void> presentLimited();

  Future<void> openSettings();

  Future<List<AssetPathEntity>> getPathList({
    required RequestType type,
    FilterOptionGroup? filterOption,
  });

  Future<int> getCount(AssetPathEntity path);

  Future<List<AssetEntity>> getPaged(AssetPathEntity path, int page, int size);

  Future<int> getFileSize(AssetEntity entity);

  Future<AssetEntity?> getEntity(String id);

  Future<Uint8List?> getThumbnailBytes(
    AssetEntity entity,
    int size,
    int quality,
  );
}

/// The real photo_manager calls, unchanged from the pre-2.1
/// implementation (including the Phase 1.5 explicit JPEG quality).
class PhotoManagerGateway implements MediaPluginGateway {
  @override
  Future<PermissionState> requestPermission() {
    return PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.common,
          mediaLocation: false,
        ),
      ),
    );
  }

  @override
  Future<void> presentLimited() {
    return PhotoManager.presentLimited(type: RequestType.common);
  }

  @override
  Future<void> openSettings() {
    return PhotoManager.openSetting();
  }

  @override
  Future<List<AssetPathEntity>> getPathList({
    required RequestType type,
    FilterOptionGroup? filterOption,
  }) {
    return PhotoManager.getAssetPathList(
      hasAll: true,
      type: type,
      filterOption: filterOption,
    );
  }

  @override
  Future<int> getCount(AssetPathEntity path) {
    return path.assetCountAsync;
  }

  @override
  Future<List<AssetEntity>> getPaged(AssetPathEntity path, int page, int size) {
    return path.getAssetListPaged(page: page, size: size);
  }

  @override
  Future<int> getFileSize(AssetEntity entity) {
    return entity.fileSize;
  }

  @override
  Future<AssetEntity?> getEntity(String id) {
    return AssetEntity.fromId(id);
  }

  @override
  Future<Uint8List?> getThumbnailBytes(
    AssetEntity entity,
    int size,
    int quality,
  ) {
    return entity.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      format: ThumbnailFormat.jpeg,
      quality: quality,
    );
  }
}
