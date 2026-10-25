// One smart deck as a swipe deck (requirements §7, Phase 2).
//
// WHY A THIN CONTROLLER INSTEAD OF EXTENDING DeckController: the
// main deck controller is paging/filter-bound and already near its
// line budget, while a smart deck arrives with a precomputed asset
// list. This controller therefore owns only queue/marks/undo/
// session/resume for that list — the swipe/drag behaviour itself is
// NOT duplicated: the view renders the deck's own SwipeCard and
// DeckActionBar widgets with the locked gesture mapping, and marks
// write to the same LocalService session mechanism under the key
// `smart:<deck>` so resume works and delete marks flow to /review
// exactly like main-deck marks (same arguments + filterKey
// contract). Thumbnails load for the current card + next 3 only,
// the same window the main deck preloads.
//
// The controller never deletes: marks only, review + native
// confirmation still own removal (requirements §4).

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/deferred_action.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../deck/controller/deck_protection.dart';
import '../../deck/controller/deck_retention.dart';
import '../../deck/model/retention.dart';
import '../model/smart_deck_launch.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/thumbnail/thumbnail_service_impl.dart';

class SmartDeckController extends GetxController {
  SmartDeckController({
    required this.media,
    required this.local,
    this.initialLaunch,
    ThumbnailService? thumbnailService,
  }) : _thumbnails = thumbnailService ?? ThumbnailServiceImpl(media: media);

  final MediaService media;
  final LocalService local;
  final SmartDeckLaunch? initialLaunch;

  /// Phase 2.3: bytes live in the shared thumbnail service.
  final ThumbnailService _thumbnails;

  /// Phase 2B retention glue, shared with the main deck controller
  /// (summary, snooze expiry, completion days). No share backend:
  /// smart-deck finishes show counts without a share button.
  late final DeckRetention retention = DeckRetention(local: local);

  /// Thumbnail edge for swipe cards, matching the deck's preload size
  /// (solutions 3.1: deck-card surface, capped at 1080 px).
  static const int thumbnailSize = 1080;

  /// Cards preloaded ahead of the current card (current + next 3).
  static const int preloadAhead = 3;

  final RxBool ready = false.obs;
  final RxList<MediaAsset> queue = <MediaAsset>[].obs;
  final RxMap<String, DeckMark> marks = <String, DeckMark>{}.obs;
  final RxSet<String> favouriteIds = <String>{}.obs;
  final RxInt currentIndex = 0.obs;
  final RxList<String> undoStack = <String>[].obs;

  /// Phase 2.3: service-owned bytes / failures for the deck size.
  /// Views read through these getters unchanged.
  RxMap<String, Uint8List> get thumbnails =>
      _thumbnails.thumbnailsFor(thumbnailSize);
  RxSet<String> get failedThumbnails => _thumbnails.failedFor(thumbnailSize);

  /// Phase 3A favourites protection (see DeckProtection).
  final DeckProtection protection = DeckProtection();

  SmartDeckLaunch? _launch;
  String _sessionKey = 'smart:unknown';

  SmartDeckId? get deckId => _launch?.deckId;

  MediaAsset? get currentAsset {
    final int index = currentIndex.value;
    if (index < 0 || index >= queue.length) {
      return null;
    }
    return queue[index];
  }

  bool get isFinished =>
      ready.value && queue.isNotEmpty && currentIndex.value >= queue.length;

  bool get canUndo => undoStack.isNotEmpty;

  List<MediaAsset> get deleteMarkedAssets {
    return queue
        .where((MediaAsset asset) => marks[asset.id] == DeckMark.delete)
        .toList();
  }

  /// Finished-session summary (Phase 2B): same counts as the main
  /// deck, shown without a share button (see SmartDeckView).
  SessionSummary get summary => retention.summarize(marks, queue);

  @override
  void onInit() {
    super.onInit();
    _launch = initialLaunch ?? _routeLaunch();
    if (_launch != null) {
      _sessionKey = _launch!.sessionKey;
      queue.assignAll(_launch!.assets);
    }
    _init();
  }

  SmartDeckLaunch? _routeLaunch() {
    try {
      final dynamic args = Get.arguments;
      if (args is SmartDeckLaunch) {
        return args;
      }
    } catch (_) {
      // No route in this context; the constructor launch wins.
    }
    return null;
  }

  Future<void> _init() async {
    final Result<DeckSession?> sessionResult = await local.loadSession(
      _sessionKey,
    );
    DeckSession? session;
    sessionResult.fold(
      onSuccess: (DeckSession? value) => session = value,
      onFailure: (_) {},
    );
    if (await retention.restoreSession(marks, favouriteIds, session)) {
      _persist();
    }
    // Phase 3A protection, same contract as the main deck.
    await protection.load(local);
    currentIndex.value = _firstUndecidedIndex();
    ready.value = true;
    _preloadAround(currentIndex.value);
  }

  int _firstUndecidedIndex() {
    for (int i = 0; i < queue.length; i++) {
      if (!marks.containsKey(queue[i].id)) {
        return i;
      }
    }
    return queue.length;
  }

  void markCurrent(DeckMark mark) {
    final MediaAsset? asset = currentAsset;
    if (asset == null || !ready.value) {
      return;
    }
    // Phase 2.5, same rule as the main deck: never mark a card
    // whose thumbnail is not visible (still loading or failed).
    if (!thumbnails.containsKey(asset.id) ||
        failedThumbnails.contains(asset.id)) {
      return;
    }
    // Phase 3A: protected photos can never be marked delete here
    // either — same block + explanation as the main deck.
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
    _preloadAround(currentIndex.value);
    _persist();
    AppHaptics.mark();
    // Phase 2B streak day, same contract as the main deck.
    if (isFinished) {
      retention.recordCompletion();
    }
  }

  /// Phase 2.5 explicit retry for a failed current card: clears
  /// the failed mark and re-fetches the window (same contract as
  /// the main deck's retry).
  void retryCurrentThumbnail() {
    final MediaAsset? asset = currentAsset;
    if (asset == null) {
      return;
    }
    _thumbnails.retry(asset.id, thumbnailSize);
    _preloadAround(currentIndex.value);
  }

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
    _preloadAround(currentIndex.value);
    _persist();
  }

  /// Phase 3.2 settled-review gate (same contract as the main
  /// deck's): review navigation requested while a card exit is in
  /// flight defers until the flight ends.
  final DeferredAction _reviewGate = DeferredAction();

  /// True while a card exit animation is in flight.
  bool get isCardExiting => _reviewGate.isBusy;

  /// Called by the view from the card's exit callbacks.
  void setCardExiting(bool exiting) => _reviewGate.setBusy(exiting);

  void goToReview() => _reviewGate.run(_goToReviewNow);

  void _goToReviewNow() {
    Get.toNamed<dynamic>(
      AppRoutes.review,
      arguments: deleteMarkedAssets,
      parameters: <String, String>{'filterKey': _sessionKey},
    );
  }

  void _preloadAround(int start) {
    final List<String> ids = <String>[
      for (int i = start; i < queue.length && i <= start + preloadAhead; i++)
        queue[i].id,
    ];
    _thumbnails.prefetch(ids, thumbnailSize);
    _thumbnails.cancelOutside(<ThumbnailKey>{
      for (final String id in ids) (id: id, size: thumbnailSize, quality: 85),
    });
  }

  void _persist() {
    local.saveSession(
      DeckSession(
        filterKey: _sessionKey,
        currentIndex: currentIndex.value,
        marks: Map<String, DeckMark>.of(marks),
        favouriteIds: Set<String>.of(favouriteIds),
      ),
    );
  }
}
