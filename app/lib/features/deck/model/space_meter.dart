import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/trash/trash_entry.dart';
import '../../../services/trash/trash_service.dart';
import '../../../core/utils/result.dart';

/// Three-state space totals for the deck meter (requirements §4,
/// design.md §7). Pure: no service calls, no state.
///
/// - Marked: size of assets currently marked delete ("to be freed").
///   Only assets still present in the loaded queue count; a mark for
///   an asset no longer in the library contributes nothing.
/// - In Trash: size of recorded Trash entries ("recoverable until
///   [earliest date]"). NEVER counted as freed.
/// - Freed: sum of `mbFreed` from deletion-history records only.
///   Emptying Trash or expiry are the only paths that free space.
class SpaceMeterTotals {
  const SpaceMeterTotals({
    required this.markedBytes,
    required this.inTrashBytes,
    required this.freedBytes,
    required this.recoverableUntil,
  });

  final int markedBytes;
  final int inTrashBytes;
  final int freedBytes;

  /// Earliest recoverable-until date across Trash entries, or null
  /// when Trash is empty (the meter then shows the plain "In trash"
  /// label with no date).
  final DateTime? recoverableUntil;

  double get markedMb => markedBytes / 1048576;
  double get inTrashMb => inTrashBytes / 1048576;
  double get freedMb => freedBytes / 1048576;
}

/// Computes the three-state totals from the deck's current marks, the
/// loaded queue (as an id map), recorded Trash entries and history.
SpaceMeterTotals computeSpaceMeter({
  required Map<String, DeckMark> marks,
  required Map<String, MediaAsset> assetsById,
  required List<TrashEntry> trashEntries,
  required List<HistoryRecord> history,
}) {
  int markedBytes = 0;
  for (final MapEntry<String, DeckMark> entry in marks.entries) {
    if (entry.value == DeckMark.delete) {
      markedBytes += assetsById[entry.key]?.sizeBytes ?? 0;
    }
  }
  int inTrashBytes = 0;
  DateTime? earliest;
  for (final TrashEntry entry in trashEntries) {
    inTrashBytes += entry.sizeBytes;
    final DateTime until = entry.recoverableUntil;
    if (earliest == null || until.isBefore(earliest)) {
      earliest = until;
    }
  }
  double freedMb = 0;
  for (final HistoryRecord record in history) {
    freedMb += record.mbFreed;
  }
  return SpaceMeterTotals(
    markedBytes: markedBytes,
    inTrashBytes: inTrashBytes,
    freedBytes: (freedMb * 1048576).round(),
    recoverableUntil: earliest,
  );
}

/// Owns the deck meter's service calls: loading its Trash/history
/// inputs and computing totals from the current marks + queue.
/// The controller keeps the reactive lists; this class keeps the
/// controller under its line budget without changing behaviour.
class DeckMeter {
  DeckMeter({required this.trash, required this.local});

  final TrashService trash;
  final LocalService local;

  SpaceMeterTotals compute(
    Map<String, DeckMark> marks,
    List<MediaAsset> queue,
    List<TrashEntry> trashEntries,
    List<HistoryRecord> history,
  ) {
    return computeSpaceMeter(
      marks: marks,
      assetsById: <String, MediaAsset>{
        for (final MediaAsset asset in queue) asset.id: asset,
      },
      trashEntries: trashEntries,
      history: history,
    );
  }

  /// Reloads Trash records and history for the meter. Failures
  /// leave the previous totals in place rather than erroring
  /// the deck.
  Future<void> refresh(
    RxList<TrashEntry> trashEntries,
    RxList<HistoryRecord> history,
  ) async {
    final Result<List<TrashEntry>> trashResult = await trash.listTrashed();
    trashResult.fold(onSuccess: trashEntries.assignAll, onFailure: (_) {});
    final Result<List<HistoryRecord>> historyResult = await local.loadHistory();
    historyResult.fold(onSuccess: history.assignAll, onFailure: (_) {});
  }
}
