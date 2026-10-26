// Trash, restore and empty-trash, through the Android native sheet.
//
// Interface only. The implementation routes every destructive step
// through MediaStore's system confirmation sheet (requirements §4):
// no swipe, no review tap and no service call ever deletes silently.
//
// Outcome semantics (requirements §5):
// * succeeded ids — the user confirmed and the system applied it.
// * denied ids — the user dismissed/denied the native sheet. The
//   caller MUST return these photos to the deck with an explanation;
//   they are never silently dropped from the queue.
// * failed ids — the asset could not even be reached (gone already,
//   unresolvable id). These are errors, not denials.

import '../../core/utils/result.dart';
import 'trash_entry.dart';

/// Outcome of a trash request: ids the system trashed, ids the user
/// declined at the native sheet, and ids that could not be reached.
class TrashOutcome {
  const TrashOutcome({
    required this.trashedIds,
    required this.deniedIds,
    required this.failedIds,
  });

  final List<String> trashedIds;
  final List<String> deniedIds;
  final List<String> failedIds;
}

/// Outcome of a restore request, with the same three-way split.
class RestoreOutcome {
  const RestoreOutcome({
    required this.restoredIds,
    required this.deniedIds,
    required this.failedIds,
  });

  final List<String> restoredIds;
  final List<String> deniedIds;
  final List<String> failedIds;
}

/// Outcome of emptying Trash: ids removed, ids the user declined at
/// the native sheet, and ids that could not be reached.
class EmptyTrashOutcome {
  const EmptyTrashOutcome({
    required this.removedIds,
    required this.deniedIds,
    required this.failedIds,
  });

  final List<String> removedIds;
  final List<String> deniedIds;
  final List<String> failedIds;
}

/// Outcome of a permanent delete request: ids the system deleted,
/// ids the user declined at the native sheet, and ids that could
/// not be reached.
class DeleteOutcome {
  const DeleteOutcome({
    required this.deletedIds,
    required this.deniedIds,
    required this.failedIds,
  });

  final List<String> deletedIds;
  final List<String> deniedIds;
  final List<String> failedIds;
}

abstract class TrashService {
  /// Moves [ids] to the system Trash via the native confirmation
  /// sheet. Records a [TrashEntry] for every trashed id so
  /// [listTrashed] can show it later.
  Future<Result<TrashOutcome>> trashAssets(List<String> ids);

  /// Restores [ids] from Trash (single or multi) via the native
  /// confirmation sheet. Restored entries leave the Trash record.
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids);

  /// Trash contents, newest first, from Klara's Trash record.
  /// The system Trash itself cannot be queried (trashed assets are
  /// hidden from MediaStore), so this is the recorded list.
  Future<Result<List<TrashEntry>>> listTrashed();

  /// Removes everything in Trash via the native confirmation sheet.
  ///
  /// The CALLER must first show Klara's own in-app confirmation;
  /// this service then routes through the native sheet and never
  /// deletes silently. Denied ids stay in Trash. Only after this
  /// completes may the caller count the space as freed — never while
  /// assets sit in Trash. Requires Android 11 (API 30+); below that
  /// it fails with [AppStrings.errorTrashUnsupported] instead of
  /// deleting through any silent path.
  Future<Result<EmptyTrashOutcome>> emptyTrash();

  /// Permanently deletes [ids] via the native confirmation sheet
  /// (MediaStore.createDeleteRequest on API 30+). Never enters Trash.
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids);
}
