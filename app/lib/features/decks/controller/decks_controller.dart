// Smart-deck hub state (requirements §7, Phase 2).
//
// The hub NEVER blocks on a full-library scan before showing
// anything: the scanner reports each page, and this controller
// appends each page's assets to their decks immediately, so rows
// fill in as their counts become known. A determinate progress bar
// (scanned count + % against the estimated library total) sits at
// the top while scanning. Bursts and duplicates are list-level
// results, so their rows stay in "still scanning" until the scan
// completes; every other deck updates per page.
//
// Failure handling: a denied permission shows the denied state; a
// failed page keeps whatever arrived and flips to error only when
// nothing arrived at all (partial results beat no results).
//
// Phase 3B performance (requirements §7, 50,000+ photos): the hub
// used to rebuild O(library) structures on every scan page —
// copying each deck list per asset (`[...assetsFor(id), asset]`),
// rebuilding the asset-by-id map inside [maybeItems], and summing
// every deck's bytes inside [totalBytesFor]. On a 50k library with
// 1,000 pages that is quadratic. Now the scan accumulates deck
// lists, byte totals, the by-id map and the marked-bytes total
// incrementally per page, so a page costs O(page) and a hub rebuild
// costs O(user marks), not O(library).

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/photo_analysis.dart';
import '../../../services/detection/scan_repository.dart';
import '../../../services/detection/scan_repository_impl.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/storage/storage_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';
import '../../../services/trash/trash_entry.dart';
import '../../deck/model/retention.dart';
import '../model/decks_status.dart';
import '../model/maybe_items.dart';
import '../model/timeline_grouping.dart';
import '../model/maybe_pile_item.dart';
import '../model/smart_deck_launch.dart';

class DecksController extends GetxController {
  DecksController({
    required this.media,
    required this.local,
    this.storage,
    ThumbnailService? thumbnailService,
    ScanRepository? scanRepository,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media),
       _scans =
           scanRepository ?? ScanRepositoryImpl(media: media, local: local);

  final MediaService media;
  final LocalService local;

  /// Phase 4.2: the shared scan (see scan_repository.dart). The
  /// binding supplies the app-wide instance; tests that construct
  /// the controller directly get a private one.
  final ScanRepository _scans;
  ScanSubscription? _scanSubscription;

  /// Phase 2.3: hub previews read through the shared thumbnail
  /// service instead of fetching per widget in `initState`.
  final ThumbnailService _thumbnails;

  /// Service-owned bytes / failures for one hub size (128 for
  /// preview strips, 256 for month covers).
  RxMap<String, Uint8List> thumbnailsFor(int size) =>
      _thumbnails.thumbnailsFor(size);
  RxSet<String> failedFor(int size) => _thumbnails.failedFor(size);

  /// Idempotent hub preview request, for one hub size.
  void requestThumbnail(String id, int size) =>
      _thumbnails.requestThumbnail(id, size);

  /// Device-storage backend (Phase 2B projection). Null in tests
  /// that construct the controller without one — the hub then
  /// shows the labelled library projection instead.
  final StorageService? storage;

  /// Slider default, shared with the Duplicates screen: the hub's
  /// duplicates row counts groups at this threshold.
  static const int duplicatesThreshold = 5;

  final Rx<DecksStatus> status = DecksStatus.loading.obs;
  final RxString errorKey = ''.obs;
  final RxInt scanned = 0.obs;
  final Rx<int?> estimatedTotal = Rx<int?>(null);
  final RxBool scanComplete = false.obs;
  final RxMap<SmartDeckId, List<MediaAsset>> deckAssets =
      <SmartDeckId, List<MediaAsset>>{}.obs;
  final RxMap<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{}.obs;

  // Phase 4.3 incremental timeline state, built per scan page
  // (see TimelineAccumulator) — never recomputed over the whole
  // library in build(). The view reads [timelineTotalBytes],
  // [timelineYears] and [monthsForYear] (at most 12 summaries),
  // so a hub rebuild costs O(months), not O(library).
  final TimelineAccumulator _timeline = TimelineAccumulator();

  /// Total library bytes, maintained incrementally per scan page.
  int get timelineTotalBytes => _timeline.totalBytes;

  /// Years present in the scanned library, newest first.
  List<int> get timelineYears => _timeline.years;

  /// Month summaries for [year] from the incremental
  /// accumulators — identical to [groupAssetsByMonth] over the
  /// full list (see the equivalence test).
  List<MonthSummary> monthsForYear(int year, {bool ascending = false}) =>
      _timeline.monthsForYear(year, ascending: ascending);

  // Phase 2B retention state (loaded in init, independent of the scan).
  final RxList<DeckSession> sessions = <DeckSession>[].obs;
  final RxMap<String, DateTime> snoozes = <String, DateTime>{}.obs;
  final RxDouble goalTargetMb = defaultGoalMb.obs;
  final RxList<HistoryRecord> history = <HistoryRecord>[].obs;
  final RxList<TrashEntry> trashEntries = <TrashEntry>[].obs;
  final RxList<DateTime> completionDays = <DateTime>[].obs;
  final Rx<double?> freeMb = Rx<double?>(null);

  final List<MediaAsset> _allAssets = <MediaAsset>[];

  /// Phase 3B incremental scan state (see the file doc): the by-id
  /// map, per-deck byte totals, delete-marked ids (from retention,
  /// loaded before the scan) and the marked-bytes total, all built
  /// per page instead of recomputed per rebuild.
  final Map<String, MediaAsset> _assetsById = <String, MediaAsset>{};
  final Map<SmartDeckId, int> _deckBytes = <SmartDeckId, int>{};
  final Set<String> _deleteMarkedIds = <String>{};
  double _markedBytes = 0;
  bool _markedAccumulated = false;

  /// 0-1 progress, or null when the library total is unknown.
  double? get progress {
    final int? total = estimatedTotal.value;
    if (total == null || total <= 0) {
      return null;
    }
    return (scanned.value / total).clamp(0, 1).toDouble();
  }

  bool get isScanning => status.value == DecksStatus.scanning;

  List<MediaAsset> assetsFor(SmartDeckId id) {
    return deckAssets[id] ?? <MediaAsset>[];
  }

  int totalBytesFor(SmartDeckId id) {
    // Phase 3B: the scan keeps this total incrementally; the fold
    // is only a fallback for deck lists set without a scan (tests).
    final int? cached = _deckBytes[id];
    if (cached != null) {
      return cached;
    }
    return assetsFor(id).fold<int>(0, (int sum, MediaAsset a) {
      return sum + a.sizeBytes;
    });
  }

  // ---- Phase 2B retention getters (pure math in retention.dart) ----

  /// MB freed this calendar week, from history only (never trashed).
  double get weekFreedMbValue => weekFreedMb(history, DateTime.now());

  /// 0–1 goal progress, clamped; 1.0 once the target is met.
  double get goalProgress {
    final double target = goalTargetMb.value;
    if (target <= 0) {
      return 0;
    }
    return (weekFreedMbValue / target).clamp(0, 1).toDouble();
  }

  /// Streak over completion days + history-record days.
  StreakResult get streak {
    final List<DateTime> days = <DateTime>[
      ...completionDays,
      for (final HistoryRecord record in history) record.date,
    ];
    return computeStreak(days, DateTime.now());
  }

  /// MB currently in Trash (recoverable, never freed).
  double get inTrashMb {
    int bytes = 0;
    for (final TrashEntry entry in trashEntries) {
      bytes += entry.sizeBytes;
    }
    return bytes / 1048576;
  }

  /// MB marked delete across all saved sessions, for assets still
  /// in the scanned library ("to be freed", never freed).
  /// Phase 3B: accumulated per scan page (see [_scan]); the loop
  /// below is only the pre-scan fallback, when nothing is scanned.
  double get markedMb {
    if (_markedAccumulated) {
      return _markedBytes / 1048576;
    }
    int bytes = 0;
    for (final DeckSession session in sessions) {
      for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
        if (mark.value == DeckMark.delete) {
          bytes += _assetsById[mark.key]?.sizeBytes ?? 0;
        }
      }
    }
    return bytes / 1048576;
  }

  /// Projected device free storage after emptying Trash, or null
  /// when device free storage is unknown (library fallback then).
  double? get projectedFreeMbValue {
    final double? free = freeMb.value;
    if (free == null) {
      return null;
    }
    return projectedFreeMb(free, inTrashMb);
  }

  /// Maybe pile: every Maybe mark in every saved session whose
  /// asset is still in the scanned library, with its snooze state.
  /// Reads reactive state so an Obx rebuilds as pages arrive.
  List<MaybePileItem> get maybeItems {
    // Reactive reads (sessions, snoozes, scanned) so Obx tracks them.
    final List<DeckSession> allSessions = sessions.toList();
    final Map<String, DateTime> allSnoozes = Map<String, DateTime>.of(snoozes);
    final int scannedCount = scanned.value;
    if (scannedCount == 0 && _allAssets.isEmpty) {
      return <MaybePileItem>[];
    }
    // Phase 3B: _assetsById is built per scan page, so this getter
    // costs O(user Maybe marks), not O(library), per rebuild.
    return maybeItemsFor(allSessions, allSnoozes, _assetsById);
  }

  /// List-level decks (bursts, duplicates) are ready only when the
  /// scan completes; the rest are ready as soon as pages arrive.
  bool deckReady(SmartDeckId id) {
    if (id == SmartDeckId.bursts || id == SmartDeckId.duplicates) {
      return scanComplete.value;
    }
    return scanned.value > 0 || scanComplete.value;
  }

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Loads retention data (sessions, snoozes, goal, history, Trash
  /// records, completion days, device free storage). Failures leave
  /// defaults in place — the hub still works, the projection just
  /// falls back to library figures.
  Future<void> loadRetention() async {
    final Result<List<DeckSession>> sessionsResult = await local.listSessions();
    sessionsResult.fold(onSuccess: sessions.assignAll, onFailure: (_) {});
    // Phase 3B: the delete-marked id set for incremental marked
    // bytes during the scan (sessions load before the scan runs).
    _deleteMarkedIds.clear();
    for (final DeckSession session in sessions) {
      for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
        if (mark.value == DeckMark.delete) {
          _deleteMarkedIds.add(mark.key);
        }
      }
    }
    final Result<Map<String, DateTime>> snoozesResult = await local
        .loadSnoozes();
    snoozesResult.fold(onSuccess: snoozes.assignAll, onFailure: (_) {});
    final Result<double> goalResult = await local.loadGoalTargetMb();
    goalResult.fold(onSuccess: goalTargetMb.call, onFailure: (_) {});
    final Result<List<HistoryRecord>> historyResult = await local.loadHistory();
    historyResult.fold(onSuccess: history.assignAll, onFailure: (_) {});
    final Result<List<TrashEntry>> trashResult = await local.loadTrashEntries();
    trashResult.fold(onSuccess: trashEntries.assignAll, onFailure: (_) {});
    final Result<List<DateTime>> completionsResult = await local
        .loadCompletionDays();
    completionsResult.fold(
      onSuccess: completionDays.assignAll,
      onFailure: (_) {},
    );
    final StorageService? backend = storage;
    if (backend != null) {
      final Result<double> freeResult = await backend.getFreeMb();
      freeResult.fold(
        onSuccess: (double value) => freeMb.value = value,
        onFailure: (_) => freeMb.value = null,
      );
    }
  }

  /// Snoozes [item]'s asset for [days] from today. The session mark
  /// stays Maybe — only the snooze record changes.
  Future<void> snoozeItem(MaybePileItem item, int days) async {
    final DateTime until = snoozeUntilFor(days, DateTime.now());
    final Result<void> result = await local.setSnooze(item.asset.id, until);
    result.fold(
      onSuccess: (_) => snoozes[item.asset.id] = until,
      onFailure: (_) {},
    );
  }

  /// Clears [item]'s snooze. The asset stays Maybe (unsnoozed) and
  /// returns to its deck as undecided only via the normal flow —
  /// clearing a snooze does not itself unmark anything.
  Future<void> clearSnoozeItem(MaybePileItem item) async {
    final Result<void> result = await local.setSnooze(item.asset.id, null);
    result.fold(
      onSuccess: (_) => snoozes.remove(item.asset.id),
      onFailure: (_) {},
    );
  }

  /// Saves a new weekly goal target (one of the presets).
  Future<void> setGoal(double mb) async {
    final Result<void> result = await local.saveGoalTargetMb(mb);
    result.fold(onSuccess: (_) => goalTargetMb.value = mb, onFailure: (_) {});
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
    status.value = DecksStatus.scanning;
    await loadRetention();
    await _scan();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    super.onClose();
  }

  Future<void> retry() async {
    await init();
  }

  /// Phase 3B: opens this app's system Settings page (the denied
  /// state's second action — a permanently denied grant makes the
  /// system prompt a no-op). Re-check on return via retry.
  Future<void> openPermissionSettings() async {
    await media.openAppSettings();
  }

  Future<void> _scan() async {
    // Phase 4.2: reset scan accumulation first — resubscribing
    // replays past pages, so stale state would double-count.
    _allAssets.clear();
    _assetsById.clear();
    _deckBytes.clear();
    _markedBytes = 0;
    deckAssets.clear();
    analyses.clear();
    scanned.value = 0;
    estimatedTotal.value = null;
    scanComplete.value = false;
    // Phase 4.3: reset the incremental timeline state with it.
    _timeline.clear();

    final DateTime now = DateTime.now();
    _markedAccumulated = true;
    // Phase 3B: deck lists accumulate here per page (one assignment
    // per deck per page, not one list copy per asset per deck).
    final Map<SmartDeckId, List<MediaAsset>> accumulated =
        <SmartDeckId, List<MediaAsset>>{};
    // Phase 4.2: pages now carry ONLY fresh analyses, so seed the
    // cumulative map from the cache first (snapshot-served since
    // 4.1, so this costs no fresh decode). Deck membership below
    // then resolves cached and fresh assets alike.
    final Result<Map<String, PhotoAnalysis>> cached = await local
        .loadAnalyses();
    cached.fold(onSuccess: analyses.addAll, onFailure: (_) {});
    _scanSubscription?.cancel();
    _scanSubscription = _scans.subscribe(
      onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> fresh) {
        _allAssets.addAll(page);
        analyses.addAll(fresh);
        for (final MediaAsset asset in page) {
          _assetsById[asset.id] = asset;
          // Phase 4.3: incremental timeline state, per asset.
          _timeline.add(asset);
          if (_deleteMarkedIds.contains(asset.id)) {
            _markedBytes += asset.sizeBytes;
          }
          for (final SmartDeckId id in decksForAsset(asset, analyses, now)) {
            final List<MediaAsset> list = accumulated[id] ??= <MediaAsset>[];
            list.add(asset);
            _deckBytes[id] = (_deckBytes[id] ?? 0) + asset.sizeBytes;
            deckAssets[id] = list;
          }
        }
        scanned.value = _allAssets.length;
      },
      onProgress: (int count, int? total) {
        scanned.value = count;
        estimatedTotal.value = total;
      },
    );
    final LibraryScan result = await _scans.start();
    if (result.cancelled) {
      // Externally cancelled while awaiting: never present partial
      // data as ready. The controller is going away or will
      // re-init; leave status untouched.
      return;
    }
    scanComplete.value = true;
    // List-level decks resolve only over the full list.
    final Set<String> burstIds = burstAssetIds(_allAssets);
    _setDeck(
      SmartDeckId.bursts,
      _allAssets.where((MediaAsset a) => burstIds.contains(a.id)).toList(),
    );
    final List<DuplicateGroup> groups = groupAssets(
      assets: _allAssets,
      analyses: result.analyses,
      threshold: duplicatesThreshold,
    );
    _setDeck(SmartDeckId.duplicates, <MediaAsset>[
      for (final DuplicateGroup group in groups) ...group.assets,
    ]);
    if (result.pageFailed && _allAssets.isEmpty) {
      status.value = DecksStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    status.value = DecksStatus.ready;
  }

  /// Assigns a fully computed deck list with its byte total
  /// (list-level decks: bursts, duplicates — see [_scan]).
  void _setDeck(SmartDeckId id, List<MediaAsset> assets) {
    deckAssets[id] = assets;
    _deckBytes[id] = assets.fold<int>(
      0,
      (int sum, MediaAsset asset) => sum + asset.sizeBytes,
    );
  }

  /// Opens a deck: duplicates go to their own screen; every other
  /// deck opens as a swipe deck with its precomputed assets.
  void openDeck(SmartDeckId id) {
    if (id == SmartDeckId.duplicates) {
      Get.toNamed<dynamic>(AppRoutes.duplicates);
      return;
    }
    Get.toNamed<dynamic>(
      AppRoutes.smartDeck,
      arguments: SmartDeckLaunch(deckId: id, assets: assetsFor(id)),
    );
  }

  List<MediaAsset> get allAssets => _allAssets;
  final RxInt selectedYear = DateTime.now().year.obs;
  final RxBool timelineAscending = false.obs;
  void openMonth(String monthKey) {
    final List<MediaAsset> monthAssets = _allAssets
        .where(
          (MediaAsset a) =>
              '${a.createDate.year}-${a.createDate.month.toString().padLeft(2, '0')}' ==
              monthKey,
        )
        .toList();
    Get.toNamed<dynamic>(
      AppRoutes.smartDeck,
      arguments: SmartDeckLaunch(deckId: null, assets: monthAssets),
    );
  }
}
