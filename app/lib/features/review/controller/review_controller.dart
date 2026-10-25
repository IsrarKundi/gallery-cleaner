import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/trash/trash_service.dart';

/// Outcome of [ReviewController.deleteSelected], for the view's
/// post-delete handling and for tests (navigation itself is not
/// asserted — see the navigation contract below).
enum ReviewDeleteOutcome { trashed, denied, failed, serviceError }

/// Review screen state (requirements §4): the editable grid of
/// delete-marked photos the deck passed via route arguments.
///
/// Navigation contract: after any action that changes session marks,
/// the view resets the stack with [Get.offAllNamed] to the destination
/// screen, never [Get.back] into the deck's stale controller, whose
/// in-memory marks only reload from the session on creation. The same
/// rule covers [goToDeck] and the view's trash navigation.
///
/// Session contract: the deck passes only the asset list as arguments,
/// so the deck filter key travels as a route parameter (`filterKey` —
/// see [DeckController.goToReview]). It defaults to `all` when absent,
/// which is also the filter the deck reloads under after a stack
/// reset. Session writes load the stored session, apply the mark
/// change, and save it back preserving its index and favourites.
///
/// Outcome priority when the native sheet splits a run: denied wins
/// over failed (the denied dialog returns the user to the deck, and
/// failed ids keep their delete marks so they reappear there for
/// another review). A pure trashed run navigates to Trash; a run with
/// trashed + failed ids stays on screen with the failed items and an
/// error state. Trashed MB is never reported as freed: the history
/// record carries it as trashed with freed 0 (requirements §4).
class ReviewController extends GetxController {
  ReviewController({
    required this.media,
    required this.trash,
    required this.local,
    this.initialAssets,
    this.filterKeyOverride,
  });

  final MediaService media;
  final TrashService trash;
  final LocalService local;

  /// Thumbnail edge in pixels, matching the deck's preload size.
  static const int thumbnailSize = 512;

  final List<MediaAsset>? initialAssets;
  final String? filterKeyOverride;

  /// The review set. Shrinks as items are unmarked or trashed; an
  /// empty set renders the empty state (never a disabled Delete).
  final RxList<MediaAsset> items = <MediaAsset>[].obs;
  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxSet<String> failedThumbnails = <String>{}.obs;
  final RxBool isDeleting = false.obs;
  final RxString errorKey = ''.obs;
  final Rx<ReviewDeleteOutcome?> lastOutcome = Rx<ReviewDeleteOutcome?>(null);

  /// Ids the user denied at the native sheet: marks cleared, the
  /// view shows the denied explanation, then the stack resets.
  final RxList<String> deniedIds = <String>[].obs;

  /// Shared recoverable-until date for a trashed run (trashedAt +
  /// 30 days, from the controller's clock — the service records the
  /// same moment, so this matches except across a midnight edge).
  final Rx<DateTime?> trashedUntil = Rx<DateTime?>(null);

  String _filterKey = 'all';

  /// Total size of the current review set, live as items leave it.
  int get totalBytes {
    return items.fold<int>(0, (int sum, MediaAsset asset) {
      return sum + asset.sizeBytes;
    });
  }

  @override
  void onInit() {
    super.onInit();
    final List<MediaAsset>? fromArgs = initialAssets ?? _routeAssets();
    if (fromArgs != null) {
      items.assignAll(fromArgs);
    }
    _filterKey = filterKeyOverride ?? _routeFilterKey();
    _loadThumbnails();
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
      final Result<Uint8List> result = await media.getThumbnail(
        asset.id,
        thumbnailSize,
      );
      result.fold(
        onSuccess: (Uint8List bytes) => thumbnails[asset.id] = bytes,
        onFailure: (_) => failedThumbnails.add(asset.id),
      );
    }
  }

  /// Unmarks one photo: its delete mark leaves the session (it
  /// returns to the deck as undecided) and it leaves the grid. The
  /// session write happens first — on failure the photo stays put
  /// and the error state shows instead of silently dropping it.
  Future<void> unmark(MediaAsset asset) async {
    errorKey.value = '';
    final bool saved = await _updateSessionMarks(<String, DeckMark?>{
      asset.id: null,
    });
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
    final bool saved = await _updateSessionMarks(updates);
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
  Future<ReviewDeleteOutcome?> deleteSelected() async {
    if (items.isEmpty || isDeleting.value) {
      return null;
    }
    isDeleting.value = true;
    errorKey.value = '';
    deniedIds.clear();
    trashedUntil.value = null;
    lastOutcome.value = null;
    final List<String> ids = items.map((MediaAsset a) => a.id).toList();
    final Result<TrashOutcome> result = await trash.trashAssets(ids);
    isDeleting.value = false;
    if (result.isFailure) {
      errorKey.value = (result as Failure<TrashOutcome>).failure.messageKey;
      lastOutcome.value = ReviewDeleteOutcome.serviceError;
      return ReviewDeleteOutcome.serviceError;
    }
    final TrashOutcome outcome = (result as Success<TrashOutcome>).value;
    if (outcome.trashedIds.isNotEmpty) {
      await _applyTrashed(outcome.trashedIds);
    }
    if (outcome.deniedIds.isNotEmpty) {
      // Denied marks clear best-effort: even if the write fails, the
      // photos stay delete-marked and reappear in the deck for
      // another review instead of vanishing.
      await _updateSessionMarks(<String, DeckMark?>{
        for (final String id in outcome.deniedIds) id: null,
      });
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
    await _updateSessionMarks(<String, DeckMark?>{
      for (final String id in ids) id: null,
    });
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

  /// Loads the deck session for [_filterKey], applies [updates]
  /// (null removes a mark), and saves it back preserving the stored
  /// index and favourites. Returns false when the session could not
  /// be read or written.
  Future<bool> _updateSessionMarks(Map<String, DeckMark?> updates) async {
    final Result<DeckSession?> loaded = await local.loadSession(_filterKey);
    DeckSession? session;
    final bool loadOk = loaded.fold(
      onSuccess: (DeckSession? value) {
        session = value;
        return true;
      },
      onFailure: (_) => false,
    );
    if (!loadOk) {
      return false;
    }
    final Map<String, DeckMark> marks = Map<String, DeckMark>.of(
      session?.marks ?? <String, DeckMark>{},
    );
    for (final MapEntry<String, DeckMark?> entry in updates.entries) {
      final DeckMark? mark = entry.value;
      if (mark == null) {
        marks.remove(entry.key);
      } else {
        marks[entry.key] = mark;
      }
    }
    final Result<void> saved = await local.saveSession(
      DeckSession(
        filterKey: _filterKey,
        currentIndex: session?.currentIndex ?? 0,
        marks: marks,
        favouriteIds: Set<String>.of(session?.favouriteIds ?? <String>{}),
      ),
    );
    return saved.isSuccess;
  }

  /// Resets the stack to the deck so it reloads fresh from the
  /// session. Never [Get.back] into the stale deck controller.
  void goToDeck() {
    Get.offAllNamed<dynamic>(AppRoutes.deck);
  }
}
