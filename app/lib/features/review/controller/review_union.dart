// Union set and per-origin sync for Review (requirements §4).
//
// The Trash tab shows the union of Clean deck deletes (pending +
// awaiting) plus every smart deck's delete-marked photos. Actions
// in Review (unmark, keep, permanent delete, denied delete) sync
// back to the deck and persisted session each photo came from,
// never corrupting per-deck sessions into a single key.

import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../deck/controller/deck_controller.dart';
import '../../decks/controller/smart_deck_controller.dart';
import 'review_session.dart';

/// Route arguments and in-memory payload for Review: the photos
/// and a mapping of asset id -> origin deck session key.
class ReviewLaunch {
  const ReviewLaunch({
    required this.assets,
    this.originSessionKeys = const <String, String>{},
  });

  final List<MediaAsset> assets;
  final Map<String, String> originSessionKeys;
}

/// Gathers the union of delete-marked photos across Clean deck and
/// all smart decks.
///
/// Order:
/// 1. Clean deck deletes (awaiting then queued, newest swipe last).
/// 2. Smart deck deletes, sorted stably by deck session key (alphabetical),
///    with newest swipe last within each deck.
Future<ReviewLaunch> buildReviewUnion({
  required LocalService local,
  required MediaService media,
  DeckController? deck,
  SmartDeckController? liveSmartDeck,
}) async {
  final List<MediaAsset> unionAssets = <MediaAsset>[];
  final Map<String, String> originSessionKeys = <String, String>{};
  final Set<String> seenIds = <String>{};

  // 1. Clean deck deletes
  final String cleanKey = deck?.filter.value.filterKey ?? 'all';
  List<MediaAsset> cleanAssets = deck?.deleteMarkedAssets ?? <MediaAsset>[];
  if (cleanAssets.isEmpty && deck == null) {
    cleanAssets = await loadDeleteMarkedAssets(
      local: local,
      media: media,
      filterKey: cleanKey,
    );
  }
  for (final MediaAsset asset in cleanAssets) {
    if (seenIds.add(asset.id)) {
      unionAssets.add(asset);
      originSessionKeys[asset.id] = cleanKey;
    }
  }

  // 2. Smart deck deletes
  final SmartDeckController? liveSmart =
      liveSmartDeck ??
      (Get.isRegistered<SmartDeckController>()
          ? Get.find<SmartDeckController>()
          : null);
  final String? liveSmartKey = liveSmart?.sessionKey;
  final List<MediaAsset> liveSmartAssets =
      liveSmart?.deleteMarkedAssets ?? <MediaAsset>[];

  final Result<List<DeckSession>> sessionsResult = await local.listSessions();
  final List<DeckSession> allSessions = sessionsResult.fold(
    onSuccess: (List<DeckSession> list) => list,
    onFailure: (_) => <DeckSession>[],
  );

  final List<DeckSession> smartSessions =
      allSessions
          .where((DeckSession s) => s.filterKey.startsWith('smart:'))
          .toList()
        ..sort(
          (DeckSession a, DeckSession b) => a.filterKey.compareTo(b.filterKey),
        );

  final Set<String> processedSmartKeys = <String>{};

  for (final DeckSession session in smartSessions) {
    processedSmartKeys.add(session.filterKey);
    if (liveSmart != null && session.filterKey == liveSmartKey) {
      for (final MediaAsset asset in liveSmartAssets) {
        if (seenIds.add(asset.id)) {
          unionAssets.add(asset);
          originSessionKeys[asset.id] = session.filterKey;
        }
      }
    } else {
      final List<String> deleteIds = session.marks.entries
          .where((MapEntry<String, DeckMark> e) => e.value == DeckMark.delete)
          .map((MapEntry<String, DeckMark> e) => e.key)
          .toList();
      if (deleteIds.isNotEmpty) {
        final Result<List<MediaAsset>> fetched = await media.getAssetsByIds(
          deleteIds,
        );
        final List<MediaAsset> assets = fetched.fold(
          onSuccess: (List<MediaAsset> list) => list,
          onFailure: (_) => <MediaAsset>[],
        );
        final Map<String, MediaAsset> byId = <String, MediaAsset>{
          for (final MediaAsset a in assets) a.id: a,
        };
        for (final String id in deleteIds) {
          final MediaAsset? asset = byId[id];
          if (asset != null && seenIds.add(asset.id)) {
            unionAssets.add(asset);
            originSessionKeys[asset.id] = session.filterKey;
          }
        }
      }
    }
  }

  // If liveSmart is active and its session isn't in smartSessions yet
  if (liveSmart != null &&
      liveSmartKey != null &&
      !processedSmartKeys.contains(liveSmartKey)) {
    for (final MediaAsset asset in liveSmartAssets) {
      if (seenIds.add(asset.id)) {
        unionAssets.add(asset);
        originSessionKeys[asset.id] = liveSmartKey;
      }
    }
  }

  return ReviewLaunch(
    assets: unionAssets,
    originSessionKeys: originSessionKeys,
  );
}

/// Syncs an unmark action back to the origin session and controller.
Future<bool> syncReviewUnmark({
  required LocalService local,
  required MediaAsset asset,
  required String sessionKey,
}) async {
  final bool saved = await updateSessionMarks(
    local: local,
    filterKey: sessionKey,
    updates: <String, DeckMark?>{asset.id: null},
  );
  if (!saved) {
    return false;
  }
  if (sessionKey.startsWith('smart:')) {
    if (Get.isRegistered<SmartDeckController>()) {
      final SmartDeckController smart = Get.find<SmartDeckController>();
      if (smart.sessionKey == sessionKey) {
        smart.unmarkAsset(asset.id);
      }
    }
  } else {
    if (Get.isRegistered<DeckController>()) {
      Get.find<DeckController>().cancelAwaiting(asset);
    }
  }
  return true;
}

/// Syncs kept assets back to their origin sessions and controllers.
Future<bool> syncReviewKept({
  required LocalService local,
  required Iterable<MediaAsset> assets,
  required Map<String, String> originSessionKeys,
  required String defaultFilterKey,
}) async {
  final Map<String, List<String>> bySession = <String, List<String>>{};
  for (final MediaAsset a in assets) {
    final String key = originSessionKeys[a.id] ?? defaultFilterKey;
    bySession.putIfAbsent(key, () => <String>[]).add(a.id);
  }

  bool allSaved = true;
  for (final MapEntry<String, List<String>> entry in bySession.entries) {
    final String sessionKey = entry.key;
    final List<String> ids = entry.value;
    final bool saved = await updateSessionMarks(
      local: local,
      filterKey: sessionKey,
      updates: <String, DeckMark?>{
        for (final String id in ids) id: DeckMark.keep,
      },
    );
    if (!saved) {
      allSaved = false;
    }
    if (sessionKey.startsWith('smart:')) {
      if (Get.isRegistered<SmartDeckController>()) {
        final SmartDeckController smart = Get.find<SmartDeckController>();
        if (smart.sessionKey == sessionKey) {
          smart.markAssetsKept(ids);
        }
      }
    } else {
      if (Get.isRegistered<DeckController>()) {
        Get.find<DeckController>().markAssetsKept(ids);
      }
    }
  }
  return allSaved;
}

/// Syncs permanently deleted assets back to their origin sessions and controllers.
Future<void> syncReviewDeleted({
  required LocalService local,
  required Iterable<String> deletedIds,
  required Map<String, String> originSessionKeys,
  required String defaultFilterKey,
}) async {
  final Map<String, List<String>> bySession = <String, List<String>>{};
  for (final String id in deletedIds) {
    final String key = originSessionKeys[id] ?? defaultFilterKey;
    bySession.putIfAbsent(key, () => <String>[]).add(id);
  }

  for (final MapEntry<String, List<String>> entry in bySession.entries) {
    final String sessionKey = entry.key;
    final List<String> ids = entry.value;
    await updateSessionMarks(
      local: local,
      filterKey: sessionKey,
      updates: <String, DeckMark?>{for (final String id in ids) id: null},
    );
    if (sessionKey.startsWith('smart:')) {
      if (Get.isRegistered<SmartDeckController>()) {
        final SmartDeckController smart = Get.find<SmartDeckController>();
        if (smart.sessionKey == sessionKey) {
          smart.removeTrashedAssets(ids);
        }
      }
    } else {
      if (Get.isRegistered<DeckController>()) {
        Get.find<DeckController>().removeTrashedAssets(ids);
      }
    }
  }
}

/// Syncs denied assets back to their origin sessions and controllers.
Future<void> syncReviewDenied({
  required LocalService local,
  required Iterable<String> deniedIds,
  required Map<String, String> originSessionKeys,
  required String defaultFilterKey,
}) async {
  final Map<String, List<String>> bySession = <String, List<String>>{};
  for (final String id in deniedIds) {
    final String key = originSessionKeys[id] ?? defaultFilterKey;
    bySession.putIfAbsent(key, () => <String>[]).add(id);
  }

  for (final MapEntry<String, List<String>> entry in bySession.entries) {
    final String sessionKey = entry.key;
    final List<String> ids = entry.value;
    await updateSessionMarks(
      local: local,
      filterKey: sessionKey,
      updates: <String, DeckMark?>{for (final String id in ids) id: null},
    );
    if (sessionKey.startsWith('smart:')) {
      if (Get.isRegistered<SmartDeckController>()) {
        final SmartDeckController smart = Get.find<SmartDeckController>();
        if (smart.sessionKey == sessionKey) {
          smart.handleDeniedTrash(ids);
        }
      }
    } else {
      if (Get.isRegistered<DeckController>()) {
        Get.find<DeckController>().handleDeniedTrash(ids);
      }
    }
  }
}
