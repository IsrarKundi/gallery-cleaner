import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';

/// Phase 3B helpers for [DeckController], extracted so the
/// controller stays under its ~400-line budget.
///
/// - [expandPartialAccess]: the honest Android 14 recovery path.
///   `presentLimitedSelection` shows the system picker so the user
///   can ADD photos to a limited grant; it cannot grant full access
///   (only system Settings can — see [openPermissionSettings]).
///   Returns the permission state after the picker dismisses, so the
///   caller can reload the queue against the new grant.
/// - [openPermissionSettings]: opens this app's system Settings page
///   (the only place "Allow all photos" lives). No result callback
///   exists, so the caller re-checks via "Add more photos" on return.
/// - [rewindDenied]: the denied-confirmation rewind (requirements
///   §5), shared logic for [DeckController.clearDeleteMarks]:
///   denied photos lose their delete mark and their undo entry, so
///   the deck re-shows them as undecided instead of dropping them.
/// - [undo]: pops the last decision from [undoStack], clears its
///   mark (and favourite flag), and returns the queue index to
///   return to, or null when the stack is empty.
class DeckAccess {
  DeckAccess({required this.media});

  final MediaService media;

  Future<MediaPermission?> expandPartialAccess() async {
    final Result<void> presented = await media.presentLimitedSelection();
    if (presented.isFailure) {
      return null;
    }
    final Result<MediaPermission> permission = await media.requestPermission();
    return permission.fold(
      onSuccess: (MediaPermission value) => value,
      onFailure: (_) => null,
    );
  }

  Future<void> openPermissionSettings() async {
    await media.openAppSettings();
  }

  /// Removes delete marks for [ids] from [marks] and [undoStack].
  /// Returns true when anything changed (the caller then rewinds
  /// the queue index and persists). Ids with any other mark, or no
  /// mark, are untouched.
  bool rewindDenied(
    RxMap<String, DeckMark> marks,
    RxList<String> undoStack,
    List<String> ids,
  ) {
    bool changed = false;
    for (final String id in ids) {
      if (marks[id] == DeckMark.delete) {
        marks.remove(id);
        undoStack.remove(id);
        changed = true;
      }
    }
    return changed;
  }

  /// Pops the last decision. Returns the queue index of the popped
  /// asset, or -1 when it is no longer in the queue (the caller
  /// then falls back to the first undecided index), or null when
  /// there is nothing to undo.
  int? undo(
    RxMap<String, DeckMark> marks,
    RxSet<String> favouriteIds,
    RxList<String> undoStack,
    List<MediaAsset> queue,
  ) {
    if (undoStack.isEmpty) {
      return null;
    }
    final String id = undoStack.removeLast();
    final bool wasFavourite = marks[id] == DeckMark.favourite;
    marks.remove(id);
    if (wasFavourite) {
      favouriteIds.remove(id);
    }
    return queue.indexWhere((MediaAsset asset) => asset.id == id);
  }
}
