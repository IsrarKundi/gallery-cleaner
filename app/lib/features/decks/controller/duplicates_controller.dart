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

import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/async_guard.dart';
import '../../../core/utils/result.dart';
import '../../../services/lifecycle/app_lifecycle.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/photo_analysis.dart';
import '../../../services/detection/scan_repository.dart';
import '../../../services/detection/scan_repository_impl.dart';
import '../../../services/local/local_service.dart';
import '../../../services/local/protection.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/decks_status.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';

class DuplicatesController extends GetxController {
  DuplicatesController({
    required this.media,
    required this.local,
    ThumbnailService? thumbnailService,
    ScanRepository? scanRepository,
    GroupingRunner? groupingRunner,
    this.lifecycle,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media),
       _scans =
           scanRepository ?? ScanRepositoryImpl(media: media, local: local),
       _groupingRunner = groupingRunner ?? groupAssetsOnIsolate;

  final MediaService media;
  final LocalService local;

  /// Phase 4.4 lifecycle delivery (null in tests and on entry
  /// paths without the initial binding: Duplicates then behaves
  /// exactly as before, with no resume handling).
  final AppLifecycle? lifecycle;

  /// Phase 4.2: the shared scan (see scan_repository.dart). The
  /// binding supplies the app-wide instance, so hub → Duplicates
  /// in one session pays exactly one scan; tests that construct
  /// the controller directly get a private one.
  final ScanRepository _scans;

  /// Phase 2.3: bytes live in the shared thumbnail service.
  final ThumbnailService _thumbnails;

  /// Phase 5.2: grouping runs off the UI isolate; injectable so
  /// tests can gate the runner and prove stale-result drops.
  final GroupingRunner _groupingRunner;

  /// Guards regroup results: only the latest request lands.
  final AsyncGuard _regroupGuard = AsyncGuard();

  /// Threshold of the regroup currently in flight, if any. Needed
  /// for the return-to-applied-value case: dragging back to the
  /// already-applied threshold and releasing must supersede a
  /// still-running regroup for another value, not let it land
  /// under the wrong slider position.
  int? _pendingThreshold;

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

  /// Phase 2.3: service-owned bytes / failures for the grid size.
  /// Views read through these getters unchanged.
  RxMap<String, Uint8List> get thumbnails =>
      _thumbnails.thumbnailsFor(thumbnailSize);
  RxSet<String> get failedThumbnails => _thumbnails.failedFor(thumbnailSize);

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
    // Phase 4.4: same shape as the hub (background pauses the
    // shared scan; resume re-checks permission and reconciles
    // a dirty library with a fresh scan).
    if (lifecycle != null) {
      lifecycle!.addPauseListener(_handlePause);
      lifecycle!.addResumeListener(_handleResume);
      _librarySubscription = lifecycle!.libraryChanged.listen(
        (_) => _libraryDirty = true,
      );
    }
    init();
  }

  @override
  void onClose() {
    if (lifecycle != null) {
      lifecycle!.removePauseListener(_handlePause);
      lifecycle!.removeResumeListener(_handleResume);
    }
    unawaited(_librarySubscription?.cancel());
    _librarySubscription = null;
    // See DecksController.onClose: never leave the shared scan
    // paused after disposal.
    _scans.resume();
    // Drop any regroup still in flight: its groups must not land
    // on a disposed controller.
    _regroupGuard.invalidate();
    _pendingThreshold = null;
    super.onClose();
  }

  /// Phase 4.4: library change since the last reconciliation.
  bool _libraryDirty = false;

  /// Phase 4.4: resume handling in flight (single-flight guard).
  Future<void>? _resumeFuture;

  StreamSubscription<void>? _librarySubscription;

  void _handlePause() {
    _scans.pause();
  }

  void _handleResume() {
    if (_resumeFuture != null) {
      return;
    }
    _resumeFuture = _doDuplicatesResume();
    _resumeFuture!.whenComplete(() {
      _resumeFuture = null;
    });
  }

  /// Phase 4.4 Duplicates resume: permission re-check first.
  /// Denied → denied state + explanation. Granted → clear any
  /// background pause first (restart does not clear a paused
  /// flag), then: denied/error → reload from scratch; dirty
  /// library → fresh scan; otherwise the scan simply continues.
  /// Never throws.
  Future<void> _doDuplicatesResume() async {
    try {
      final Result<MediaPermission> perm = await media.requestPermission();
      final bool granted = perm.fold(
        onSuccess: (MediaPermission value) => value != MediaPermission.denied,
        onFailure: (_) => false,
      );
      if (!granted) {
        status.value = DecksStatus.denied;
        if (errorKey.value.isEmpty) {
          errorKey.value = AppStrings.errorMediaPermission;
        }
        return;
      }
      // Clear any background pause BEFORE any reload path (see
      // DecksController._doHubResume for why).
      _scans.resume();
      if (status.value == DecksStatus.denied ||
          status.value == DecksStatus.error) {
        await init();
        return;
      }
      if (_libraryDirty) {
        _libraryDirty = false;
        _scans.restart();
        await init();
        return;
      }
    } catch (_) {
      // Resume handling must never crash the screen.
    }
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
    // Phase 4.2: join the shared scan (hub → Duplicates pays one
    // scan). No page subscription: Duplicates only needs the
    // final result, and the run belongs to the repository, so
    // leaving this screen mid-scan neither cancels nor loses it.
    LibraryScan scan = await _scans.start();
    if (scan.cancelled) {
      // Restarted externally while awaiting: join the fresh run
      // once. A second cancellation means the scan is being
      // actively restarted; fall through with whatever arrived.
      scan = await _scans.start();
    }
    if ((scan.pageFailed || scan.cancelled) && scan.assets.isEmpty) {
      status.value = DecksStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    _assets = scan.assets;
    _analyses = scan.analyses;
    await _regroupAsync();
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
    unawaited(_regroupAsync());
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
    if (threshold.value != _groupedThreshold ||
        (_pendingThreshold != null && _pendingThreshold != threshold.value)) {
      unawaited(_regroupAsync());
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

  /// Regroups off the UI isolate (solutions 5.2). The request's
  /// threshold is captured at call time and recorded as
  /// [_groupedThreshold] only when its result actually lands, so
  /// a slow earlier regroup can never overwrite a newer one, and
  /// old groups stay visible until the new ones arrive (no
  /// flicker to an empty list mid-drag).
  Future<void> _regroupAsync() async {
    final int generation = _regroupGuard.next();
    final int requested = threshold.value;
    _pendingThreshold = requested;
    final List<DuplicateGroup> grouped = await _groupingRunner(
      List<MediaAsset>.of(_assets),
      Map<String, PhotoAnalysis>.of(_analyses),
      requested,
    );
    if (!_regroupGuard.isCurrent(generation) || isClosed) {
      return;
    }
    _pendingThreshold = null;
    _groupedThreshold = requested;
    groups.assignAll(grouped);
    // One prefetch for all member tiles: deduped, and failed tiles
    // retry only when the member list changes (slider regroup).
    final List<String> ids = <String>[
      for (final DuplicateGroup group in groups)
        for (final MediaAsset asset in group.assets) asset.id,
    ];
    _thumbnails.prefetch(ids, thumbnailSize);
  }
}
