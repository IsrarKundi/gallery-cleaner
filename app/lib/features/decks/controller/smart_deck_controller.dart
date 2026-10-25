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
import '../../../core/utils/result.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/smart_deck_launch.dart';

class SmartDeckController extends GetxController {
  SmartDeckController({
    required this.media,
    required this.local,
    this.initialLaunch,
  });

  final MediaService media;
  final LocalService local;
  final SmartDeckLaunch? initialLaunch;

  /// Thumbnail edge for swipe cards, matching the deck's preload size.
  static const int thumbnailSize = 512;

  /// Cards preloaded ahead of the current card (current + next 3).
  static const int preloadAhead = 3;

  final RxBool ready = false.obs;
  final RxList<MediaAsset> queue = <MediaAsset>[].obs;
  final RxMap<String, DeckMark> marks = <String, DeckMark>{}.obs;
  final RxSet<String> favouriteIds = <String>{}.obs;
  final RxInt currentIndex = 0.obs;
  final RxList<String> undoStack = <String>[].obs;
  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxSet<String> failedThumbnails = <String>{}.obs;

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
    sessionResult.fold(
      onSuccess: (DeckSession? session) {
        if (session != null) {
          marks.assignAll(session.marks);
          favouriteIds.assignAll(session.favouriteIds);
        }
      },
      onFailure: (_) {},
    );
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

  void goToReview() {
    Get.toNamed<dynamic>(
      AppRoutes.review,
      arguments: deleteMarkedAssets,
      parameters: <String, String>{'filterKey': _sessionKey},
    );
  }

  void _preloadAround(int start) {
    for (int i = start; i < queue.length && i <= start + preloadAhead; i++) {
      _loadThumbnail(queue[i].id);
    }
  }

  Future<void> _loadThumbnail(String id) async {
    if (thumbnails.containsKey(id) || failedThumbnails.contains(id)) {
      return;
    }
    final Result<Uint8List> result = await media.getThumbnail(
      id,
      thumbnailSize,
    );
    result.fold(
      onSuccess: (Uint8List bytes) => thumbnails[id] = bytes,
      onFailure: (_) => failedThumbnails.add(id),
    );
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
