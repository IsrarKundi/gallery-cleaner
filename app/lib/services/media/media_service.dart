// Media library access: permission, albums, assets, thumbnails.
//
// Interface only — the implementation is the single file allowed to
// import photo_manager (AGENTS.md dependency rules). Every method
// returns [Result]; failures carry string keys, never exception text.
// No method here reads, logs or sends photo content: thumbnails are
// bytes handed to the deck for display only.

import 'dart:typed_data';

import '../../core/utils/result.dart';
import 'media_asset.dart';

abstract class MediaService {
  /// Requests photo access and reports the grant distinctly:
  /// [MediaPermission.grantedFull], [MediaPermission.grantedLimited]
  /// (Android 14 user-selected partial access — the deck works on
  /// exactly those photos and says so) or [MediaPermission.denied].
  Future<Result<MediaPermission>> requestPermission();

  /// Phase 3B partial-access recovery (photo_manager 3.12.0
  /// `PhotoManager.presentLimited`, Android 14+): shows the system
  /// photo picker so the user can ADD photos to a limited grant.
  /// This is honest re-selection, not a full-access grant: only the
  /// system Settings page can switch a grant to "Allow all photos"
  /// (see [openAppSettings]). Completes when the picker dismisses;
  /// the caller re-checks permission and reloads afterwards.
  Future<Result<void>> presentLimitedSelection();

  /// Phase 3B denied/permanent-denial recovery (photo_manager
  /// 3.12.0 `PhotoManager.openSetting`): opens this app's system
  /// Settings page, where the user can change photo access to
  /// "Allow all photos". The system gives no result callback, so
  /// the caller must re-check permission when the user returns
  /// (the deck's "Add more photos" action does exactly that).
  Future<Result<void>> openAppSettings();

  /// Album/folder list with asset counts, including the whole-library
  /// ("Recent") album. Type filter is not applied here: album counts
  /// are for the filter picker, which then filters in [getAssets].
  Future<Result<List<MediaAlbum>>> getAlbums();

  /// One page of assets from an album, newest first.
  ///
  /// [albumId] null means the whole-library album. [monthKey] is
  /// `yyyy-MM` and restricts to assets created in that month; an
  /// invalid key fails the call rather than silently returning all.
  /// [page] is zero-based; [pageSize] must be positive.
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  });

  /// Thumbnail bytes for one asset at [size] x [size] pixels, for
  /// deck preloading. Returns the raw bytes; the deck renders them.
  ///
  /// Phase 1.5: [quality] is explicit JPEG quality (default 85 for
  /// display — the plugin's implicit q100 was the largest byte count
  /// for no visible gain). Analysis callers MUST pass 100: cached
  /// analyses were hashed from q100 thumbnails, and a quality change
  /// would silently mix hash versions (issues file F-12).
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  });
}
