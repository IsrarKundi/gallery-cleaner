// Shared media records for the deck, review and trash controllers.
//
// These types live in the media service folder on purpose (AGENTS.md):
// controllers import service types, never another feature's model.
// No photo content lives here — only ids, dimensions, sizes and dates.

/// Image or video. Audio is out of scope: the deck requests common
/// (image + video) only, so anything else is skipped at the mapping step.
enum MediaAssetType { image, video }

/// How much of the library the user granted (requirements §5).
///
/// Android 14 partial access is a distinct state: the app works on
/// exactly the granted photos and must say so, so controllers need
/// [grantedLimited] kept apart from [grantedFull].
enum MediaPermission { grantedFull, grantedLimited, denied }

/// Which media kinds a query covers.
enum MediaFilterType { all, image, video }

/// One library asset, as the deck sees it.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.createDate,
    required this.title,
    required this.albumName,
  });

  /// MediaStore id. This is the only handle trash/restore need.
  final String id;
  final MediaAssetType type;
  final int width;
  final int height;

  /// File size in bytes, for the review counts and space meter.
  final int sizeBytes;
  final DateTime createDate;

  /// Display name (may be empty when MediaStore has none).
  final String title;

  /// Album/folder the asset was read from.
  final String albumName;
}

/// One album/folder from the library, with its asset count.
class MediaAlbum {
  const MediaAlbum({required this.id, required this.name, required this.count});

  final String id;
  final String name;
  final int count;
}
