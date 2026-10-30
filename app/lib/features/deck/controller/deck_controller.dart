import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/deferred_action.dart';
import '../../../core/utils/result.dart';
import '../../../services/lifecycle/app_lifecycle.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/review_ask/review_ask_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/trash/trash_entry.dart';
import '../../../services/trash/trash_service.dart';
import '../../../services/warmup/deck_warm_up.dart';
import '../../finish/model/finish_summary.dart';
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
    ThumbnailService? thumbnailService,
    this.lifecycle,
    this.reviewAsk,
  }) : _preloader = ThumbnailPreloader(media: media, service: thumbnailService),
       retention = DeckRetention(local: local, share: share),
       access = DeckAccess(media: media),
       meterState = DeckMeter(trash: trash, local: local);

  final MediaService media;
  final TrashService trash;
  final LocalService local;

  /// Phase 4.4 lifecycle delivery (null in tests and on entry
  /// paths without the initial binding: the deck then behaves
  /// exactly as before, with no resume handling).
  final AppLifecycle? lifecycle;

  /// Review-ask service (fix plan Stage 5, ADR-020), optional:
  /// marks and completed trash batches are counted here, and
  /// the view reads it to present the swipe/home asks. Null in
  /// tests that do not wire it — counting is then simply off.
  final ReviewAskService? reviewAsk;

  /// A completed Clean-deck trash batch (Stage 5), published
  /// for the view to present as the finish screen; the view
  /// consumes it (sets it back to null) when it navigates.
  final Rx<FinishSummary?> lastFinishSummary = Rx<FinishSummary?>(null);

  /// Set when a mark finishes this session: the view presents
  /// the swipe-place review ask (session end only, never
  /// mid-session), then consumes the flag.
  final RxBool swipeAskPending = false.obs;

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

  /// Two-second undo window for delete swipes (owner decision
  /// 26 Oct 2026, ADR-013): the photo stays delete-marked and
  /// undoable for [pendingDeleteWindow]; then it commits to
  /// [_awaitingTrash]. A new mark commits it at once, so swiping
  /// on is the confirmation. The delete mark itself is kept
  /// until the native batch lands, so the session stays the
  /// source of truth for intent (a Review keep/unmark rewinds
  /// instead of trashing).
  static const Duration pendingDeleteWindow = Duration(seconds: 2);

  Timer? _pendingDeleteTimer;
  MediaAsset? _pendingDelete;

  /// Delete-swiped photos committed by the deck but not yet
  /// moved to Trash by the native sheet. The batch fires once
  /// when the user leaves the Clean deck (see
  /// [flushAwaitingTrash]); if the app dies first, these photos
  /// simply reappear undecided on the next launch.
  final List<MediaAsset> _awaitingTrash = <MediaAsset>[];

  bool _flushingTrash = false;

  /// Set when the batched native sheet is denied: the deck shows
  /// a banner until dismissed.
  final RxString trashBatchDeniedKey = ''.obs;
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

  /// The delete-swiped photo still inside its undo window, if any.
  MediaAsset? get pendingDelete => _pendingDelete;

  /// Committed photos still waiting for the native batch.
  List<MediaAsset> get awaitingTrash =>
      List<MediaAsset>.unmodifiable(_awaitingTrash);

  /// True only for the honest Android 14 partial-access state.
  bool get isPartialAccess =>
      permission.value == MediaPermission.grantedLimited;

  /// Assets marked delete: the review set (see class doc).
  /// Includes both committed photos waiting in [_awaitingTrash]
  /// and newly swiped photos still in [queue].
  List<MediaAsset> get deleteMarkedAssets {
    final List<MediaAsset> queued = queue
        .where((MediaAsset asset) => marks[asset.id] == DeckMark.delete)
        .toList();
    if (_awaitingTrash.isEmpty) {
      return queued;
    }
    final Set<String> queuedIds = queued.map((MediaAsset a) => a.id).toSet();
    return <MediaAsset>[
      for (final MediaAsset asset in _awaitingTrash)
        if (!queuedIds.contains(asset.id)) asset,
      ...queued,
    ];
  }

  /// Finished-session summary (Phase 2B; delete MB is "to be freed").
  SessionSummary get summary => retention.summarize(marks, queue);

  /// Live three-state totals (marks + queue + trash + history).
  SpaceMeterTotals get meter =>
      meterState.compute(marks, queue, trashEntries, history);

  @override
  void onInit() {
    super.onInit();
    // Phase 4.4: pause/resume + library-change delivery. The
    // deck owns no scan, so its pause work is only the
    // preloader (flush on pause is central, in AppLifecycleImpl).
    if (lifecycle != null) {
      lifecycle!.addPauseListener(_handlePause);
      lifecycle!.addResumeListener(_handleResume);
      _librarySubscription = lifecycle!.libraryChanged.listen(
        (_) => _onLibraryChanged(),
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
    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;
    _pendingDelete = null;
    unawaited(_librarySubscription?.cancel());
    _librarySubscription = null;
    // Dispose flush point (solutions 4.1/4.4): never leave a
    // coalesced session write behind when the controller goes.
    unawaited(local.flushPendingWrites());
    super.onClose();
  }

  /// Phase 4.4: assets of the last page-0 fetch, for the merge in
  /// [refreshPageZero] (dates decide gone vs displaced — see
  /// [mergePageZero]). Empty until the first page 0 lands, in
  /// which case a refresh only ever prepends (nothing is known
  /// gone yet).
  List<MediaAsset> _lastPageZero = <MediaAsset>[];

  /// Phase 4.4: resume handling in flight (see [_handleResume]).
  /// [markCurrent] awaits it so a mark can never be overwritten
  /// by the reload's session restore.
  Future<void>? _resumeFuture;

  /// Phase 4.4: page-0 refresh in flight (see [refreshPageZero]).
  /// Concurrent refreshes are no-ops: the in-flight fetch covers
  /// them (same page, same merge, idempotent result).
  bool _refreshing = false;

  StreamSubscription<void>? _librarySubscription;

  void _handlePause() {
    _preloader.setPaused(true);
  }

  void _handleResume() {
    if (_resumeFuture != null) {
      return;
    }
    _resumeFuture = _doResume();
    _resumeFuture!.whenComplete(() {
      _resumeFuture = null;
    });
  }

  /// Phase 4.4 resume sequence (never throws: a failed resume
  /// keeps the pre-resume state rather than crashing the deck).
  /// 1. Unpause the preloader. 2. Flush pending session writes
  /// so any later reload reads current marks. 3. Apply snooze
  /// expiry once (one batched write when something cleared).
  /// 4. If the deck is not ready, retry from scratch — this is
  /// the deny → Settings → grant → return path, no manual tap.
  /// 5. Re-check permission (never a persisted value): denied →
  /// denied state + explanation; level changed → full reload
  /// (the visible set becomes the new grant); unchanged →
  /// cheap page-0 refresh, marks and position preserved.
  Future<void> _doResume() async {
    try {
      // Stage 5: a resume is a use of the app — count the day
      // for the home review ask (date-only, de-duplicated by
      // the service). Fire-and-forget like every ask write.
      final ReviewAskService? ask = reviewAsk;
      if (ask != null) {
        unawaited(ask.recordUsageDay(DateTime.now()));
      }
      _preloader.setPaused(false);
      await local.flushPendingWrites();
      if (status.value == DeckStatus.ready) {
        final ({Map<String, DeckMark> marks, bool changed}) expiry =
            await retention.clearExpiredSnoozes(
              Map<String, DeckMark>.of(marks),
              DateTime.now(),
            );
        if (expiry.changed) {
          marks.assignAll(expiry.marks);
          _persist();
        }
      }
      if (status.value != DeckStatus.ready) {
        await retry();
        return;
      }
      final Result<MediaPermission> permResult = await media
          .requestPermission();
      final MediaPermission? fresh = permResult.fold(
        onSuccess: (MediaPermission value) => value,
        onFailure: (_) => null,
      );
      if (fresh == null) {
        // Re-check failed: keep the current state untouched.
        return;
      }
      if (fresh == MediaPermission.denied) {
        permission.value = fresh;
        status.value = DeckStatus.denied;
        errorKey.value = AppStrings.errorMediaPermission;
        return;
      }
      if (fresh != permission.value) {
        permission.value = fresh;
        await _loadFilterData();
        return;
      }
      await refreshPageZero();
    } catch (_) {
      // Resume handling must never crash the deck.
    }
  }

  /// Phase 4.4: a library-change event while foregrounded
  /// refreshes page 0 immediately (the merge preserves position
  /// and marks). Background changes are covered by the resume
  /// handler, which always refreshes — so nothing is needed here
  /// while backgrounded.
  void _onLibraryChanged() {
    if (lifecycle?.isBackgrounded ?? false) {
      return;
    }
    if (status.value != DeckStatus.ready) {
      return;
    }
    unawaited(refreshPageZero());
  }

  /// Phase 4.4 cheap page-0 refresh (see [mergePageZero] for the
  /// merge contract and its honest bounds). A failed fetch keeps
  /// the current queue; the next resume or change event retries.
  Future<void> refreshPageZero() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final DeckFilter currentFilter = filter.value;
      final Result<List<MediaAsset>> result = await media.getAssets(
        albumId: currentFilter.albumId,
        monthKey: currentFilter.monthKey,
        page: 0,
        pageSize: pageSize,
      );
      result.fold(
        onSuccess: (List<MediaAsset> fresh) {
          final ({List<MediaAsset> queue, int index}) merged = mergePageZero(
            queue: queue.toList(),
            freshPageZero: fresh,
            oldPageZero: _lastPageZero,
            pageSize: pageSize,
            index: currentIndex.value,
          );
          queue.assignAll(merged.queue);
          currentIndex.value = merged.index;
          _lastPageZero = fresh;
          _refreshMonths();
          _preloader.preloadAround(queue, currentIndex.value);
        },
        onFailure: (_) {},
      );
    } finally {
      _refreshing = false;
    }
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
    // Stage 5 resume (ADR-020 decision 4): the session stores
    // where the user left, and first-undecided IS that photo —
    // but only once its page is loaded. When a decided run
    // crosses a page boundary, the photo sits on a later page
    // and the deck would wrongly show the finished summary;
    // page forward until it is loaded or pages run out. A
    // failed page stops the walk and keeps the old behaviour.
    while (currentIndex.value >= queue.length && _hasMore) {
      if (!await _loadPage(_nextPage)) {
        break;
      }
      currentIndex.value = firstUndecidedIndex(queue, marks);
    }
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
        _lastPageZero = warmed;
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
            _lastPageZero = assets;
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
  ///
  /// Phase 2.5: refuses when the current card has no visible
  /// thumbnail (still loading or failed). The action bar is shown
  /// as soon as the deck is ready, so buttons alone cannot gate
  /// this — a mark on an unseen photo is never recorded, and no
  /// banner, haptic or advance happens for it.
  Future<void> markCurrent(DeckMark mark) async {
    // Phase 4.4: a resume reload may be in flight; a mark
    // recorded during it would be overwritten by the reload's
    // session restore, so wait for the resume to settle first.
    final Future<void>? resume = _resumeFuture;
    if (resume != null) {
      try {
        await resume;
      } catch (_) {
        // Resume handling never throws (see _doResume), but a
        // mark must never be lost to a resume failure.
      }
    }
    final MediaAsset? asset = currentAsset;
    if (asset == null || status.value != DeckStatus.ready) {
      return;
    }
    if (!thumbnails.containsKey(asset.id) ||
        failedThumbnails.contains(asset.id)) {
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
    // A new decision commits the previous delete swipe at once:
    // swiping on is the confirmation (ADR-013). Refused marks
    // never reach here (the guards above return first).
    _commitPendingDelete();
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
    if (mark == DeckMark.delete) {
      _startPendingDelete(asset);
    }
    // Phase 3A haptics (design.md §8): light tick on every mark.
    AppHaptics.mark();
    // Stage 5 counting point (ADR-020 decision 6): every
    // recorded mark counts as a swipe for the review ask.
    // Fire-and-forget — counting never delays a swipe.
    final ReviewAskService? ask = reviewAsk;
    if (ask != null) {
      unawaited(ask.recordSwipe());
    }
    // Phase 2B streak day: the moment the final mark lands, this
    // session is complete. Recording is idempotent per day, so an
    // undo + re-mark on the same day records nothing new.
    if (isFinished) {
      retention.recordCompletion();
      // Stage 5: session end is the swipe ask's moment — flag
      // it for the view (never mid-session).
      swipeAskPending.value = true;
    }
  }

  /// Phase 2.5 explicit retry for a failed current card: clears
  /// the failed mark and re-fetches the window, so the card
  /// becomes visible (or fails again) instead of staying a dead
  /// end. No-op with no current card.
  void retryCurrentThumbnail() {
    final MediaAsset? asset = currentAsset;
    if (asset == null) {
      return;
    }
    _preloader.retry(asset.id);
    _preloader.preloadAround(queue, currentIndex.value);
  }

  /// Pops the last decision and returns to that card. Disabled (a
  /// no-op) when the undo stack is empty.
  void undo() {
    final int? index = access.undo(marks, favouriteIds, undoStack, queue);
    // The pending delete (if any) was the popped entry by
    // construction: a new mark always commits it first.
    // Cancelling here is safe even if that invariant ever
    // breaks — the photo simply stays delete-marked until the
    // next mark or Review.
    _cancelPendingDelete();
    if (index == null) {
      return;
    }
    currentIndex.value = index >= 0 ? index : firstUndecidedIndex(queue, marks);
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
  }

  /// Starts the undo window for a freshly delete-swiped photo.
  /// Any previous window is already closed: a new mark commits
  /// it first, and undo cancels it.
  void _startPendingDelete(MediaAsset asset) {
    _pendingDeleteTimer?.cancel();
    _pendingDelete = asset;
    _pendingDeleteTimer = Timer(pendingDeleteWindow, _commitPendingDelete);
  }

  /// Closes the undo window without committing: the photo keeps
  /// whatever mark it has (undo already popped it, or a Review
  /// action cleared it).
  void _cancelPendingDelete() {
    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;
    _pendingDelete = null;
  }

  /// Commits the pending delete swipe to the trash pipeline:
  /// the photo leaves the deck queue and its undo entry, and
  /// waits in [_awaitingTrash] for the batched native sheet.
  /// The delete mark is deliberately KEPT (in memory and in the
  /// session) until that sheet lands: the session stays the
  /// source of truth for intent, so a Review keep/unmark rewinds
  /// instead of trashing, and the meter (queue-only lookups)
  /// never counts a photo that is not in the queue. No-op when
  /// the photo already left the queue (trashed via Review) or
  /// its mark was cleared while the window was open.
  void _commitPendingDelete() {
    final MediaAsset? pending = _pendingDelete;
    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;
    _pendingDelete = null;
    if (pending == null) {
      return;
    }
    final int index = queue.indexWhere(
      (MediaAsset asset) => asset.id == pending.id,
    );
    if (index == -1) {
      return;
    }
    if (marks[pending.id] != DeckMark.delete) {
      return;
    }
    queue.removeAt(index);
    undoStack.remove(pending.id);
    if (index < currentIndex.value) {
      currentIndex.value -= 1;
    }
    _awaitingTrash.add(pending);
    _refreshMonths();
    _maybeLoadMore();
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
  }

  /// Moves every committed photo to Trash through ONE native
  /// sheet. One sheet per batch, never one per photo: per-photo
  /// sheets would interrupt swiping, which is exactly the
  /// friction this removes. Re-entrant calls and empty batches
  /// are no-ops. (Its former shell tab-switch trigger was
  /// removed by the owner in 306f75d; Stage 5 hooks the
  /// COMPLETION — the finish summary + ask counting below —
  /// never a new trigger. ADR-020 decision 1.)
  ///
  /// Intent is verified against the session before anything is
  /// trashed: a photo Review kept or unmarked after its swipe
  /// rewinds to the deck undecided instead of being trashed,
  /// and a photo Review already trashed is simply dropped. A
  /// failed session read fails safe: nothing is trashed and the
  /// batch waits for the next trigger. Denied photos rewind to
  /// the deck with a banner; unreachable photos are dropped
  /// (MediaStore cannot return them, so retrying is pointless).
  Future<void> flushAwaitingTrash() async {
    if (_awaitingTrash.isEmpty || _flushingTrash) {
      return;
    }
    _flushingTrash = true;
    try {
      final Result<DeckSession?> sessionResult = await local.loadSession(
        filter.value.filterKey,
      );
      if (sessionResult.isFailure) {
        return;
      }
      final Map<String, DeckMark> sessionMarks =
          (sessionResult as Success<DeckSession?>).value?.marks ??
          <String, DeckMark>{};
      final Result<List<TrashEntry>> trashedResult = await trash.listTrashed();
      final Set<String> alreadyTrashed = trashedResult.fold(
        onSuccess: (List<TrashEntry> entries) =>
            entries.map((TrashEntry entry) => entry.assetId).toSet(),
        onFailure: (_) => <String>{},
      );
      final List<MediaAsset> toTrash = <MediaAsset>[];
      final List<MediaAsset> toRewind = <MediaAsset>[];
      for (final MediaAsset asset in _awaitingTrash) {
        if (alreadyTrashed.contains(asset.id)) {
          continue;
        }
        if (sessionMarks[asset.id] == DeckMark.delete) {
          toTrash.add(asset);
        } else {
          toRewind.add(asset);
        }
      }
      int insertAt = currentIndex.value;
      for (final MediaAsset asset in toRewind) {
        insertAt = _rewindAsset(asset, insertAt);
      }
      _awaitingTrash.removeWhere(
        (MediaAsset asset) =>
            toRewind.contains(asset) || alreadyTrashed.contains(asset.id),
      );
      if (toTrash.isEmpty) {
        if (toRewind.isNotEmpty) {
          _refreshMonths();
          _preloader.preloadAround(queue, currentIndex.value);
          _persist();
        }
        return;
      }
      final Result<TrashOutcome> result = await trash.trashAssets(
        toTrash.map((MediaAsset asset) => asset.id).toList(),
      );
      if (result.isFailure) {
        if (toRewind.isNotEmpty) {
          _refreshMonths();
          _preloader.preloadAround(queue, currentIndex.value);
          _persist();
        }
        return;
      }
      final TrashOutcome outcome = (result as Success<TrashOutcome>).value;
      final Set<String> trashedIds = outcome.trashedIds.toSet();
      final Set<String> deniedIds = outcome.deniedIds.toSet();
      for (final MediaAsset asset in toTrash) {
        if (trashedIds.contains(asset.id)) {
          // Trashed photos keep their delete mark in memory and
          // in the session, exactly like Review-trashed photos:
          // decided photos behind the index are never re-shown,
          // and MediaStore hides them from fresh loads anyway.
        } else if (deniedIds.contains(asset.id)) {
          insertAt = _rewindAsset(asset, insertAt);
        }
        // Unreachable photos are simply dropped from the batch
        // (their mark stays delete; MediaStore cannot return
        // them, so retrying is pointless).
      }
      _awaitingTrash.removeWhere((MediaAsset asset) => toTrash.contains(asset));
      if (deniedIds.isNotEmpty) {
        trashBatchDeniedKey.value = AppStrings.trashBatchDenied;
      }
      if (trashedIds.isNotEmpty) {
        // Stage 5 (ADR-020 decisions 1–2, 6): a completed trash
        // batch is a delete batch. Its finish summary reads the
        // recover-by date back from the entries the trash
        // service just recorded (the batch's earliest), and the
        // batch counts toward the review ask.
        int bytes = 0;
        for (final MediaAsset asset in toTrash) {
          if (trashedIds.contains(asset.id)) {
            bytes += asset.sizeBytes;
          }
        }
        DateTime? recoverableUntil;
        final Result<List<TrashEntry>> entriesResult = await trash
            .listTrashed();
        entriesResult.fold(
          onSuccess: (List<TrashEntry> entries) {
            for (final TrashEntry entry in entries) {
              if (!trashedIds.contains(entry.assetId)) {
                continue;
              }
              if (recoverableUntil == null ||
                  entry.recoverableUntil.isBefore(recoverableUntil!)) {
                recoverableUntil = entry.recoverableUntil;
              }
            }
          },
          onFailure: (_) {},
        );
        lastFinishSummary.value = FinishSummary(
          deletedCount: trashedIds.length,
          sizeBytes: bytes,
          spaceState: FinishSpaceState.inTrash,
          recoverableUntil: recoverableUntil,
        );
        final ReviewAskService? ask = reviewAsk;
        if (ask != null) {
          unawaited(
            ask.recordDeleteBatch(count: trashedIds.length, bytes: bytes),
          );
        }
      }
      _refreshMonths();
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
      unawaited(meterState.refresh(trashEntries, history));
    } finally {
      _flushingTrash = false;
    }
  }

  /// Dismisses the batched-trash denial banner.
  void clearTrashDeniedNotice() {
    trashBatchDeniedKey.value = '';
  }

  /// Returns a photo to the deck undecided, as the current card
  /// (or the next slot when several rewind at once). A photo
  /// that re-entered the queue through a fresh load (e.g. after
  /// a filter change) only loses its mark — inserting it again
  /// would show the same photo twice. Returns the next insert
  /// position.
  int _rewindAsset(MediaAsset asset, int insertAt) {
    marks.remove(asset.id);
    if (queue.any((MediaAsset queued) => queued.id == asset.id)) {
      return insertAt;
    }
    final int at = insertAt.clamp(0, queue.length);
    queue.insert(at, asset);
    return insertAt + 1;
  }

  /// Rewinds assets whose delete marks were cleared by review (e.g.
  /// after a denied native confirmation, requirements §5) so the deck
  /// re-shows them instead of silently dropping them from the queue.
  void clearDeleteMarks(List<String> ids) {
    // A denied photo that is still inside its undo window comes
    // back undecided: close the window so the timer cannot
    // commit it after the rewind.
    if (_pendingDelete != null && ids.contains(_pendingDelete!.id)) {
      _cancelPendingDelete();
    }
    final Set<String> idSet = ids.toSet();
    final List<MediaAsset> toRewind = <MediaAsset>[];
    _awaitingTrash.removeWhere((MediaAsset asset) {
      if (idSet.contains(asset.id)) {
        toRewind.add(asset);
        return true;
      }
      return false;
    });
    int insertAt = currentIndex.value;
    for (final MediaAsset asset in toRewind) {
      insertAt = _rewindAsset(asset, insertAt);
    }
    if (access.rewindDenied(marks, undoStack, ids) || toRewind.isNotEmpty) {
      currentIndex.value = firstUndecidedIndex(queue, marks);
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
    }
  }

  /// Cancels an awaiting or pending delete swipe from Review:
  /// removes the photo from [_awaitingTrash] (or cancels its
  /// pending window), clears its mark, and rewinds it into
  /// [queue] undecided at [currentIndex] so it returns to the
  /// deck as the current card.
  void cancelAwaiting(MediaAsset asset) {
    if (_pendingDelete?.id == asset.id) {
      _cancelPendingDelete();
      marks.remove(asset.id);
      final int idx = queue.indexWhere((MediaAsset a) => a.id == asset.id);
      if (idx != -1 && idx < currentIndex.value) {
        currentIndex.value = idx;
      }
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
      return;
    }
    final int awaitingIdx = _awaitingTrash.indexWhere(
      (MediaAsset a) => a.id == asset.id,
    );
    if (awaitingIdx != -1) {
      final MediaAsset removed = _awaitingTrash.removeAt(awaitingIdx);
      _rewindAsset(removed, currentIndex.value);
      _refreshMonths();
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
      return;
    }
    if (marks[asset.id] == DeckMark.delete) {
      marks.remove(asset.id);
      final int idx = queue.indexWhere((MediaAsset a) => a.id == asset.id);
      if (idx != -1 && idx < currentIndex.value) {
        currentIndex.value = idx;
      }
      _preloader.preloadAround(queue, currentIndex.value);
      _persist();
    }
  }

  /// Records keep marks from Review: removes them from
  /// [_awaitingTrash] so they are never trashed, and updates
  /// their marks to keep.
  void markAssetsKept(Iterable<String> assetIds) {
    final Set<String> ids = assetIds.toSet();
    if (_pendingDelete != null && ids.contains(_pendingDelete!.id)) {
      _cancelPendingDelete();
    }
    _awaitingTrash.removeWhere((MediaAsset a) => ids.contains(a.id));
    for (final String id in ids) {
      marks[id] = DeckMark.keep;
    }
    _persist();
  }

  /// Drops confirmed-trashed photos from [_awaitingTrash] when
  /// Review trashes them, so [flushAwaitingTrash] will never
  /// re-trash them.
  void removeTrashedAssets(Iterable<String> assetIds) {
    final Set<String> ids = assetIds.toSet();
    if (_pendingDelete != null && ids.contains(_pendingDelete!.id)) {
      _cancelPendingDelete();
    }
    _awaitingTrash.removeWhere((MediaAsset a) => ids.contains(a.id));
    undoStack.removeWhere((String id) => ids.contains(id));
    for (final String id in ids) {
      marks.remove(id);
    }
    _persist();
    unawaited(meterState.refresh(trashEntries, history));
  }

  /// Rewinds denied photos from Review to the deck queue as
  /// undecided, and sets [trashBatchDeniedKey] so the deck
  /// shows the denial notice banner on return.
  void handleDeniedTrash(Iterable<String> deniedIds) {
    final Set<String> ids = deniedIds.toSet();
    if (_pendingDelete != null && ids.contains(_pendingDelete!.id)) {
      _cancelPendingDelete();
    }
    final List<MediaAsset> toRewind = <MediaAsset>[];
    _awaitingTrash.removeWhere((MediaAsset asset) {
      if (ids.contains(asset.id)) {
        toRewind.add(asset);
        return true;
      }
      return false;
    });
    int insertAt = currentIndex.value;
    for (final MediaAsset asset in toRewind) {
      insertAt = _rewindAsset(asset, insertAt);
    }
    for (final String id in ids) {
      marks.remove(id);
    }
    trashBatchDeniedKey.value = AppStrings.trashBatchDenied;
    _refreshMonths();
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
  }

  /// Starts a fresh queue under the new filter's session key.
  Future<void> setFilter(DeckFilter next) async {
    if (next == filter.value) {
      return;
    }
    // A filter change must not strand a photo inside its undo
    // window: commit it to the trash pipeline first.
    _commitPendingDelete();
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
    // Filter-change flush point (solutions 4.1/4.4): the new
    // filter's session must not sit in the coalescing window.
    unawaited(local.flushPendingWrites());
  }

  /// Clears any month/album filter back to All.
  Future<void> clearFilter() => setFilter(const DeckFilter.all());

  /// Dismisses the first-run tutorial and records it, so it never
  /// reappears on later launches.
  Future<void> dismissTutorial() async {
    showTutorial.value = false;
    await local.setTutorialSeen(true);
  }

  /// Phase 3.2 settled-review gate, closed by Phase 7.1: while a
  /// card exit animation is in flight its mark is unrecorded, so
  /// review navigation requested then defers until the mark
  /// records instead of opening review with a stale mark set. The
  /// view drives this from the card's exit callbacks — the gate
  /// releases when the swipe's mark records (see the onSwiped
  /// wiring in deck_view.dart), NOT when the exit animation ends:
  /// releasing on exit-end would capture the review set before
  /// the in-flight mark lands. Retained tab switches keep the
  /// deck alive, so the flight always completes; the shell's
  /// Trash-tab navigation defers through [runAfterCardExit].
  final DeferredAction _reviewGate = DeferredAction();

  /// True while a card exit animation is in flight.
  bool get isCardExiting => _reviewGate.isBusy;

  /// Called by the view from the card's exit callbacks.
  void setCardExiting(bool exiting) => _reviewGate.setBusy(exiting);

  /// Runs [action] once no card exit is in flight — immediately
  /// when idle, deferred until the in-flight mark records when
  /// busy. The shell's Trash-tab navigation uses this so Review
  /// never opens with the in-flight mark missing.
  void runAfterCardExit(void Function() action) => _reviewGate.run(action);

  /// Navigates to review with the delete-marked list + filter key,
  /// deferred while a card exit is in flight (see [_reviewGate]).
  void goToReview() => _reviewGate.run(_goToReviewNow);

  void _goToReviewNow() {
    // Go-to-review flush point (solutions 4.1/4.4): review reads
    // the session, so the marks behind it must be on disk first.
    unawaited(local.flushPendingWrites());
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
