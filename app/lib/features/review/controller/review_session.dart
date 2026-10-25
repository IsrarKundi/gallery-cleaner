// Phase 4 extraction from [ReviewController] (which sits at its
// ~400-line budget): the session-mark write shared by unmark,
// keep-all, delete, denied handling and the document-guard keep.
//
// Loads the deck session for [filterKey], applies [updates]
// (null removes a mark), and saves it back preserving the stored
// index and favourites. Returns false when the session could not
// be read or written, so callers keep the photo in place instead
// of silently dropping it.

import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';

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
