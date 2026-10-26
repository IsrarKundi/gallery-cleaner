import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../shell/controller/shell_controller.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';
import '../../../services/trash/trash_service.dart';
import 'review_selection.dart';
import 'review_session.dart';
import 'review_delete.dart';
import 'review_union.dart';

/// Outcome of [ReviewController.deleteSelected], for the view's
/// post-delete handling and for tests (navigation itself is not
/// asserted — see the navigation contract below).
enum ReviewDeleteOutcome { deleted, denied, failed, serviceError }

/// Review screen state (requirements §4): editable grid of delete-marked photos.
/// Navigation: exits return to the retained shell when one is alive
/// (pop, never rebuild); standalone Review falls back to a stack
/// reset. The post-delete path to Trash still resets, so state
/// after a delete loads fresh. See ADR-009.
/// Session: filterKey travels as route param, preserving stored index and favourites.
/// Priority: denied wins over failed; pure trashed goes to Trash; mixed stays with errors.
class ReviewController extends GetxController {
  ReviewController({
    required this.media,
    required this.trash,
    required this.local,
    this.initialAssets,
    Map<String, String>? initialOriginSessionKeys,
    this.filterKeyOverride,
    ThumbnailService? thumbnailService,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media),
       originSessionKeys = initialOriginSessionKeys != null
           ? Map<String, String>.of(initialOriginSessionKeys)
           : <String, String>{} {
    if (initialAssets != null) {
      items.assignAll(initialAssets!);
    }
    if (filterKeyOverride != null) {
      _filterKey = filterKeyOverride!;
    }
  }

  final MediaService media;
  final TrashService trash;
  final LocalService local;

  /// Mapping of asset id -> origin deck session key, preserving
  /// independent sessions across the union set (requirements §4).
  final Map<String, String> originSessionKeys;

  /// Thumbnail edge in pixels for grid tiles (solutions 3.1: grid
  /// standard 256–320 px, top of the range so 3×-DPR tiles stay
  /// sharp). Deliberately NOT the deck's 1080: one size per display
  /// surface, so review tiles stop fetching deck-sized bytes.
  static const int thumbnailSize = 320;

  /// Phase 2.3: bytes live in the shared thumbnail service; the
  /// view observes these same reactive objects through the getters.
  final ThumbnailService _thumbnails;

  final List<MediaAsset>? initialAssets;
  final String? filterKeyOverride;

  /// The review set. Shrinks as items are unmarked or trashed.
  final RxList<MediaAsset> items = <MediaAsset>[].obs;

  /// Service-owned bytes / failures for the review size.
  RxMap<String, Uint8List> get thumbnails =>
      _thumbnails.thumbnailsFor(thumbnailSize);
  RxSet<String> get failedThumbnails => _thumbnails.failedFor(thumbnailSize);
  final RxBool isLoading = false.obs;
  final RxBool isDeleting = false.obs;
  final RxString errorKey = ''.obs;
  final Rx<ReviewDeleteOutcome?> lastOutcome = Rx<ReviewDeleteOutcome?>(null);

  /// Ids the user denied at the native sheet: marks cleared, the
  /// view shows the denied explanation, then the stack resets.
  final RxList<String> deniedIds = <String>[].obs;

  /// Selection state for the grid (owner decision 26 Oct 2026):
  /// photos are always shown revealed, and the user selects the
  /// ones to keep or delete instead of acting on the whole set.
  /// See [ReviewSelection] for the mode rules.
  final ReviewSelection selection = ReviewSelection();

  /// True while the grid is in selection mode.
  bool get selectionMode => selection.mode.value;

  /// True when at least one photo is selected.
  bool get hasSelection => selection.hasSelection;

  /// Photos currently selected (empty outside selection mode).
  List<MediaAsset> get selectedItems =>
      items.where((MediaAsset a) => selection.isSelected(a.id)).toList();

  /// Phase 3A: favourited items kept out of the last delete run
  /// (they stay in the grid, protected, and are never sent to
  /// trash). The view shows this count as a banner.
  final RxInt protectedExcludedCount = 0.obs;

  /// Phase 3B mixed-outcome counts for the view's dialog/snackbar:
  /// how many of the last run were permanently deleted, and how many
  /// failed to resolve at all. Denied count is [deniedIds].length.
  /// A pure run leaves the other count at 0, so the view can tell
  /// a pure outcome from a mixed one without re-deriving it.
  final RxInt lastDeletedCount = 0.obs;
  RxInt get lastTrashedCount => lastDeletedCount;
  final RxInt lastFailedCount = 0.obs;

  /// Shared recoverable-until date for a trashed run (trashedAt +
  /// 30 days, from the controller's clock — the service records the
  /// same moment, so this matches except across a midnight edge).
  final Rx<DateTime?> trashedUntil = Rx<DateTime?>(null);

  String _filterKey = 'all';

  /// Total size of the current review set, live as items leave it.
  int get totalBytes =>
      items.fold<int>(0, (int sum, MediaAsset a) => sum + a.sizeBytes);

  @override
  void onInit() {
    super.onInit();
    final List<MediaAsset>? fromArgs = initialAssets ?? _routeAssets();
    if (fromArgs != null && items.isEmpty) {
      items.assignAll(fromArgs);
    }
    final Map<String, String>? fromLaunch = _routeOriginSessions();
    if (fromLaunch != null && originSessionKeys.isEmpty) {
      originSessionKeys.addAll(fromLaunch);
    }
    if (filterKeyOverride == null) {
      _filterKey = _routeFilterKey();
    }
    if (items.isEmpty) {
      isLoading.value = true;
      _loadFromSession();
    }
    _loadThumbnails();
  }

  Future<void> _loadFromSession() async {
    try {
      if (_filterKey == 'union') {
        final ReviewLaunch launch = await buildReviewUnion(
          local: local,
          media: media,
        );
        if (launch.assets.isNotEmpty && items.isEmpty) {
          items.assignAll(launch.assets);
          originSessionKeys.addAll(launch.originSessionKeys);
          _loadThumbnails();
        }
      } else {
        final List<MediaAsset> loaded = await loadDeleteMarkedAssets(
          local: local,
          media: media,
          filterKey: _filterKey,
        );
        if (loaded.isNotEmpty && items.isEmpty) {
          items.assignAll(loaded);
          _loadThumbnails();
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Reads the asset list the deck passed as route arguments.
  /// Guarded: unit tests construct the controller directly and never
  /// touch Get's routing.
  List<MediaAsset>? _routeAssets() {
    try {
      final dynamic args = Get.arguments;
      if (args is List<MediaAsset>) {
        return args;
      }
      if (args is ReviewLaunch) {
        return args.assets;
      }
    } catch (_) {
      // No route in this context; the constructor list (if any) wins.
    }
    return null;
  }

  Map<String, String>? _routeOriginSessions() {
    try {
      final dynamic args = Get.arguments;
      if (args is ReviewLaunch) {
        return args.originSessionKeys;
      }
    } catch (_) {
      // No route in this context; constructor map (if any) wins.
    }
    return null;
  }

  /// Reads the deck filter key from the route parameters.
  String _routeFilterKey() {
    try {
      return Get.parameters['filterKey'] ?? 'all';
    } catch (_) {
      return 'all';
    }
  }

  Future<void> _loadThumbnails() async {
    // Phase 3.3: bounded concurrency (F-18). Tiles arrive in
    // batches of 8 — one batch in flight at a time — instead of
    // the old strictly-sequential loop or an unbounded prefetch
    // of the whole set. Items are snapshotted so an unmark
    // mid-load cannot shift the batch. The service publishes
    // bytes/failures to its shared maps; the loop only paces
    // the loads.
    const int batchSize = 8;
    final List<MediaAsset> assets = items.toList();
    for (int start = 0; start < assets.length; start += batchSize) {
      final int end = (start + batchSize) > assets.length
          ? assets.length
          : start + batchSize;
      await Future.wait(<Future<void>>[
        for (int i = start; i < end; i++)
          _thumbnails.getThumbnail(assets[i].id, thumbnailSize),
      ]);
    }
  }

  /// Retry a failed tile (Phase 3.3, brief 3.6): clears the failed
  /// mark via the shared service and re-fetches, mirroring the
  /// deck's retry. Tapping the tile itself still unmarks.
  Future<void> retryThumbnail(String assetId) async {
    _thumbnails.retry(assetId, thumbnailSize);
    await _thumbnails.getThumbnail(assetId, thumbnailSize);
  }

  /// Unmarks one photo: its delete mark leaves the session (it
  /// returns to the deck as undecided) and it leaves the grid. The
  /// session write happens first — on failure the photo stays put
  /// and the error state shows instead of silently dropping it.
  Future<void> unmark(MediaAsset asset) async {
    errorKey.value = '';
    final String sessionKey = originSessionKeys[asset.id] ?? _filterKey;
    final bool saved = await syncReviewUnmark(
      local: local,
      asset: asset,
      sessionKey: sessionKey,
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    items.removeWhere((MediaAsset item) => item.id == asset.id);
    _syncSelection();
  }

  /// Sets every delete mark in the set to keep in the session
  /// (decided, so they do not reappear in the deck) and resets the
  /// stack to the deck.
  Future<void> keepAll() async {
    if (items.isEmpty) {
      return;
    }
    errorKey.value = '';
    final bool saved = await syncReviewKept(
      local: local,
      assets: items.toList(),
      originSessionKeys: originSessionKeys,
      defaultFilterKey: _filterKey,
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    items.clear();
    selection.clear();
    goToDeck();
  }

  /// Keeps only the selected photos: their marks become keep in
  /// the session (decided, so they do not reappear in the deck)
  /// and they leave the grid. The rest stay marked. When the
  /// selection covered the whole set the grid is empty, so this
  /// lands on the deck like [keepAll]. Never called with an empty
  /// selection (the Keep button falls back to [keepAll] then).
  Future<void> keepSelected() async {
    if (selectedItems.isEmpty) {
      return;
    }
    errorKey.value = '';
    final List<MediaAsset> toKeep = selectedItems.toList();
    final bool saved = await syncReviewKept(
      local: local,
      assets: toKeep,
      originSessionKeys: originSessionKeys,
      defaultFilterKey: _filterKey,
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    final Set<String> kept = toKeep.map((MediaAsset a) => a.id).toSet();
    items.removeWhere((MediaAsset item) => kept.contains(item.id));
    _syncSelection();
    if (items.isEmpty) {
      goToDeck();
    }
  }

  /// Drops selection ids that left the grid (unmarked, kept,
  /// trashed) and ends selection mode when nothing remains.
  void _syncSelection() {
    selection.sync(items.map((MediaAsset a) => a.id));
  }

  /// Permanently deletes photos through the native confirmation sheet
  /// (MediaStore.createDeleteRequest on API 30+) and returns the outcome
  /// for the view to act on (return to deck, denied dialog + deck
  /// navigation, or the error state with retry). Returns null when
  /// there is nothing to delete or a delete is already running.
  ///
  /// [onlyIds] scopes the run to the selection: only those photos
  /// are deleted and the rest stay in the grid (the view shows a
  /// snackbar and stays for a partial deleted run). Without it the
  /// whole set is deleted, returning to the deck.
  ///
  /// Phase 3A protection: when ON, favourited items (Klara or
  /// system) are EXCLUDED from the delete run — they stay in the
  /// grid and [protectedExcludedCount] explains how many. When
  /// every item is protected, nothing is sent and null returns
  /// (the banner is the whole outcome; no native sheet appears).
  Future<ReviewDeleteOutcome?> deleteSelected({List<String>? onlyIds}) async {
    final List<MediaAsset> scope = onlyIds == null
        ? items.toList()
        : items.where((MediaAsset a) => onlyIds.contains(a.id)).toList();
    if (scope.isEmpty || isDeleting.value) {
      return null;
    }
    isDeleting.value = true;
    errorKey.value = '';
    deniedIds.clear();
    trashedUntil.value = null;
    lastOutcome.value = null;
    protectedExcludedCount.value = 0;
    lastDeletedCount.value = 0;
    lastFailedCount.value = 0;
    // Phase 3B: protection filtering lives in review_delete.dart
    // (extracted to hold the controller's line budget).
    final ReviewDeletePlan plan = await planReviewDelete(
      items: scope,
      local: local,
      filterKey: _filterKey,
    );
    protectedExcludedCount.value = plan.protectedCount;
    final List<MediaAsset> toDelete = plan.toDelete;
    if (toDelete.isEmpty) {
      isDeleting.value = false;
      return null;
    }
    final List<String> ids = toDelete.map((MediaAsset a) => a.id).toList();
    final Result<DeleteOutcome> result = await trash.deletePermanently(ids);
    isDeleting.value = false;
    if (result.isFailure) {
      errorKey.value = (result as Failure<DeleteOutcome>).failure.messageKey;
      lastOutcome.value = ReviewDeleteOutcome.serviceError;
      return ReviewDeleteOutcome.serviceError;
    }
    final DeleteOutcome outcome = (result as Success<DeleteOutcome>).value;
    // Phase 3B: record the split before branching, so the view can
    // explain mixed runs (deleted + denied, deleted + failed) instead
    // of reporting only the winning outcome and hiding the rest.
    lastDeletedCount.value = outcome.deletedIds.length;
    lastFailedCount.value = outcome.failedIds.length;
    if (outcome.deletedIds.isNotEmpty) {
      await _applyDeleted(outcome.deletedIds);
      // Phase 3A haptics (design.md §8): medium click when a
      // delete is confirmed through the native sheet.
      AppHaptics.deleteConfirm();
    }
    if (outcome.deniedIds.isNotEmpty) {
      await syncReviewDenied(
        local: local,
        deniedIds: outcome.deniedIds,
        originSessionKeys: originSessionKeys,
        defaultFilterKey: _filterKey,
      );
      deniedIds.assignAll(outcome.deniedIds);
      lastOutcome.value = ReviewDeleteOutcome.denied;
      return ReviewDeleteOutcome.denied;
    }
    if (outcome.failedIds.isNotEmpty) {
      errorKey.value = AppStrings.errorTrash;
      lastOutcome.value = ReviewDeleteOutcome.failed;
      return ReviewDeleteOutcome.failed;
    }
    lastOutcome.value = ReviewDeleteOutcome.deleted;
    return ReviewDeleteOutcome.deleted;
  }

  /// Clears deleted ids' delete marks (best-effort), removes them
  /// from the grid, and appends the one history record for the run
  /// (mbFreed = bytes / 1048576, mbTrashed = 0 — permanently freed).
  Future<void> _applyDeleted(List<String> ids) async {
    await syncReviewDeleted(
      local: local,
      deletedIds: ids,
      originSessionKeys: originSessionKeys,
      defaultFilterKey: _filterKey,
    );
    final Set<String> deleted = ids.toSet();
    int bytes = 0;
    for (final MediaAsset asset in items) {
      if (deleted.contains(asset.id)) {
        bytes += asset.sizeBytes;
      }
    }
    items.removeWhere((MediaAsset asset) => deleted.contains(asset.id));
    _syncSelection();
    await local.appendHistory(
      HistoryRecord(
        date: DateTime.now(),
        count: ids.length,
        mbTrashed: 0,
        mbFreed: bytes / 1048576,
      ),
    );
  }

  /// Returns to the deck tab. When Review sits on top of the
  /// retained shell (the normal bottom-nav path), the shell is
  /// still alive underneath, so select the deck tab and pop back
  /// to it instead of destroying and rebuilding every tab — the
  /// destination matches the old stack reset exactly, only the
  /// rebuild goes away. Standalone Review (no shell underneath)
  /// keeps the old reset. Never [Get.back] into a stale deck
  /// controller: the shell's deck controller is retained, not
  /// stale, so popping to it is safe.
  void goToDeck() => _popToShellTab(0);

  /// Bottom-nav return from Review to a shell tab. Same
  /// pop-to-retained-shell rule as [goToDeck]; standalone Review
  /// keeps the old reset with the tapped tab as the shell's
  /// initial tab.
  void goToShellTab(int nav) => _popToShellTab(nav);

  void _popToShellTab(int nav) {
    if (Get.isRegistered<ShellController>()) {
      Get.find<ShellController>().selectTab(nav);
      Get.back<dynamic>();
      return;
    }
    Get.offAllNamed<dynamic>(AppRoutes.deck, arguments: nav);
  }
}
