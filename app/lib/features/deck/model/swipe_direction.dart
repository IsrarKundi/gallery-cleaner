import '../../../services/local/local_service.dart';

/// Pure drag-to-mark mapping for deck swipes (requirements §3 amendment 27 Oct 2026).
///
/// Default mapping is Right = Keep, Left = Delete ([SwipeDirections.rightKeepLeftDelete]).
/// If [directions] is [SwipeDirections.rightDeleteLeftKeep], Right = Delete, Left = Keep.
/// Vertical swipes are disabled (no Maybe or Favourite gesture via swipe).
///
/// A horizontal drag shorter than [threshold] or a drag that is predominantly
/// vertical (dx.abs() < dy.abs()) is not a swipe and maps to null (the card springs back).
DeckMark? markForDrag(
  double dx,
  double dy,
  double threshold, {
  SwipeDirections directions = SwipeDirections.rightKeepLeftDelete,
}) {
  if (dx.abs() < threshold || dx.abs() < dy.abs()) {
    return null;
  }
  final bool isRight = dx > 0;
  final bool rightIsKeep = directions == SwipeDirections.rightKeepLeftDelete;
  if (isRight) {
    return rightIsKeep ? DeckMark.keep : DeckMark.delete;
  } else {
    return rightIsKeep ? DeckMark.delete : DeckMark.keep;
  }
}
