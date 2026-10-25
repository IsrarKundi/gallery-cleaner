import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/document_guard.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';
import '../../../services/trash/trash_service.dart';
import 'review_blur.dart';
import 'review_session.dart';
import 'review_delete.dart';

/// Outcome of [ReviewController.deleteSelected], for the view's
/// post-delete handling and for tests (navigation itself is not
/// asserted — see the navigation contract below).
enum ReviewDeleteOutcome {
  trashed,
  denied,
  failed,
  serviceError,

  /// Phase 4 guard blocked the run: document-like items pend in
  /// [ReviewController.documentGuardPending] for the override.
  documentGuard,
}

/// Review screen state (requirements §4): editable grid of delete-marked photos.
/// Navigation: stack reset with Get.offAllNamed (never Get.back into stale controller).
/// Session: filterKey travels as route param, preserving stored index and favourites.
/// Priority: denied wins over failed; pure trashed goes to Trash; mixed stays with errors.
class ReviewController extends GetxController {
  ReviewController({
    required this.media,
    required this.trash,
    required this.local,
    this.initialAssets,
    this.filterKeyOverride,
    ThumbnailService? thumbnailService,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media);

  final MediaService media;
  final TrashService trash;
  final LocalService local;

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

  /// Phase 3A private blur, extracted to [ReviewBlur] (Phase 4)
  /// to hold this controller's line budget; forwarded so the
  /// view's contract is unchanged.
  final ReviewBlur blur = ReviewBlur();

  RxBool get privateBlur => blur.privateBlur;
  RxSet<String> get revealedIds => blur.revealedIds;

  /// Phase 4 guard: document-like items in the current run
  /// awaiting override or keeping (empty unless the last run
  /// was blocked with [ReviewDeleteOutcome.documentGuard]).
  final RxList<MediaAsset> documentGuardPending = <MediaAsset>[].obs;

  /// Phase 4: items [keepDocumentGuarded] last kept, for the
  /// view's confirmation snackbar.
  final RxInt documentGuardKeptCount = 0.obs;

  /// Phase 3A: favourited items kept out of the last delete run
  /// (they stay in the grid, protected, and are never sent to
  /// trash). The view shows this count as a banner.
  final RxInt protectedExcludedCount = 0.obs;

  /// Phase 3B mixed-outcome counts for the view's dialog/snackbar:
  /// how many of the last run were actually trashed, and how many
  /// failed to resolve at all. Denied count is [deniedIds].length.
  /// A pure run leaves the other count at 0, so the view can tell
  /// a pure outcome from a mixed one without re-deriving it.
  final RxInt lastTrashedCount = 0.obs;
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
    if (fromArgs != null) {
      items.assignAll(fromArgs);
    }
    _filterKey = filterKeyOverride ?? _routeFilterKey();
    if (items.isEmpty) {
      isLoading.value = true;
      _loadFromSession();
    }
    _loadThumbnails();
    _loadBlurSetting();
  }

  Future<void> _loadFromSession() async {
    try {
      final List<MediaAsset> loaded = await loadDeleteMarkedAssets(
        local: local,
        media: media,
        filterKey: _filterKey,
      );
      if (loaded.isNotEmpty && items.isEmpty) {
        items.assignAll(loaded);
        _loadThumbnails();
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Reads the persisted blur setting (defaults OFF).
  Future<void> _loadBlurSetting() => blur.load(local);

  /// Flips private blur and persists it (the same setting the
  /// Settings screen toggles). Toggling clears all reveals, so
  /// turning blur back on never inherits a stale revealed set.
  Future<void> toggleBlur() async {
    errorKey.value = await blur.toggle(local) ?? '';
  }

  /// Reveals one blurred thumbnail until blur is toggled off or
  /// this screen is left (see [ReviewBlur.revealedIds]).
  void reveal(String assetId) => blur.reveal(assetId);

  /// True when [asset]'s tile must render blurred: blur ON and
  /// this item not yet tapped to reveal.
  bool isBlurred(MediaAsset asset) => blur.isBlurred(asset);

  /// Phase 4 guard, the "keep" side: unmarks every pending
  /// document-like item (back to the deck, undecided). Deletes
  /// nothing itself.
  Future<void> keepDocumentGuarded() async {
    if (documentGuardPending.isEmpty) {
      return;
    }
    final List<MediaAsset> guarded = documentGuardPending.toList();
    final bool saved = await updateSessionMarks(
      local: local,
      filterKey: _filterKey,
      updates: <String, DeckMark?>{
        for (final MediaAsset asset in guarded) asset.id: null,
      },
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    final Set<String> ids = guarded.map((MediaAsset a) => a.id).toSet();
    items.removeWhere((MediaAsset item) => ids.contains(item.id));
    documentGuardPending.clear();
    documentGuardKeptCount.value = guarded.length;
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
    } catch (_) {
      // No route in this context; the constructor list (if any) wins.
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
    for (final MediaAsset asset in items) {
      // The service publishes bytes/failures to its shared maps;
      // the loop only paces the loads (sequential here — Phase 3.3
      // adds bounded concurrency).
      await _thumbnails.getThumbnail(asset.id, thumbnailSize);
    }
  }

  /// Unmarks one photo: its delete mark leaves the session (it
  /// returns to the deck as undecided) and it leaves the grid. The
  /// session write happens first — on failure the photo stays put
  /// and the error state shows instead of silently dropping it.
  Future<void> unmark(MediaAsset asset) async {
    errorKey.value = '';
    final bool saved = await updateSessionMarks(
      local: local,
      filterKey: _filterKey,
      updates: <String, DeckMark?>{asset.id: null},
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    items.removeWhere((MediaAsset item) => item.id == asset.id);
  }

  /// Sets every delete mark in the set to keep in the session
  /// (decided, so they do not reappear in the deck) and resets the
  /// stack to the deck.
  Future<void> keepAll() async {
    if (items.isEmpty) {
      return;
    }
    errorKey.value = '';
    final Map<String, DeckMark?> updates = <String, DeckMark?>{
      for (final MediaAsset asset in items) asset.id: DeckMark.keep,
    };
    final bool saved = await updateSessionMarks(
      local: local,
      filterKey: _filterKey,
      updates: updates,
    );
    if (!saved) {
      errorKey.value = AppStrings.errorLocal;
      return;
    }
    items.clear();
    goToDeck();
  }

  /// Moves the review set to Trash through the native confirmation
  /// sheet and returns the outcome for the view to act on (snackbar
  /// + Trash navigation, denied dialog + deck navigation, or the
  /// error state with retry). Returns null when there is nothing to
  /// delete or a delete is already running.
  ///
  /// Phase 3A protection: when ON, favourited items (Klara or
  /// system) are EXCLUDED from the trash run — they stay in the
  /// grid and [protectedExcludedCount] explains how many. When
  /// every item is protected, nothing is sent and null returns
  /// (the banner is the whole outcome; no native sheet appears).
  ///
  /// Phase 4 guard: unless [overrideDocumentGuard] is true, a
  /// run with document-like items stops BEFORE any native sheet
  /// with [ReviewDeleteOutcome.documentGuard] and fills
  /// [documentGuardPending]; the view then asks: delete anyway
  /// (re-call with the override) or keep those items.
  Future<ReviewDeleteOutcome?> deleteSelected({
    bool overrideDocumentGuard = false,
  }) async {
    if (items.isEmpty || isDeleting.value) {
      return null;
    }
    isDeleting.value = true;
    errorKey.value = '';
    deniedIds.clear();
    trashedUntil.value = null;
    lastOutcome.value = null;
    protectedExcludedCount.value = 0;
    lastTrashedCount.value = 0;
    lastFailedCount.value = 0;
    documentGuardKeptCount.value = 0;
    // Phase 3B: protection filtering lives in review_delete.dart
    // (extracted to hold the controller's line budget).
    final ReviewDeletePlan plan = await planReviewDelete(
      items: items.toList(),
      local: local,
      filterKey: _filterKey,
    );
    protectedExcludedCount.value = plan.protectedCount;
    final List<MediaAsset> toDelete = plan.toDelete;
    // Phase 4 guard (requirements §7): warn, never silently
    // delete — no native sheet until the user overrides.
    final List<MediaAsset> guarded = documentLikeItems(toDelete);
    if (guarded.isNotEmpty && !overrideDocumentGuard) {
      documentGuardPending.assignAll(guarded);
      isDeleting.value = false;
      lastOutcome.value = ReviewDeleteOutcome.documentGuard;
      return ReviewDeleteOutcome.documentGuard;
    }
    documentGuardPending.clear();
    if (toDelete.isEmpty) {
      isDeleting.value = false;
      return null;
    }
    final List<String> ids = toDelete.map((MediaAsset a) => a.id).toList();
    final Result<TrashOutcome> result = await trash.trashAssets(ids);
    isDeleting.value = false;
    if (result.isFailure) {
      errorKey.value = (result as Failure<TrashOutcome>).failure.messageKey;
      lastOutcome.value = ReviewDeleteOutcome.serviceError;
      return ReviewDeleteOutcome.serviceError;
    }
    final TrashOutcome outcome = (result as Success<TrashOutcome>).value;
    // Phase 3B: record the split before branching, so the view can
    // explain mixed runs (trashed + denied, trashed + failed) instead
    // of reporting only the winning outcome and hiding the rest.
    lastTrashedCount.value = outcome.trashedIds.length;
    lastFailedCount.value = outcome.failedIds.length;
    if (outcome.trashedIds.isNotEmpty) {
      await _applyTrashed(outcome.trashedIds);
      // Phase 3A haptics (design.md §8): medium click when a
      // delete is confirmed through the native sheet.
      AppHaptics.deleteConfirm();
    }
    if (outcome.deniedIds.isNotEmpty) {
      // Denied marks clear best-effort: even if the write fails, the
      // photos stay delete-marked and reappear in the deck for
      // another review instead of vanishing.
      await updateSessionMarks(
        local: local,
        filterKey: _filterKey,
        updates: <String, DeckMark?>{
          for (final String id in outcome.deniedIds) id: null,
        },
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
    lastOutcome.value = ReviewDeleteOutcome.trashed;
    return ReviewDeleteOutcome.trashed;
  }

  /// Clears trashed ids' delete marks (best-effort: the photos are
  /// already in Trash, so a failed write must not reframe the run
  /// as an error), removes them from the grid, and appends the one
  /// history record for the run (trashed MB, freed 0 — never freed
  /// while the photos sit in Trash).
  Future<void> _applyTrashed(List<String> ids) async {
    await updateSessionMarks(
      local: local,
      filterKey: _filterKey,
      updates: <String, DeckMark?>{for (final String id in ids) id: null},
    );
    final Set<String> trashed = ids.toSet();
    int bytes = 0;
    for (final MediaAsset asset in items) {
      if (trashed.contains(asset.id)) {
        bytes += asset.sizeBytes;
      }
    }
    items.removeWhere((MediaAsset asset) => trashed.contains(asset.id));
    await local.appendHistory(
      HistoryRecord(
        date: DateTime.now(),
        count: ids.length,
        mbTrashed: bytes / 1048576,
        mbFreed: 0,
      ),
    );
    trashedUntil.value = DateTime.now().add(const Duration(days: 30));
  }

  /// Resets the stack to the deck so it reloads fresh from the
  /// session. Never [Get.back] into the stale deck controller.
  void goToDeck() {
    Get.offAllNamed<dynamic>(AppRoutes.deck);
  }
}
