import 'package:get/get.dart';

/// Selection state for the review grid (owner decision 26 Oct 2026):
/// photos are always shown revealed, and the user selects the ones
/// to act on instead of acting on the whole set every time.
///
/// Entered by long-pressing a tile (that tile starts selected) or
/// by the header's Select text button (nothing pre-selected).
/// While active, tile taps toggle selection instead of unmarking.
/// The mode ends when the selection empties or the back control
/// cancels it. The set itself is transient UI state — it never
/// persists and never survives leaving the screen.
class ReviewSelection {
  /// True while the grid is in selection mode.
  final RxBool mode = false.obs;

  /// Ids currently selected. Empty outside selection mode.
  final RxSet<String> ids = <String>{}.obs;

  bool get hasSelection => ids.isNotEmpty;

  bool isSelected(String id) => ids.contains(id);

  /// Header button entry: mode on, nothing pre-selected.
  void enter() {
    mode.value = true;
  }

  /// Long-press entry: mode on with this tile selected; in mode,
  /// a long-press toggles like a tap.
  void longPress(String id) {
    if (mode.value) {
      toggle(id);
      return;
    }
    mode.value = true;
    ids.add(id);
  }

  /// Toggles one tile; emptying the set ends the mode.
  void toggle(String id) {
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    if (ids.isEmpty) {
      mode.value = false;
    }
  }

  /// Selects every id in [allIds] (the header's Select-all step).
  void selectAll(Iterable<String> allIds) {
    mode.value = true;
    ids.addAll(allIds);
  }

  /// Back-control cancel: ends the mode and clears the set.
  /// Returns true when a mode was active (the caller should
  /// swallow the pop); false when there was nothing to cancel.
  bool cancel() {
    if (!mode.value) {
      return false;
    }
    mode.value = false;
    ids.clear();
    return true;
  }

  /// Drops ids that left the grid (unmarked, kept, trashed) and
  /// ends the mode when nothing remains selected.
  void sync(Iterable<String> liveIds) {
    final Set<String> live = liveIds.toSet();
    ids.retainAll(live);
    if (ids.isEmpty) {
      mode.value = false;
    }
  }

  /// Clears the mode and the set (used after an action consumed
  /// the selection, e.g. keep-all navigating away).
  void clear() {
    mode.value = false;
    ids.clear();
  }
}
