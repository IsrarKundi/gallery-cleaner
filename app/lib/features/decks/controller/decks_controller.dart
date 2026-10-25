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

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/photo_analysis.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/storage/storage_service.dart';
import '../../../services/trash/trash_entry.dart';
import '../../deck/model/retention.dart';
import '../model/decks_status.dart';
import '../model/maybe_pile_item.dart';
import '../model/smart_deck_launch.dart';

class DecksController extends GetxController {
  DecksController({required this.media, required this.local, this.storage});

  final MediaService media;
  final LocalService local;

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

  // Phase 2B retention state (loaded in init, independent of the scan).
  final RxList<DeckSession> sessions = <DeckSession>[].obs;
  final RxMap<String, DateTime> snoozes = <String, DateTime>{}.obs;
  final RxDouble goalTargetMb = defaultGoalMb.obs;
  final RxList<HistoryRecord> history = <HistoryRecord>[].obs;
  final RxList<TrashEntry> trashEntries = <TrashEntry>[].obs;
  final RxList<DateTime> completionDays = <DateTime>[].obs;
  final Rx<double?> freeMb = Rx<double?>(null);

  final List<MediaAsset> _allAssets = <MediaAsset>[];

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
  double get markedMb {
    final Map<String, MediaAsset> byId = <String, MediaAsset>{
      for (final MediaAsset asset in _allAssets) asset.id: asset,
    };
    int bytes = 0;
    for (final DeckSession session in sessions) {
      for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
        if (mark.value == DeckMark.delete) {
          bytes += byId[mark.key]?.sizeBytes ?? 0;
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
    final Map<String, MediaAsset> byId = <String, MediaAsset>{
      for (final MediaAsset asset in _allAssets) asset.id: asset,
    };
    final List<MaybePileItem> items = <MaybePileItem>[];
    for (final DeckSession session in allSessions) {
      for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
        if (mark.value != DeckMark.maybe) {
          continue;
        }
        final MediaAsset? asset = byId[mark.key];
        if (asset == null) {
          continue;
        }
        items.add(
          MaybePileItem(
            asset: asset,
            sessionKey: session.filterKey,
            snoozeUntil: allSnoozes[mark.key],
          ),
        );
      }
    }
    return items;
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

  Future<void> retry() async {
    _allAssets.clear();
    deckAssets.clear();
    analyses.clear();
    scanned.value = 0;
    estimatedTotal.value = null;
    scanComplete.value = false;
    await init();
  }

  Future<void> _scan() async {
    final DateTime now = DateTime.now();
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> found) {
        _allAssets.addAll(page);
        analyses.assignAll(found);
        for (final MediaAsset asset in page) {
          for (final SmartDeckId id in decksForAsset(asset, found, now)) {
            deckAssets[id] = <MediaAsset>[...assetsFor(id), asset];
          }
        }
        scanned.value = _allAssets.length;
      },
      onProgress: (int count, int? total) {
        scanned.value = count;
        estimatedTotal.value = total;
      },
    );
    scanComplete.value = true;
    // List-level decks resolve only over the full list.
    final Set<String> burstIds = burstAssetIds(_allAssets);
    deckAssets[SmartDeckId.bursts] = _allAssets
        .where((MediaAsset a) => burstIds.contains(a.id))
        .toList();
    final List<DuplicateGroup> groups = groupAssets(
      assets: _allAssets,
      analyses: result.analyses,
      threshold: duplicatesThreshold,
    );
    deckAssets[SmartDeckId.duplicates] = <MediaAsset>[
      for (final DuplicateGroup group in groups) ...group.assets,
    ];
    if (result.pageFailed && _allAssets.isEmpty) {
      status.value = DecksStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    status.value = DecksStatus.ready;
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
}
