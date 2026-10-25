import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';

/// Index of the first asset in [queue] with no mark in [marks], or
/// [queue.length] when every loaded asset is decided. Pure helper
/// so the deck controller stays under its line budget; the deck
/// resumes at this index after a session load, an undo, and a
/// denied-confirmation rewind (requirements §5).
int firstUndecidedIndex(List<MediaAsset> queue, Map<String, DeckMark> marks) {
  for (int i = 0; i < queue.length; i++) {
    if (!marks.containsKey(queue[i].id)) {
      return i;
    }
  }
  return queue.length;
}
