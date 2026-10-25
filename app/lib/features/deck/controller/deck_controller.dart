import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/trash/trash_entry.dart';
import '../../../services/trash/trash_service.dart';
import '../../../services/warmup/deck_warm_up.dart';
import '../model/deck_filter.dart';
import '../model/deck_queue.dart';
import '../model/deck_status.dart';
import '../model/retention.dart';
import '../model/space_meter.dart';
import '../model/thumbnail_preloader.dart';
import 'deck_access.dart';
import 'deck_protection.dart';
import 'deck_retention.dart';

/// The deck: permission, paged queue, marks, undo, filters, session
/// resume, thumbnail preloading and the three-state space meter
/// (requirements §3, §4, §5, §7 / design.md §7).
///
/// Queue: one ordered list per filter, newest first. [currentIndex]
/// points at the current card; "next undecided" is the first queue
/// index with no mark. A swipe or button records the mark and
/// advances; undo pops the last decision and returns to that card.
///
/// Cross-feature contract for review (no review code here): deck ->
/// review passes the delete-marked list via route arguments (see
/// [goToReview]); the LocalService session stays the source of truth
/// for resume, and review edits write marks back to it.
/// Denied-confirmation contract (requirements §5): if the user denies
/// the native confirmation, review clears those delete marks in the
/// session and resume re-shows them (first undecided asset);
/// [clearDeleteMarks] does the same rewind live, in-session.
class DeckController extends GetxController {
  DeckController({
    required this.media,
    required this.trash,
    required this.local,
    ShareService? share,
    this.warmUp,
  }) : _preloader = ThumbnailPreloader(media: media),
       retention = DeckRetention(local: local, share: share),
       access = DeckAccess(media: media),
       meterState = DeckMeter(trash: trash, local: local);

  final MediaService media;
  final TrashService trash;
  final LocalService local;

  /// Phase 2.2 warm-up, started by the splash binding. Null in tests
  /// and on any entry path that skips the splash: the deck then runs
  /// its normal path (fresh permission + fresh page 0).
  final DeckWarmUp? warmUp;

  /// Phase 2B retention glue (summary, share, snooze expiry,
  /// completion days). No share backend = no share button.
  final DeckRetention retention;

  /// Three-state meter state.
  final DeckMeter meterState;

  /// Thumbnail preloading + bounded cache (see thumbnail_preloader.dart).
  final ThumbnailPreloader _preloader;

  static const int pageSize = 50;

  /// When this many cards remain, the next page loads in background.
  static const int paginationTrigger = 10;

  final Rx<DeckStatus> status = DeckStatus.loading.obs;
  final Rx<MediaPermission?> permission = Rx<MediaPermission?>(null);
  final RxString errorKey = ''.obs;
  final Rx<DeckFilter> filter = const DeckFilter.all().obs;
  final RxList<MediaAsset> queue = <MediaAsset>[].obs;
  final RxMap<String, DeckMark> marks = <String, DeckMark>{}.obs;
  final RxSet<String> favouriteIds = <String>{}.obs;
  final RxInt currentIndex = 0.obs;
  final RxList<String> undoStack = <String>[].obs;
  final RxList<MediaAlbum> albums = <MediaAlbum>[].obs;
  final RxList<String> months = <String>[].obs;
  final RxList<TrashEntry> trashEntries = <TrashEntry>[].obs;
  final RxList<HistoryRecord> history = <HistoryRecord>[].obs;

  /// Owned by the thumbnail preloader; the view observes these
  /// same reactive objects, so preloading behaviour is unchanged.
  RxMap<String, Uint8List> get thumbnails => _preloader.thumbnails;
  RxSet<String> get failedThumbnails => _preloader.failedThumbnails;
  final RxBool showTutorial = false.obs;
  final RxBool loadingMore = false.obs;

  /// Phase 3A favourites protection (see DeckProtection).
  final DeckProtection protection = DeckProtection();

  /// Phase 3B partial-access + denied-mark helper (see DeckAccess).
  final DeckAccess access;

  Future<void>? _initFuture;
  bool _hasMore = true;
  int _nextPage = 0;
  bool _loadingPage = false;

  /// Phase 2.2: warmed work is consumed on the first init only; a
  /// retry always re-requests permission and re-fetches page 0.
  bool _warmUpUsed = false;

  /// Phase 2.2: parallel, non-gating work. Tutorial and protection
  /// land when they land (the meter refreshes after ready — see
  /// _loadFilterData); they are fire-and-forget by design, marked
  /// with unawaited so the intent is explicit. Protection is the
  /// exception: its future is held so a delete mark can await it.
  Future<void>? _protectionFuture;

  /// Phase 2.2: albums load lazily via [ensureAlbums], not at init.
  bool _albumsLoaded = false;

  /// Current card, or null when the queue is empty or finished.
  MediaAsset? get currentAsset {
    final int index = currentIndex.value;
    if (index < 0 || index >= queue.length) {
      return null;
    }
    return queue[index];
  }

  /// True once every loaded card has a mark (and at least one exists).
  bool get isFinished {
    return status.value == DeckStatus.ready &&
        queue.isNotEmpty &&
        currentIndex.value >= queue.length;
  }

  bool get canUndo => undoStack.isNotEmpty;

  /// True only for the honest Android 14 partial-access state.
  bool get isPartialAccess =>
      permission.value == MediaPermission.grantedLimited;

  /// Assets marked delete: the review set (see class doc).
  List<MediaAsset> get deleteMarkedAssets {
    return queue
        .where((MediaAsset asset) => marks[asset.id] == DeckMark.delete)
        .toList();
  }

  /// Finished-session summary (Phase 2B; delete MB is "to be freed").
  SessionSummary get summary => retention.summarize(marks, queue);

  /// Live three-state totals (marks + queue + trash + history).
  SpaceMeterTotals get meter =>
      meterState.compute(marks, queue, trashEntries, history);

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Async entry point, shared by onInit, retry and tests (guarded).
  Future<void> init() {
    return _initFuture ??= _init();
  }

  /// Re-requests permission and reloads the deck (denied-state retry).
  Future<void> retry() async {
    _initFuture = null;
    await init();
  }

  /// Phase 3B: system picker to add photos to a limited grant,
  /// then reload against the new grant (see DeckAccess).
  Future<void> expandPartialAccess() async {
    await access.expandPartialAccess();
    await retry();
  }

  /// Phase 3B: opens system Settings ("Allow all photos" lives
  /// there); on return, "Add more photos" re-checks and reloads.
  Future<void> openPermissionSettings() async {
    await access.openPermissionSettings();
  }

  Future<void> _init() async {
    status.value = DeckStatus.loading;
    // Phase 2.2: join warmed work on the first init only. A warmed
    // denial means the user already answered the dialog (over the
    // splash); the deck must not re-prompt. A retry always goes fresh.
    final bool useWarmUp = !_warmUpUsed && (warmUp?.started ?? false);
    _warmUpUsed = true;
    MediaPermission? warmedPermission;
    if (useWarmUp) {
      try {
        warmedPermission = await warmUp!.permission;
      } catch (_) {
        warmedPermission = null;
      }
    }
    final Result<MediaPermission> result = warmedPermission != null
        ? Success<MediaPermission>(warmedPermission)
        : await media.requestPermission();
    final bool granted = result.fold(
      onSuccess: (MediaPermission value) {
        permission.value = value;
        return value != MediaPermission.denied;
      },
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
        return false;
      },
    );
    if (!granted) {
      status.value = permission.value == MediaPermission.denied
          ? DeckStatus.denied
          : DeckStatus.error;
      if (errorKey.value.isEmpty) {
        errorKey.value = AppStrings.errorMediaPermission;
      }
      return;
    }
    await _loadFilterData(initial: true, useWarmUpPage: useWarmUp);
  }

  /// Staged ready-gate (solutions 2.2). The critical path to ready
  /// is ONLY: session + page 0 + restore. Everything else moved:
  /// albums load lazily via [ensureAlbums]; the tutorial flag reads
  /// in parallel (initial load only — it is a global flag, not per
  /// filter); protection loads in parallel and is awaited only by
  /// the first delete-mark attempt (see [_ensureProtectionLoaded]);
  /// the meter refreshes after ready, without gating it. Filter
  /// changes reload session + page only (plus a parallel protection
  /// refresh, so a Settings toggle applies on the next load).
  ///
  /// Never shows a blocking "building deck" overlay: the deck becomes
  /// interactive as soon as the first page is ready (design.md §7).
  Future<void> _loadFilterData({
    bool initial = false,
    bool useWarmUpPage = false,
  }) async {
    if (initial) {
      unawaited(_readTutorialFlag());
    }
    _protectionFuture = protection.load(local);
    DeckSession? session;
    final Result<DeckSession?> sessionResult = await local.loadSession(
      filter.value.filterKey,
    );
    sessionResult.fold(
      onSuccess: (DeckSession? value) => session = value,
      onFailure: (_) => session = null,
    );
    final bool firstPageOk = initial
        ? await _loadFirstPage(useWarmUpPage)
        : await _loadPage(0);
    if (!firstPageOk) {
      status.value = DeckStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    if (await retention.restoreSession(marks, favouriteIds, session)) {
      _persist();
    }
    currentIndex.value = firstUndecidedIndex(queue, marks);
    status.value = DeckStatus.ready;
    _preloader.preloadAround(queue, currentIndex.value);
    // Post-ready: meter inputs refresh without gating readiness.
    // The meter view is reactive, so it picks the values up when
    // they land.
    unawaited(meterState.refresh(trashEntries, history));
  }

  /// Reads the tutorial flag without gating ready. The view shows
  /// the overlay reactively when the flag lands.
  Future<void> _readTutorialFlag() async {
    final Result<bool> tutorialResult = await local.isTutorialSeen();
    showTutorial.value = tutorialResult.fold(
      onSuccess: (bool seen) => !seen,
      onFailure: (_) => false,
    );
  }

  /// Page 0 for the initial load: warmed assets when the splash
  /// warmed them, otherwise a fresh fetch (also the fallback when
  /// the warmed fetch failed). Applies the page with exactly the
  /// same bookkeeping as [_loadPage].
  Future<bool> _loadFirstPage(bool useWarmUpPage) async {
    if (useWarmUpPage && warmUp != null) {
      List<MediaAsset>? warmed;
      try {
        warmed = await warmUp!.firstPage;
      } catch (_) {
        warmed = null;
      }
      if (warmed != null) {
        queue.assignAll(warmed);
        _hasMore = warmed.length == pageSize;
        _nextPage = 1;
        _refreshMonths();
        return true;
      }
    }
    return _loadPage(0);
  }

  /// Loads the album list on demand (filter sheet / album picker).
  /// Loaded once per controller life; a failure leaves the list
  /// empty and retries on the next open, never blocking the deck.
  Future<void> ensureAlbums() async {
    if (_albumsLoaded) {
      return;
    }
    final Result<List<MediaAlbum>> albumResult = await media.getAlbums();
    albumResult.fold(
      onSuccess: (List<MediaAlbum> value) {
        albums.assignAll(value);
        _albumsLoaded = true;
      },
      onFailure: (_) => albums.clear(),
    );
  }

  /// Awaits the latest protection load, once. Delete marks call this
  /// before deciding; every other mark skips it (protection only
  /// ever blocks deletes). A load failure reads as protection OFF,
  /// the same default as a settings-load failure inside
  /// [DeckProtection.load], so a broken settings read never blocks
  /// the deck.
  Future<void> _ensureProtectionLoaded() async {
    final Future<void>? pending = _protectionFuture;
    if (pending == null) {
      return;
    }
    try {
      await pending;
    } catch (_) {
      // Fail open to unprotected (see doc comment).
    }
    _protectionFuture = null;
  }

  /// Loads one page; page 0 replaces the queue, later pages append.
  /// Returns false only when the page itself fails.
  Future<bool> _loadPage(int page) async {
    if (_loadingPage) {
      return true;
    }
    _loadingPage = true;
    bool loaded = false;
    try {
      final DeckFilter currentFilter = filter.value;
      final Result<List<MediaAsset>> result = await media.getAssets(
        albumId: currentFilter.albumId,
        monthKey: currentFilter.monthKey,
        page: page,
        pageSize: pageSize,
      );
      loaded = result.fold(
        onSuccess: (List<MediaAsset> assets) {
          if (page == 0) {
            queue.assignAll(assets);
          } else {
            queue.addAll(assets);
          }
          _hasMore = assets.length == pageSize;
          _nextPage = page + 1;
          _refreshMonths();
          return true;
        },
        onFailure: (_) => false,
      );
    } finally {
      _loadingPage = false;
    }
    return loaded;
  }

  void _refreshMonths() {
    months.assignAll(monthKeysFor(queue));
  }

  /// Records [mark] for the current card and advances. No-op with
  /// no current card (empty or finished deck). Async because a
  /// delete mark awaits the parallel protection load first (2.2);
  /// every other mark skips that wait.
  Future<void> markCurrent(DeckMark mark) async {
    final MediaAsset? asset = currentAsset;
    if (asset == null || status.value != DeckStatus.ready) {
      return;
    }
    // Phase 3A: a protected delete mark is blocked, not recorded.
    // Protection loads in parallel with the deck; only a delete
    // mark waits for it, so keep/maybe/favourite never stall.
    if (mark == DeckMark.delete) {
      await _ensureProtectionLoaded();
    }
    if (protection.blocksDelete(mark, asset, favouriteIds)) {
      return;
    }
    marks[asset.id] = mark;
    if (mark == DeckMark.favourite) {
      favouriteIds.add(asset.id);
    } else {
      favouriteIds.remove(asset.id);
    }
    undoStack.add(asset.id);
    currentIndex.value += 1;
    _maybeLoadMore();
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
    // Phase 3A haptics (design.md §8): light tick on every mark.
    AppHaptics.mark();
    // Phase 2B streak day: the moment the final mark lands, this
    // session is complete. Recording is idempotent per day, so an
    // undo + re-mark on the same day records nothing new.
    if (isFinished) {
      retention.recordCompletion();
    }
  }

  /// Pops the last decision and returns to that card. Disabled (a
  /// no-op) when the undo stack is empty.
  void undo() {
    final int? index = access.undo(marks, favouriteIds, undoStack, queue);
    if (index == null) {
      return;
    }
    currentIndex.value = index >= 0 ? index : firstUndecidedIndex(queue, marks);
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
  }

  /// Rewinds assets whose delete marks were cleared by review (e.g.
  /// after a denied native confirmation, requirements §5) so the deck
  /// re-shows them instead of silently dropping them from the queue.
  void clearDeleteMarks(List<String> ids) {
    if (access.rewindDenied(marks, undoStack, ids)) {
      currentIndex.value = firstUndecidedIndex(queue, marks);
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
    }
  }

  /// Starts a fresh queue under the new filter's session key.
  Future<void> setFilter(DeckFilter next) async {
    if (next == filter.value) {
      return;
    }
    filter.value = next;
    queue.clear();
    marks.clear();
    favouriteIds.clear();
    undoStack.clear();
    _preloader.clear();
    currentIndex.value = 0;
    _hasMore = true;
    _nextPage = 0;
    status.value = DeckStatus.loading;
    await _loadFilterData();
    _persist();
  }

  /// Clears any month/album filter back to All.
  Future<void> clearFilter() => setFilter(const DeckFilter.all());

  /// Dismisses the first-run tutorial and records it, so it never
  /// reappears on later launches.
  Future<void> dismissTutorial() async {
    showTutorial.value = false;
    await local.setTutorialSeen(true);
  }

  /// Navigates to review with the delete-marked list + filter key.
  void goToReview() {
    Get.toNamed<dynamic>(
      AppRoutes.review,
      arguments: deleteMarkedAssets,
      parameters: <String, String>{'filterKey': filter.value.filterKey},
    );
  }

  void _maybeLoadMore() {
    if (loadingMore.value || !_hasMore) {
      return;
    }
    if (queue.length - currentIndex.value > paginationTrigger) {
      return;
    }
    loadingMore.value = true;
    _loadPage(_nextPage).whenComplete(() {
      loadingMore.value = false;
      _preloader.preloadAround(queue, currentIndex.value);
    });
  }

  /// Persists on every mark, undo and filter change — never on every
  /// animation frame. A save failure does not block swiping.
  void _persist() {
    local.saveSession(
      DeckSession(
        filterKey: filter.value.filterKey,
        currentIndex: currentIndex.value,
        marks: Map<String, DeckMark>.of(marks),
        favouriteIds: Set<String>.of(favouriteIds),
      ),
    );
  }
}
