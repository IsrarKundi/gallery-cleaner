// On-device persistence: deck sessions, deletion history, the
// tutorial flag and the Trash record.
//
// Interface only. No account, no backend, no cloud (requirements
// §5/§9). Nothing stored here contains photo content — only asset
// ids, marks, counts, sizes and dates. The implementation keeps
// JSON files in the app documents directory.

import '../../core/utils/result.dart';
import '../trash/trash_entry.dart';

/// One swipe mark. Matches the locked gesture mapping
/// (requirements §3): left = keep, right = delete, up = maybe,
/// down = favourite. A swipe only marks; nothing here deletes.
enum DeckMark { keep, delete, maybe, favourite }

/// A resumable deck session, keyed by the deck's filter
/// (e.g. `all`, an album id, or `month:2026-10`).
class DeckSession {
  const DeckSession({
    required this.filterKey,
    required this.currentIndex,
    required this.marks,
    required this.favouriteIds,
  });

  final String filterKey;

  /// Index of the next unreviewed asset when the session resumes.
  final int currentIndex;

  /// assetId -> mark, for every asset swiped so far in this session.
  final Map<String, DeckMark> marks;

  /// assetIds favourited (protected) in this session.
  final Set<String> favouriteIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filterKey': filterKey,
      'currentIndex': currentIndex,
      'marks': marks.map(
        (String id, DeckMark mark) => MapEntry<String, String>(id, mark.name),
      ),
      'favouriteIds': favouriteIds.toList(),
    };
  }

  factory DeckSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawMarks =
        (json['marks'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, DeckMark> marks = <String, DeckMark>{};
    for (final MapEntry<String, dynamic> entry in rawMarks.entries) {
      final String name = entry.value as String;
      marks[entry.key] = DeckMark.values.firstWhere(
        (DeckMark m) => m.name == name,
        orElse: () => DeckMark.keep,
      );
    }
    return DeckSession(
      filterKey: json['filterKey'] as String,
      currentIndex: json['currentIndex'] as int,
      marks: marks,
      favouriteIds: <String>{
        for (final Object? id
            in json['favouriteIds'] as List<dynamic>? ?? <dynamic>[])
          id as String,
      },
    );
  }
}

/// One completed cleaning record: what a trash or empty run did.
/// MB figures are for the history screen only; trashed MB is never
/// presented as freed (requirements §4).
class HistoryRecord {
  const HistoryRecord({
    required this.date,
    required this.count,
    required this.mbTrashed,
    required this.mbFreed,
  });

  /// Day the run completed.
  final DateTime date;

  /// Number of photos in the run.
  final int count;

  /// MB moved to Trash by the run (0 for an empty-trash run).
  final double mbTrashed;

  /// MB removed by emptying Trash (0 for a trash run).
  final double mbFreed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'count': count,
      'mbTrashed': mbTrashed,
      'mbFreed': mbFreed,
    };
  }

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int,
      mbTrashed: (json['mbTrashed'] as num).toDouble(),
      mbFreed: (json['mbFreed'] as num).toDouble(),
    );
  }
}

abstract class LocalService {
  /// Saves (overwrites) the session for its filter key.
  Future<Result<void>> saveSession(DeckSession session);

  /// Loads the session for [filterKey], or null when none exists.
  Future<Result<DeckSession?>> loadSession(String filterKey);

  /// Appends [entry] to the recorded Trash list.
  Future<Result<void>> recordTrashed(List<TrashEntry> entries);

  /// Recorded Trash entries, newest first.
  Future<Result<List<TrashEntry>>> loadTrashEntries();

  /// Drops [ids] from the recorded Trash list (after a restore or
  /// a confirmed emptying).
  Future<Result<void>> removeTrashEntries(List<String> ids);

  /// Clears the whole recorded Trash list.
  Future<Result<void>> clearTrashEntries();

  /// Appends one deletion-history record.
  Future<Result<void>> appendHistory(HistoryRecord record);

  /// History records, newest first.
  Future<Result<List<HistoryRecord>>> loadHistory();

  /// Whether the first-run swipe tutorial has been shown.
  Future<Result<bool>> isTutorialSeen();

  /// Marks the first-run swipe tutorial as shown (or resets it).
  Future<Result<void>> setTutorialSeen(bool seen);
}
