// On-device persistence: deck sessions, deletion history, the
// tutorial flag and the Trash record.
//
// Interface only. No account, no backend, no cloud (requirements
// §5/§9). Nothing stored here contains photo content — only asset
// ids, marks, counts, sizes and dates. The implementation keeps
// JSON files in the app documents directory.

import '../../core/utils/result.dart';
import '../detection/photo_analysis.dart';
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

/// Theme choice (Phase 3A). Default is [system]: following the OS
/// is the least surprising default — a user who never opens Settings
/// gets the theme their phone already uses, and a user who picks
/// Light or Dark gets exactly that, on every launch.
enum ThemePreference { system, light, dark }

/// The persisted settings record (Phase 3A), stored in the same
/// `klara_settings.json` file as the goal target and tutorial flag.
/// New keys merge into existing records: old records simply read as
/// defaults for the keys they lack, and saving settings never drops
/// the goal/tutorial keys (the implementation reads the whole map
/// first, then writes it back).
///
/// Defaults, and why:
/// - theme system (above); privateBlur OFF — blurring by default
///   would hide exactly what the user must judge before a restore
///   or delete, so wrong decisions would be more likely, not less.
/// - protection OFF — protection changes delete behaviour, so it
///   must be an explicit user choice, never a surprise.
/// - weeklyNudge OFF — no notification is scheduled until the user
///   asks for one. haptics ON (design.md §8 feedback is the norm).
/// - reducedMotion OFF — the system setting applies until the user
///   overrides it in-app. trashAutoEmptyPrompt OFF — see the
///   trust-rule resolution on [AppSettings.trashAutoEmptyPrompt].
class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.privateBlur = false,
    this.protection = false,
    this.weeklyNudge = false,
    this.haptics = true,
    this.reducedMotion = false,
    this.trashAutoEmptyPrompt = false,
  });

  final ThemePreference theme;
  final bool privateBlur;
  final bool protection;
  final bool weeklyNudge;
  final bool haptics;
  final bool reducedMotion;

  /// TRUST-RULE RESOLUTION (requirements §4 wins): "never
  /// auto-delete" overrides any literal auto-empty reading of the
  /// Phase 3 settings list. When ON, this setting NEVER silently
  /// deletes media. It only (a) prompts (in-app dialog, then the
  /// native sheet) to empty trash when records pass their
  /// recoverableUntil date, and (b) allows record-only cleanup of
  /// expired records — dropping stale local records whose system
  /// media already expired, which deletes no media at all. When
  /// OFF, expired records are left for manual emptying.
  final bool trashAutoEmptyPrompt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'theme': theme.name,
      'privateBlur': privateBlur,
      'protection': protection,
      'weeklyNudge': weeklyNudge,
      'haptics': haptics,
      'reducedMotion': reducedMotion,
      'trashAutoEmptyPrompt': trashAutoEmptyPrompt,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) {
      final Object? value = json[key];
      return value is bool ? value : fallback;
    }

    final Object? themeRaw = json['theme'];
    final ThemePreference theme = themeRaw is String
        ? ThemePreference.values.firstWhere(
            (ThemePreference t) => t.name == themeRaw,
            orElse: () => ThemePreference.system,
          )
        : ThemePreference.system;
    return AppSettings(
      theme: theme,
      privateBlur: flag('privateBlur', false),
      protection: flag('protection', false),
      weeklyNudge: flag('weeklyNudge', false),
      haptics: flag('haptics', true),
      reducedMotion: flag('reducedMotion', false),
      trashAutoEmptyPrompt: flag('trashAutoEmptyPrompt', false),
    );
  }

  AppSettings copyWith({
    ThemePreference? theme,
    bool? privateBlur,
    bool? protection,
    bool? weeklyNudge,
    bool? haptics,
    bool? reducedMotion,
    bool? trashAutoEmptyPrompt,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      privateBlur: privateBlur ?? this.privateBlur,
      protection: protection ?? this.protection,
      weeklyNudge: weeklyNudge ?? this.weeklyNudge,
      haptics: haptics ?? this.haptics,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      trashAutoEmptyPrompt: trashAutoEmptyPrompt ?? this.trashAutoEmptyPrompt,
    );
  }
}

abstract class LocalService {
  /// Saves (overwrites) the session for its filter key.
  Future<Result<void>> saveSession(DeckSession session);

  /// Loads the session for [filterKey], or null when none exists.
  Future<Result<DeckSession?>> loadSession(String filterKey);

  /// Every saved session, in no guaranteed order. The Maybe pile
  /// (Phase 2B) gathers maybe-marked assets from these sessions.
  Future<Result<List<DeckSession>>> listSessions();

  /// Snooze-until dates by asset id (Phase 2B retention). A snooze
  /// is set explicitly from the Maybe pile only — marking Maybe
  /// alone never snoozes. The stored date is the return date
  /// (date-only): the asset is snoozed while today is before it.
  Future<Result<Map<String, DateTime>>> loadSnoozes();

  /// Sets the snooze-until date for [assetId], or clears it when
  /// [until] is null. The date is normalised to date-only.
  Future<Result<void>> setSnooze(String assetId, DateTime? until);

  /// Clears the snoozes for [ids] in a single read-modify-write
  /// (solutions 4.1: snooze expiry batches instead of one write
  /// per cleared id). Default loops [setSnooze] so test fakes
  /// need not change; the real implementation batches.
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    for (final String id in ids) {
      final Result<void> result = await setSnooze(id, null);
      if (result is Failure<void>) {
        return result;
      }
    }
    return const Success<void>(null);
  }

  /// Flushes any coalesced writes (solutions 4.1: session saves
  /// flush at most every ~1.5 s or ~20 marks, AND synchronously
  /// on go-to-review, on filter change, on app-paused, and on
  /// dispose). A no-op for fakes and for implementations without
  /// coalescing; never throws — a failed flush keeps the data
  /// dirty for the next flush instead of losing it.
  Future<void> flushPendingWrites() async {}

  /// Weekly freed-space goal target in MB (Phase 2B retention).
  /// Defaults to 1024 MB when nothing was saved yet.
  Future<Result<double>> loadGoalTargetMb();

  /// Saves the weekly goal target in MB.
  Future<Result<void>> saveGoalTargetMb(double mb);

  /// Days (date-only) on which a deck session was completed
  /// (Phase 2B streaks). One entry per day, never duplicated.
  Future<Result<List<DateTime>>> loadCompletionDays();

  /// Records [day] (normalised to date-only) as a completed day.
  /// Idempotent: recording the same day twice stores it once.
  Future<Result<void>> recordCompletionDay(DateTime day);

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

  /// The persisted settings record (Phase 3A). Missing records
  /// read as [AppSettings] defaults; saving merges into the
  /// existing settings file without dropping other keys.
  ///
  /// Default bodies (fresh-install settings, no persistence) exist
  /// so test fakes that implement this interface need not change:
  /// protection OFF, blur OFF, theme system, haptics ON. The real
  /// implementation ([LocalServiceImpl]) overrides both with JSON
  /// persistence, and any test that must observe a saved setting
  /// uses that implementation with a temp directory.
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  /// Saves the whole settings record (see [loadSettings]).
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }

  /// Merges [analyses] into the on-device hash cache, keyed by
  /// asset id. Cached hashes/scores make regrouping instant and
  /// re-scans cheap: only uncached assets need a thumbnail.
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses);

  /// The whole hash cache (asset id -> analysis), or empty when
  /// nothing has been scanned yet.
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses();

  /// Removes cached analyses whose asset id is NOT in [liveIds]
  /// and returns how many were removed (solutions 5.3). Called
  /// only after a fully completed scan — never after a cancelled
  /// or page-failed one, where unseen assets must not be mistaken
  /// for deleted. Writes only when something was actually removed,
  /// so a scan with no deletions pays no rewrite. A failure
  /// returns [Failure] and the caller keeps the old cache: the
  /// next full scan retries.
  Future<Result<int>> pruneAnalyses(Set<String> liveIds);
}
