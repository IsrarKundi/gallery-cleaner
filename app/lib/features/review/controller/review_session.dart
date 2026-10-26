// Phase 4 extraction from [ReviewController] (which sits at its
// ~400-line budget): the session-mark write shared by unmark,
// keep-all, keep-selected, delete and denied handling.
//
// Loads the deck session for [filterKey], applies [updates]
// (null removes a mark), and saves it back preserving the stored
// index and favourites. Returns false when the session could not
// be read or written, so callers keep the photo in place instead
// of silently dropping it.

import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';

/// Loads delete-marked assets from the saved session for [filterKey]
/// and looks up their [MediaAsset] records. Used when the review screen
/// is opened from the bottom navigation bar without route arguments.
Future<List<MediaAsset>> loadDeleteMarkedAssets({
  required LocalService local,
  required MediaService media,
  required String filterKey,
}) async {
  final Result<DeckSession?> loaded = await local.loadSession(filterKey);
  final DeckSession? session = loaded.fold(
    onSuccess: (DeckSession? value) => value,
    onFailure: (_) => null,
  );
  if (session == null || session.marks.isEmpty) {
    return <MediaAsset>[];
  }
  final Set<String> deleteIds = session.marks.entries
      .where((MapEntry<String, DeckMark> e) => e.value == DeckMark.delete)
      .map((MapEntry<String, DeckMark> e) => e.key)
      .toSet();
  if (deleteIds.isEmpty) {
    return <MediaAsset>[];
  }
  final Result<List<MediaAsset>> assetsResult = await media.getAssetsByIds(
    deleteIds.toList(),
  );
  return assetsResult.fold(
    onSuccess: (List<MediaAsset> assets) => assets,
    onFailure: (_) => <MediaAsset>[],
  );
}

Future<bool> updateSessionMarks({
  required LocalService local,
  required String filterKey,
  required Map<String, DeckMark?> updates,
}) async {
  final Result<DeckSession?> loaded = await local.loadSession(filterKey);
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
      filterKey: filterKey,
      currentIndex: session?.currentIndex ?? 0,
      marks: marks,
      favouriteIds: Set<String>.of(session?.favouriteIds ?? <String>{}),
    ),
  );
  return saved.isSuccess;
}
