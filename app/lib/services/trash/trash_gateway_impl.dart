// photo_manager gateway for the trash service.
//
// PROVEN FROM PACKAGE SOURCE (photo_manager 3.12.0, resolved in the
// pub cache — not from marketing copy):
// * `PhotoManager.editor.android.moveToTrash` (lib/src/internal/editor.dart)
//   calls the `moveToTrash` platform method (lib/src/internal/
//   plugin.dart), which the Android plugin routes
//   (android/.../core/PhotoManagerPlugin.kt, `Methods.moveToTrash`)
//   to `PhotoManagerDeleteManager.moveToTrashInApi30`, which calls
//   `MediaStore.createTrashRequest(cr, uris, true)` and shows the
//   system confirmation sheet. On user cancel the result handler
//   replies with an empty list — that is how denial is detected.
// * `restoreFromTrash` follows the identical path with
//   `createTrashRequest(cr, uris, false)`.
// * `deleteWithIds` on API 30+ calls `MediaStore.createDeleteRequest`
//   (the native sheet for removal); below API 30 it has no sheet
//   path, which is why [TrashServiceImpl] gates emptying on API 30+.
// * All three trash paths require API 30+ in the plugin itself.
// No custom MethodChannel was needed: photo_manager provably trashes.

import 'package:photo_manager/photo_manager.dart';

class TrashGatewayImpl implements TrashGateway {
  @override
  Future<int> sdkInt() async {
    final String version = await PhotoManager.systemVersion();
    return int.tryParse(version) ?? 0;
  }

  @override
  Future<ResolvedAssets> resolveAssets(List<String> ids) async {
    final List<AssetEntity> found = <AssetEntity>[];
    final List<String> missing = <String>[];
    for (final String id in ids) {
      final AssetEntity? entity = await AssetEntity.fromId(id);
      if (entity == null) {
        missing.add(id);
      } else {
        found.add(entity);
      }
    }
    return (found: found, missing: missing);
  }

  @override
  Future<int> assetSize(AssetEntity entity) async {
    return entity.fileSize;
  }

  @override
  Future<List<String>> moveToTrash(List<AssetEntity> entities) {
    return PhotoManager.editor.android.moveToTrash(entities);
  }

  @override
  Future<List<String>> restoreFromTrash(List<AssetEntity> entities) {
    return PhotoManager.editor.android.restoreFromTrash(entities);
  }

  @override
  Future<List<String>> deleteIds(List<AssetEntity> entities) {
    return PhotoManager.editor.deleteWithIds(
      entities.map((AssetEntity e) => e.id).toList(),
    );
  }
}

/// What [TrashGateway.resolveAssets] returns: entities the platform
/// could still resolve, plus ids it could not (already gone, or bad).
typedef ResolvedAssets = ({List<AssetEntity> found, List<String> missing});

abstract class TrashGateway {
  /// Android SDK int (Build.VERSION.SDK_INT). Trash, restore and
  /// sheet-gated emptying all require API 30+.
  Future<int> sdkInt();

  /// Resolves ids to entities; unresolvable ids land in [missing]
  /// instead of throwing, so the caller can report them as failed.
  Future<ResolvedAssets> resolveAssets(List<String> ids);

  /// File size in bytes for one resolved entity.
  Future<int> assetSize(AssetEntity entity);

  /// System trash request. Returns the ids the user confirmed; an
  /// empty list means the user denied the sheet (nothing trashed).
  Future<List<String>> moveToTrash(List<AssetEntity> entities);

  /// System restore-from-trash request. Same return contract.
  Future<List<String>> restoreFromTrash(List<AssetEntity> entities);

  /// System delete request (the native sheet on API 30+). Returns
  /// the ids the user confirmed for removal.
  Future<List<String>> deleteIds(List<AssetEntity> entities);
}
