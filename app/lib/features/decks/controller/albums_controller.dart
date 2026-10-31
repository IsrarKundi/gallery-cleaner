// All Albums screen state (owner instruction 31 Oct 2026,
// ADR-027; requirements §7).
//
// The album list is the media service's own album list — the
// same getAlbums() the Clean deck's filter and the smart deck's
// album picker load — so this screen can never disagree with
// the rest of the app about what an album is. Covers are each
// album's latest asset, resolved through the same album query
// (page 0, one asset) and rendered through the shared thumbnail
// service at the hub's cover size, exactly like the hub's month
// covers.
//
// Tapping an album opens it as a swipe deck through the
// smart-deck route with a prepared asset list — the hub's own
// launch pattern (smart decks, timeline months). The session
// key is `smart:album:<bucketId>`: unique per album so resume
// works per album, and inside the `smart:` family so its marks
// flow to Review and the Trash-tab union exactly like every
// smart deck's (review_union.dart's prefix rule, ADR-015).
// Marks only — this screen never deletes; review + the native
// confirmation own removal, as everywhere else.

import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';
import '../model/decks_status.dart';
import '../model/smart_deck_launch.dart';

class AlbumsController extends GetxController {
  AlbumsController({required this.media, ThumbnailService? thumbnailService})
    : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media);

  final MediaService media;
  final ThumbnailService _thumbnails;

  /// Cover thumbnail edge: the hub's cover size (month covers,
  /// deck grid cards), so album covers share the hub's cache.
  static const int coverSize = 320;

  /// Album page size for the launch's full asset list — the
  /// Clean deck's page convention (DeckController.pageSize).
  static const int pageSize = 50;

  final Rx<DecksStatus> status = DecksStatus.loading.obs;
  final RxString errorKey = ''.obs;
  final RxList<MediaAlbum> albums = <MediaAlbum>[].obs;

  /// Album id → its latest asset's id (the cover), resolved
  /// after the list lands so rows paint first and covers pop in
  /// through the thumbnail service, like the hub's previews.
  final RxMap<String, String> coverAssetIds = <String, String>{}.obs;

  /// True while an album launch is being prepared; rows ignore
  /// taps meanwhile so a double-tap can never stack two decks.
  final RxBool opening = false.obs;

  /// A failed album launch's reason (shown as a banner over the
  /// list); the list itself stays usable.
  final RxString launchErrorKey = ''.obs;

  RxMap<String, Uint8List> get coverThumbnails =>
      _thumbnails.thumbnailsFor(coverSize);
  RxSet<String> get failedCovers => _thumbnails.failedFor(coverSize);

  /// Idempotent cover request, safe to call from build (the
  /// thumbnail service's widget path, same as the hub's).
  void requestCover(String assetId) =>
      _thumbnails.requestThumbnail(assetId, coverSize);

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Permission first, then the album list — the hub's init
  /// shape (DecksController.init): a denial shows the denied
  /// state, a failed list shows the error state, and nothing is
  /// presented as loaded that did not load.
  Future<void> init() async {
    status.value = DecksStatus.loading;
    errorKey.value = '';
    final Result<MediaPermission> permission = await media.requestPermission();
    final bool granted = permission.fold(
      onSuccess: (MediaPermission value) => value != MediaPermission.denied,
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
        return false;
      },
    );
    if (!granted) {
      status.value = DecksStatus.denied;
      if (errorKey.value.isEmpty) {
        errorKey.value = AppStrings.errorMediaPermission;
      }
      return;
    }
    final Result<List<MediaAlbum>> result = await media.getAlbums();
    final List<MediaAlbum>? loaded = result.fold(
      onSuccess: (List<MediaAlbum> value) => value,
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
        return null;
      },
    );
    if (loaded == null) {
      status.value = DecksStatus.error;
      return;
    }
    albums.assignAll(loaded);
    status.value = DecksStatus.ready;
    await _resolveCovers(loaded);
  }

  Future<void> retry() async {
    await init();
  }

  /// The denied state's second action (the hub's contract):
  /// a permanently denied grant makes the system prompt a
  /// no-op, so the user is sent to the system Settings page.
  Future<void> openPermissionSettings() async {
    await media.openAppSettings();
  }

  Future<void> _resolveCovers(List<MediaAlbum> list) async {
    await Future.wait(<Future<void>>[
      for (final MediaAlbum album in list) _resolveCover(album),
    ]);
  }

  Future<void> _resolveCover(MediaAlbum album) async {
    if (album.count <= 0) {
      return;
    }
    final Result<List<MediaAsset>> result = await media.getAssets(
      albumId: album.id,
      page: 0,
      pageSize: 1,
    );
    result.fold(
      onSuccess: (List<MediaAsset> assets) {
        if (assets.isNotEmpty) {
          coverAssetIds[album.id] = assets.first.id;
        }
      },
      onFailure: (_) {},
    );
  }

  /// Builds the swipe-deck launch for [album]: the album's full
  /// asset list through the media service's album query, paged
  /// until a short page (the Clean deck's paging shape, made
  /// eager because a launch carries its list). Null on failure,
  /// with the reason in [launchErrorKey].
  Future<SmartDeckLaunch?> buildLaunch(MediaAlbum album) async {
    final List<MediaAsset> assets = <MediaAsset>[];
    int page = 0;
    while (true) {
      final Result<List<MediaAsset>> result = await media.getAssets(
        albumId: album.id,
        page: page,
        pageSize: pageSize,
      );
      final List<MediaAsset>? batch = result.fold(
        onSuccess: (List<MediaAsset> value) => value,
        onFailure: (AppFailure failure) {
          launchErrorKey.value = failure.messageKey.isEmpty
              ? AppStrings.errorGeneric
              : failure.messageKey;
          return null;
        },
      );
      if (batch == null) {
        return null;
      }
      assets.addAll(batch);
      if (batch.length < pageSize) {
        break;
      }
      page++;
    }
    return SmartDeckLaunch(
      deckId: null,
      assets: assets,
      customSessionKey: 'smart:album:${album.id}',
      customTitle: album.name,
    );
  }

  /// Row tap: prepare the launch, then navigate. A failed
  /// preparation stays on the list with the reason bannered.
  Future<void> openAlbum(MediaAlbum album) async {
    if (opening.value) {
      return;
    }
    opening.value = true;
    launchErrorKey.value = '';
    try {
      final SmartDeckLaunch? launch = await buildLaunch(album);
      if (launch != null) {
        Get.toNamed<dynamic>(AppRoutes.smartDeck, arguments: launch);
      }
    } finally {
      opening.value = false;
    }
  }
}
