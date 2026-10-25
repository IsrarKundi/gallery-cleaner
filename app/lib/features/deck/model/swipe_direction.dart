import '../../../services/local/local_service.dart';

/// Pure drag-to-mark mapping for the locked gestures (requirements §3):
/// left = Keep, right = Delete, up = Maybe, down = Favourite.
///
/// The dominant axis wins; a drag shorter than [threshold] in both
/// axes is not a swipe and maps to null (the card springs back).
/// This is the single place the mapping lives for swipe input; buttons
/// pass their mark directly, so a mapping change touches this file.
DeckMark? markForDrag(double dx, double dy, double threshold) {
  if (dx.abs() < threshold && dy.abs() < threshold) {
    return null;
  }
  if (dx.abs() >= dy.abs()) {
    return dx < 0 ? DeckMark.keep : DeckMark.delete;
  }
  return dy < 0 ? DeckMark.maybe : DeckMark.favourite;
}
