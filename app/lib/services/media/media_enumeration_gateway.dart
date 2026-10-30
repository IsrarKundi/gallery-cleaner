// Platform boundary for the one-pass enumeration (fix plan
// Stage 2, ADR-017), in the same shape as [MediaPluginGateway]:
// the service talks to the platform only through this seam, so
// host tests inject a counting fake and prove the one-pass
// guarantees (one call per type per pass, zero per-asset calls)
// without a platform channel.
//
// The production gateway is wipe.'s OWN native query
// (MediaEnumerationChannel.kt, registered by MainActivity):
// photo_manager 3.12 cannot return file size in its list pass —
// its converted entity map has no size field and `fileSize` is
// a separate per-id query — so the pass that must carry size
// cannot be the plugin's. The plan allows exactly this: a small
// native query of our own, same idea, our code.

import 'package:flutter/services.dart';

import 'enumerated_asset.dart';
import 'media_asset.dart';

/// The two enumeration passes: one per media type.
abstract class MediaEnumerationGateway {
  Future<List<EnumeratedAsset>> enumerateImages();

  Future<List<EnumeratedAsset>> enumerateVideos();
}

/// Production gateway over the app's own MethodChannel. Each
/// method is ONE native MediaStore query (see the Kotlin side);
/// a platform error propagates and the enumeration service maps
/// it to its media-load failure — callers then fall back to the
/// legacy plugin path (ADR-017).
class NativeMediaEnumerationGateway implements MediaEnumerationGateway {
  static const MethodChannel _channel = MethodChannel(
    'mobile.wipe.app/media_enumeration',
  );

  @override
  Future<List<EnumeratedAsset>> enumerateImages() {
    return _enumerate('enumerateImages', MediaAssetType.image);
  }

  @override
  Future<List<EnumeratedAsset>> enumerateVideos() {
    return _enumerate('enumerateVideos', MediaAssetType.video);
  }

  Future<List<EnumeratedAsset>> _enumerate(
    String method,
    MediaAssetType type,
  ) async {
    final List<dynamic>? raw = await _channel.invokeListMethod<dynamic>(method);
    if (raw == null) {
      throw StateError('media enumeration returned no rows');
    }
    return raw
        .map(
          (dynamic entry) => _rowFromMap(entry as Map<dynamic, dynamic>, type),
        )
        .toList();
  }

  /// The Kotlin side sends MediaStore's numeric ids/sizes as
  /// integers; ids and bucket ids become the string forms the
  /// rest of the app uses. The row's media type is the pass that
  /// produced it (authoritative), never a payload field.
  EnumeratedAsset _rowFromMap(Map<dynamic, dynamic> map, MediaAssetType type) {
    return EnumeratedAsset(
      id: '${map['id']}',
      type: type,
      title: (map['title'] as String?) ?? '',
      bucketId: '${map['bucketId']}',
      bucketName: (map['bucketName'] as String?) ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      storeWidth: (map['storeWidth'] as num?)?.toInt() ?? 0,
      storeHeight: (map['storeHeight'] as num?)?.toInt() ?? 0,
      dateAddedSec: (map['dateAddedSec'] as num?)?.toInt() ?? 0,
      dateTakenMs: (map['dateTakenMs'] as num?)?.toInt() ?? 0,
      dateModifiedSec: (map['dateModifiedSec'] as num?)?.toInt() ?? 0,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      relativePath: map['relativePath'] as String?,
      fileExists: (map['fileExists'] as bool?) ?? false,
    );
  }
}
