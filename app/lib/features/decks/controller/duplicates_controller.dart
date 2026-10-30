// Duplicates screen state (requirements §7, Phase 2).
//
// Shows the EXACT-duplicate groups the library scan computed
// (fix plan Stage 4): grouping now happens inside the scan, and
// this screen reads the groups from the scan's persisted
// memberships — it never groups anything itself. The similarity
// slider that used to regroup live from cached hashes is GONE
// (owner-approved removal, ADR-019): the engine it drove no
// longer exists, and Cleanup's rule is a fixed compare table,
// not a user threshold.
//
// Keeper changes are local until the screen's one mark action
// (fix plan Stage 7): every non-keeper starts SELECTED; tapping
// a photo's round mark spares it. "Mark N duplicates for review"
// writes delete marks for the selected non-keepers across ALL
// groups (and keep marks for the keeper of each group that
// contributes, so it never reappears undecided) into the
// `duplicates` session and navigates to /review with the marked
// list — the same arguments + filterKey contract the deck uses.
// Nothing is deleted here; review + native confirmation still
// own removal (requirements §4). Spared non-keepers get no mark
// at all: they stay undecided for a later run.

import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/lifecycle/app_lifecycle.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/scan_memberships.dart';
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
    this.lifecycle,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media),
       _scans =
           scanRepository ?? ScanRepositoryImpl(media: media, local: local);

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

  /// Session key for marks written by the mark action.
  static const String sessionKey = 'duplicates';

  /// Grid tile thumbnail edge in pixels.
  static const int thumbnailSize = 256;

  final Rx<DecksStatus> status = DecksStatus.loading.obs;
  final RxString errorKey = ''.obs;
  final RxList<DuplicateGroup> groups = <DuplicateGroup>[].obs;

  /// Stage 7: the selection the mark action will write — the ids
  /// of the non-keepers currently selected for marking. Every
  /// non-keeper starts selected (Cleanup's pre-selected list);
  /// sparing removes an id here, it never touches the groups.
  /// Screen state only: nothing persists until the mark action
  /// writes the session.
  final RxSet<String> selectedIds = <String>{}.obs;

  /// Total duplicate photos: the non-keepers across all groups.
  int get duplicateCount => groups.fold<int>(
    0,
    (int sum, DuplicateGroup g) => sum + g.nonKeepers.length,
  );

  /// Total size of those non-keepers.
  int get duplicateBytes => groups.fold<int>(
    0,
    (int sum, DuplicateGroup g) =>
        sum +
        g.nonKeepers.fold<int>(0, (int s, MediaAsset a) => s + a.sizeBytes),
  );

  /// The selected non-keepers, in group order.
  List<MediaAsset> get selectedNonKeepers => <MediaAsset>[
    for (final DuplicateGroup group in groups)
      for (final MediaAsset asset in group.nonKeepers)
        if (selectedIds.contains(asset.id)) asset,
  ];

  int get selectedCount => selectedNonKeepers.length;

  int get selectedBytes => selectedNonKeepers.fold<int>(
    0,
    (int sum, MediaAsset a) => sum + a.sizeBytes,
  );

  bool isSelected(String assetId) => selectedIds.contains(assetId);

  bool get allSelected => duplicateCount > 0 && selectedCount == duplicateCount;

  bool get anySelected => selectedCount > 0;

  /// Phase 2.3: service-owned bytes / failures for the grid size.
  /// Views read through these getters unchanged.
  RxMap<String, Uint8List> get thumbnails =>
      _thumbnails.thumbnailsFor(thumbnailSize);
  RxSet<String> get failedThumbnails => _thumbnails.failedFor(thumbnailSize);

  /// Phase 3A: favourited non-keepers kept out of a delete-marking
  /// run (count shown as a banner in the view, never silent).
  final RxInt protectedExcludedCount = 0.obs;

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
    // Stage 4: the groups are the scan's exact-duplicate
    // memberships, resolved against this scan's assets. The
    // keeper each group shows is the duplicate reference's main
    // (the scan's suggested keeper) until the user changes it.
    final Map<String, MediaAsset> byId = <String, MediaAsset>{
      for (final MediaAsset asset in scan.assets) asset.id: asset,
    };
    groups.assignAll(
      groupsFromMemberships(byId, scan.memberships, ScanGroupKind.duplicate),
    );
    _resetSelection();
    // One prefetch for all member tiles (deduped by the service).
    _thumbnails.prefetch(<String>[
      for (final DuplicateGroup group in groups)
        for (final MediaAsset asset in group.assets) asset.id,
    ], thumbnailSize);
    status.value = DecksStatus.ready;
  }

  Future<void> retry() => init();

  /// Phase 3B: opens this app's system Settings page (see
  /// DecksController.openPermissionSettings for why the denied
  /// state needs a second action).
  Future<void> openPermissionSettings() async {
    await media.openAppSettings();
  }

  /// Every non-keeper selected: the state each fresh group list
  /// starts in (Stage 7).
  void _resetSelection() {
    selectedIds
      ..clear()
      ..addAll(<String>[
        for (final DuplicateGroup group in groups)
          for (final MediaAsset asset in group.nonKeepers) asset.id,
      ]);
  }

  /// User picks another keeper in [groupIndex]. Only member ids are
  /// offered by the view, so the keeper always stays in the group.
  ///
  /// Selection follows the keeper (Stage 7): the new keeper leaves
  /// the selection (a keeper is never marked), and the previous
  /// keeper — now an ordinary non-keeper — joins it, selected like
  /// every non-keeper. A spare the user set on it earlier is
  /// superseded by the keeper change itself.
  void changeKeeper(int groupIndex, String assetId) {
    if (groupIndex < 0 || groupIndex >= groups.length) {
      return;
    }
    final DuplicateGroup group = groups[groupIndex];
    if (!group.assets.any((MediaAsset a) => a.id == assetId)) {
      return;
    }
    final String previousKeeper = group.keeperId;
    groups[groupIndex] = group.copyWithKeeper(assetId);
    selectedIds.remove(assetId);
    if (previousKeeper != assetId) {
      selectedIds.add(previousKeeper);
    }
  }

  /// Spares a selected non-keeper, or re-selects a spared one.
  /// Keepers and unknown ids are not selectable: no-op.
  void toggleSelection(String assetId) {
    final bool isNonKeeper = groups.any(
      (DuplicateGroup g) =>
          g.keeperId != assetId &&
          g.assets.any((MediaAsset a) => a.id == assetId),
    );
    if (!isNonKeeper) {
      return;
    }
    if (selectedIds.contains(assetId)) {
      selectedIds.remove(assetId);
    } else {
      selectedIds.add(assetId);
    }
  }

  /// Selects every non-keeper in every group.
  void selectAll() => _resetSelection();

  /// Spares everything: the mark action has nothing to write.
  void deselectAll() => selectedIds.clear();

  /// The screen's one mark action (Stage 7): writes the SELECTED
  /// non-keepers' marks (delete; keeper keep for each group that
  /// contributes at least one) to the `duplicates` session, then
  /// navigates to review with the marked list. On a session-write
  /// failure nothing navigates: the marks must be durable before
  /// review edits them. Spared non-keepers and groups contributing
  /// nothing are left completely untouched.
  ///
  /// Phase 3A protection: when protection is ON, a favourited
  /// selected non-keeper is NOT marked delete — it is marked keep
  /// instead (keeper-protected: decided, so it never reappears
  /// undecided) and excluded from the review list, with
  /// [protectedExcludedCount] explaining how many. When every
  /// selected non-keeper is protected there is nothing to review,
  /// so no navigation happens — the banner is the whole outcome.
  Future<void> markSelected() async {
    if (selectedCount == 0) {
      return;
    }
    errorKey.value = '';
    protectedExcludedCount.value = 0;
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
    for (final DuplicateGroup group in groups) {
      final List<MediaAsset> chosen = group.nonKeepers
          .where((MediaAsset a) => selectedIds.contains(a.id))
          .toList();
      if (chosen.isEmpty) {
        continue;
      }
      for (final MediaAsset asset in chosen) {
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
    }
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
}
