// Duplicates screen state (requirements §7, Phase 2).
//
// Loads the library through the shared scanner (metadata re-scan,
// but hashes/scores come from the LocalService cache — no thumbnail
// re-download for already-analysed assets), groups from the cache,
// and regroups LIVE as the similarity slider moves: regrouping is a
// pure recompute over cached hashes, never a thumbnail reload.
// Thumbnails for newly grouped members load after each regroup.
//
// Keeper changes are local until "Mark others for deletion": that
// action writes delete marks for the group's non-keepers (and keep
// marks for the keeper, so it never reappears undecided) into the
// `duplicates` session and navigates to /review with the non-keeper
// list — the same arguments + filterKey contract the deck uses.
// Nothing is deleted here; review + native confirmation still own
// removal (requirements §4).

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/photo_analysis.dart';
import '../../../services/local/local_service.dart';
import '../../../services/local/protection.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/decks_status.dart';

class DuplicatesController extends GetxController {
  DuplicatesController({required this.media, required this.local});

  final MediaService media;
  final LocalService local;

  /// Similarity slider: Hamming distance range 0-10, default 5.
  /// Default 5 is the middle of the range: tight enough that groups
  /// look genuinely alike, loose enough to catch re-saves and
  /// crops that shift a few hash bits.
  static const int sliderMin = 0;
  static const int sliderMax = 10;
  static const int defaultThreshold = 5;

  /// Session key for marks written by "mark non-keepers".
  static const String sessionKey = 'duplicates';

  /// Grid tile thumbnail edge in pixels.
  static const int thumbnailSize = 256;

  final Rx<DecksStatus> status = DecksStatus.loading.obs;
  final RxString errorKey = ''.obs;
  final RxInt threshold = defaultThreshold.obs;
  final RxList<DuplicateGroup> groups = <DuplicateGroup>[].obs;
  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxSet<String> failedThumbnails = <String>{}.obs;

  /// Phase 3A: favourited non-keepers kept out of a delete-marking
  /// run (count shown as a banner in the view, never silent).
  final RxInt protectedExcludedCount = 0.obs;

  List<MediaAsset> _assets = <MediaAsset>[];
  Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};

  /// Threshold the current groups were computed at. The slider's live
  /// drag only previews ([previewThreshold]); [commitThreshold]
  /// regroups once per release, and only when the previewed value
  /// differs from this one — a drag that returns to its start value
  /// costs no regroup at all.
  int _groupedThreshold = defaultThreshold;

  @override
  void onInit() {
    super.onInit();
    init();
  }

  Future<void> init() async {
    status.value = DecksStatus.loading;
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
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan scan = await scanner.scan();
    if (scan.pageFailed && scan.assets.isEmpty) {
      status.value = DecksStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    _assets = scan.assets;
    _analyses = scan.analyses;
    _regroup();
    status.value = DecksStatus.ready;
  }

  Future<void> retry() => init();

  /// Phase 3B: opens this app's system Settings page (see
  /// DecksController.openPermissionSettings for why the denied
  /// state needs a second action).
  Future<void> openPermissionSettings() async {
    await media.openAppSettings();
  }

  /// Slider handler: regroup from cached hashes only. No thumbnail
  /// download, no re-scan — only tile thumbnails for members that
  /// newly appear in a group are fetched.
  void setThreshold(int value) {
    final int clamped = value.clamp(sliderMin, sliderMax);
    if (clamped == threshold.value) {
      return;
    }
    threshold.value = clamped;
    _regroup();
  }

  /// Phase 1.1: live slider drag — updates the displayed value only,
  /// never regroups. The view calls this from `onChanged` so the
  /// thumb and label follow the finger; the expensive regroup waits
  /// for [commitThreshold] on release.
  void previewThreshold(int value) {
    threshold.value = value.clamp(sliderMin, sliderMax);
  }

  /// Phase 1.1: slider release — exactly one regroup per release,
  /// and none when the drag ended where it started. The view calls
  /// this from `onChangeEnd`.
  void commitThreshold() {
    if (threshold.value != _groupedThreshold) {
      _regroup();
    }
  }

  /// User picks another keeper in [groupIndex]. Only member ids are
  /// offered by the view, so the keeper always stays in the group.
  void changeKeeper(int groupIndex, String assetId) {
    if (groupIndex < 0 || groupIndex >= groups.length) {
      return;
    }
    final DuplicateGroup group = groups[groupIndex];
    if (!group.assets.any((MediaAsset a) => a.id == assetId)) {
      return;
    }
    groups[groupIndex] = group.copyWithKeeper(assetId);
  }

  /// Writes this group's marks (non-keepers delete, keeper keep) to
  /// the `duplicates` session, then navigates to review with the
  /// non-keeper list. On a session-write failure nothing navigates:
  /// the marks must be durable before review edits them.
  ///
  /// Phase 3A protection: when protection is ON, a favourited
  /// non-keeper is NOT marked delete — it is marked keep instead
  /// (keeper-protected: decided, so it never reappears undecided)
  /// and excluded from the review list, with
  /// [protectedExcludedCount] explaining how many. When every
  /// non-keeper is protected there is nothing to review, so no
  /// navigation happens — the banner is the whole outcome.
  Future<void> markNonKeepers(int groupIndex) async {
    if (groupIndex < 0 || groupIndex >= groups.length) {
      return;
    }
    errorKey.value = '';
    protectedExcludedCount.value = 0;
    final DuplicateGroup group = groups[groupIndex];
    final Result<DeckSession?> loaded = await local.loadSession(sessionKey);
    DeckSession? session;
    final bool loadOk = loaded.fold(
      onSuccess: (DeckSession? value) {
        session = value;
        return true;
      },
      onFailure: (_) => false,
    );
    if (!loadOk) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    final Result<AppSettings> settingsResult = await local.loadSettings();
    final bool protectionOn = settingsResult.fold(
      onSuccess: (AppSettings value) => value.protection,
      onFailure: (_) => false,
    );
    final Set<String> klaraFavourites = await loadAllKlaraFavouriteIds(local);
    klaraFavourites.addAll(session?.favouriteIds ?? <String>{});
    final Map<String, DeckMark> marks = Map<String, DeckMark>.of(
      session?.marks ?? <String, DeckMark>{},
    );
    final List<MediaAsset> toReview = <MediaAsset>[];
    for (final MediaAsset asset in group.nonKeepers) {
      if (protectionOn &&
          isProtected(asset, klaraFavourites: klaraFavourites)) {
        marks[asset.id] = DeckMark.keep;
        protectedExcludedCount.value += 1;
      } else {
        marks[asset.id] = DeckMark.delete;
        toReview.add(asset);
      }
    }
    marks[group.keeperId] = DeckMark.keep;
    final Result<void> saved = await local.saveSession(
      DeckSession(
        filterKey: sessionKey,
        currentIndex: session?.currentIndex ?? 0,
        marks: marks,
        favouriteIds: Set<String>.of(session?.favouriteIds ?? <String>{}),
      ),
    );
    if (saved.isFailure) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    if (toReview.isEmpty) {
      return;
    }
    Get.toNamed<dynamic>(
      AppRoutes.review,
      arguments: toReview,
      parameters: <String, String>{'filterKey': sessionKey},
    );
  }

  void _regroup() {
    _groupedThreshold = threshold.value;
    groups.assignAll(
      groupAssets(
        assets: _assets,
        analyses: _analyses,
        threshold: threshold.value,
      ),
    );
    for (final DuplicateGroup group in groups) {
      for (final MediaAsset asset in group.assets) {
        _loadThumbnail(asset.id);
      }
    }
  }

  Future<void> _loadThumbnail(String id) async {
    if (thumbnails.containsKey(id) || failedThumbnails.contains(id)) {
      return;
    }
    final Result<Uint8List> result = await media.getThumbnail(
      id,
      thumbnailSize,
    );
    result.fold(
      onSuccess: (Uint8List bytes) => thumbnails[id] = bytes,
      onFailure: (_) => failedThumbnails.add(id),
    );
  }
}
