import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/trash/trash_entry.dart';
import '../../../services/trash/trash_service.dart';
import '../model/deck_filter.dart';
import '../model/deck_status.dart';
import '../model/space_meter.dart';
import '../model/thumbnail_preloader.dart';

/// The deck: permission, paged queue, marks, undo, filters, session
/// resume, thumbnail preloading and the three-state space meter
/// (requirements §3, §4, §5, §7 / design.md §7).
///
/// Queue: one ordered list per filter, newest first. [currentIndex]
/// points at the current card; "next undecided" is the first queue
/// index with no mark. A swipe or button records the mark and
/// advances; undo pops the last decision and returns to that card.
/// Default queue covers images AND videos (both permissions exist,
/// trash mechanics identical; splitting them would be a Phase 2 deck).
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
  }) : _preloader = ThumbnailPreloader(media: media);

  final MediaService media;
  final TrashService trash;
  final LocalService local;

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

  Future<void>? _initFuture;
  bool _hasMore = true;
  int _nextPage = 0;
  bool _loadingPage = false;

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

  /// True only for the honest Android 14 partial-access state: the
  /// deck works on exactly the granted photos and says so.
  bool get isPartialAccess =>
      permission.value == MediaPermission.grantedLimited;

  /// Assets marked delete: the review set (see class doc).
  List<MediaAsset> get deleteMarkedAssets {
    return queue
        .where((MediaAsset asset) => marks[asset.id] == DeckMark.delete)
        .toList();
  }

  /// Live three-state totals (marks + queue + trash + history).
  /// Trashed MB is never counted as freed (see space_meter.dart).
  SpaceMeterTotals get meter {
    return computeSpaceMeter(
      marks: marks,
      assetsById: <String, MediaAsset>{
        for (final MediaAsset asset in queue) asset.id: asset,
      },
      trashEntries: trashEntries,
      history: history,
    );
  }

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Async entry point, shared by onInit, retry and tests. Guarded so
  /// concurrent callers share one run instead of double-loading.
  Future<void> init() {
    return _initFuture ??= _init();
  }

  /// Re-requests permission and reloads the deck (denied-state retry).
  Future<void> retry() async {
    _initFuture = null;
    await init();
  }

  Future<void> _init() async {
    status.value = DeckStatus.loading;
    final Result<MediaPermission> result = await media.requestPermission();
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
    await _loadFilterData();
  }

  /// Loads albums, meter inputs, the tutorial flag, the saved session
  /// for the current filter and the first page. Never shows a blocking
  /// "building deck" overlay: the deck becomes interactive as soon as
  /// the first page is ready (design.md §7).
  Future<void> _loadFilterData() async {
    final Result<List<MediaAlbum>> albumResult = await media.getAlbums();
    albumResult.fold(
      onSuccess: albums.assignAll,
      onFailure: (_) => albums.clear(),
    );
    await refreshMeter();
    final Result<bool> tutorialResult = await local.isTutorialSeen();
    showTutorial.value = tutorialResult.fold(
      onSuccess: (bool seen) => !seen,
      onFailure: (_) => false,
    );
    DeckSession? session;
    final Result<DeckSession?> sessionResult = await local.loadSession(
      filter.value.filterKey,
    );
    sessionResult.fold(
      onSuccess: (DeckSession? value) => session = value,
      onFailure: (_) => session = null,
    );
    final bool firstPageOk = await _loadPage(0);
    if (!firstPageOk) {
      status.value = DeckStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    if (session != null) {
      // Marks for assets no longer present are kept in the map but
      // contribute nothing (meter looks assets up by id) and never
      // crash resume: the resume index scans the loaded queue only.
      marks.assignAll(session!.marks);
      favouriteIds.assignAll(session!.favouriteIds);
    }
    currentIndex.value = _firstUndecidedIndex();
    status.value = DeckStatus.ready;
    _preloader.preloadAround(queue, currentIndex.value);
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

  int _firstUndecidedIndex() {
    for (int i = 0; i < queue.length; i++) {
      if (!marks.containsKey(queue[i].id)) {
        return i;
      }
    }
    return queue.length;
  }

  /// Records [mark] for the current card and advances. No-op with
  /// no current card (empty or finished deck).
  void markCurrent(DeckMark mark) {
    final MediaAsset? asset = currentAsset;
    if (asset == null || status.value != DeckStatus.ready) {
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
  }

  /// Pops the last decision and returns to that card. Disabled (a
  /// no-op) when the undo stack is empty.
  void undo() {
    if (undoStack.isEmpty) {
      return;
    }
    final String id = undoStack.removeLast();
    final bool wasFavourite = marks[id] == DeckMark.favourite;
    marks.remove(id);
    if (wasFavourite) {
      favouriteIds.remove(id);
    }
    final int index = queue.indexWhere((MediaAsset asset) => asset.id == id);
    currentIndex.value = index >= 0 ? index : _firstUndecidedIndex();
    _preloader.preloadAround(queue, currentIndex.value);
    _persist();
  }

  /// Rewinds assets whose delete marks were cleared by review (e.g.
  /// after a denied native confirmation, requirements §5) so the deck
  /// re-shows them instead of silently dropping them from the queue.
  void clearDeleteMarks(List<String> ids) {
    bool changed = false;
    for (final String id in ids) {
      if (marks[id] == DeckMark.delete) {
        marks.remove(id);
        undoStack.remove(id);
        changed = true;
      }
    }
    if (changed) {
      currentIndex.value = _firstUndecidedIndex();
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

  /// Reloads Trash records and history for the meter. Failures leave
  /// the previous totals in place rather than erroring the deck.
  Future<void> refreshMeter() async {
    final Result<List<TrashEntry>> trashResult = await trash.listTrashed();
    trashResult.fold(onSuccess: trashEntries.assignAll, onFailure: (_) {});
    final Result<List<HistoryRecord>> historyResult = await local.loadHistory();
    historyResult.fold(onSuccess: history.assignAll, onFailure: (_) {});
  }

  /// Navigates to review: the delete-marked list as arguments, the
  /// deck filter key as a route parameter (for session writes).
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
