// JSON-file implementation of [LocalService], via per-file
// [JsonFileStore]s (solutions 4.1).
//
// Storage choice: plain JSON files in the app documents directory
// (via path_provider), one file per data kind. Chosen over
// shared_preferences because it has fewer moving parts for this
// shape of data: sessions and history are lists/maps, not scalar
// prefs; JSON files keep them inspectable, versionable and trivial
// to round-trip in tests. No new backend, no account, no sync.
//
// The documents directory is injectable ([directoryResolver]) so
// unit tests pass a temp directory and never touch platform
// channels. Production uses path_provider's documents directory.
// This is the ONLY local file importing path_provider.
//
// What Phase 4.1 changed vs the old direct file IO (see
// [JsonFileStore] for the mechanics): loads serve the in-memory
// snapshot after the first decode; session saves coalesce
// (~1.5 s / 20 marks) and flush at the mandatory points
// (go-to-review, filter change, app-paused, dispose — the callers
// drive [flushPendingWrites]); every other write is immediate;
// all writes are serialised and atomic; bad entries are salvaged
// per entry instead of failing the whole file. Nothing stored here
// contains photo content — only asset ids, marks, counts, sizes
// and dates.

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../detection/photo_analysis.dart';
import '../trash/trash_entry.dart';
import 'json_file_store.dart';
import 'local_service.dart';

class LocalServiceImpl implements LocalService {
  LocalServiceImpl({DirectoryResolver? directoryResolver})
    : _directoryResolver =
          directoryResolver ?? getApplicationDocumentsDirectory {
    _sessions = JsonFileStore(fileName: _sessionsFile, directoryResolver: _dir);
    _trash = JsonFileStore(fileName: _trashFile, directoryResolver: _dir);
    _history = JsonFileStore(fileName: _historyFile, directoryResolver: _dir);
    _settings = JsonFileStore(fileName: _settingsFile, directoryResolver: _dir);
    _analyses = JsonFileStore(fileName: _analysesFile, directoryResolver: _dir);
    _snoozes = JsonFileStore(fileName: _snoozesFile, directoryResolver: _dir);
    _completions = JsonFileStore(
      fileName: _completionsFile,
      directoryResolver: _dir,
    );
  }

  final DirectoryResolver _directoryResolver;

  /// Phase 1.4: the resolved documents directory, cached after the
  /// first resolution. Concurrent first callers share the single
  /// in-flight resolution; a failed resolution is dropped so a
  /// later call retries instead of replaying the same error.
  Future<Directory>? _dirFuture;

  static const String _sessionsFile = 'klara_sessions.json';
  static const String _trashFile = 'klara_trash.json';
  static const String _historyFile = 'klara_history.json';
  static const String _settingsFile = 'klara_settings.json';
  static const String _analysesFile = 'klara_analyses.json';
  static const String _snoozesFile = 'klara_snoozes.json';
  static const String _completionsFile = 'klara_completions.json';

  /// Default weekly goal target (Phase 2B): 1 GB freed per week.
  static const double defaultGoalTargetMb = 1024;

  late final JsonFileStore _sessions;
  late final JsonFileStore _trash;
  late final JsonFileStore _history;
  late final JsonFileStore _settings;
  late final JsonFileStore _analyses;
  late final JsonFileStore _snoozes;
  late final JsonFileStore _completions;

  /// Bad entries skipped per file (cumulative): per-entry parse
  /// failures counted here plus brace-scan fragments counted by
  /// the store. Test observability for the salvage contract.
  final Map<String, int> _entrySkips = <String, int>{};

  /// Bad entries salvaged per file (see [_entrySkips]).
  Map<String, int> get salvageReport {
    final Map<JsonFileStore, String> names = <JsonFileStore, String>{
      _sessions: _sessionsFile,
      _trash: _trashFile,
      _history: _historyFile,
      _settings: _settingsFile,
      _analyses: _analysesFile,
      _snoozes: _snoozesFile,
      _completions: _completionsFile,
    };
    return <String, int>{
      for (final MapEntry<JsonFileStore, String> e in names.entries)
        e.value: (_entrySkips[e.value] ?? 0) + e.key.salvageSkipped,
    };
  }

  /// Atomic disk writes performed per file (test observability
  /// for the write-amplification benchmark).
  Map<String, int> get diskWriteCounts {
    return <String, int>{
      _sessionsFile: _sessions.diskWrites,
      _trashFile: _trash.diskWrites,
      _historyFile: _history.diskWrites,
      _settingsFile: _settings.diskWrites,
      _analysesFile: _analyses.diskWrites,
      _snoozesFile: _snoozes.diskWrites,
      _completionsFile: _completions.diskWrites,
    };
  }

  Future<Directory> _dir() {
    final Future<Directory>? cached = _dirFuture;
    if (cached != null) {
      return cached;
    }
    final Future<Directory> pending = _resolveDir();
    _dirFuture = pending;
    unawaited(
      pending.then<void>(
        (_) {},
        onError: (_) {
          if (identical(_dirFuture, pending)) {
            _dirFuture = null;
          }
        },
      ),
    );
    return pending;
  }

  Future<Directory> _resolveDir() async {
    final Directory dir = await _directoryResolver();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  AppFailure get _failure =>
      const AppFailure(messageKey: AppStrings.errorLocal);

  void _noteSkipped(String file) {
    _entrySkips[file] = (_entrySkips[file] ?? 0) + 1;
  }

  /// Parses one entry, skipping (and counting) bad entries instead
  /// of failing the whole file (solutions 4.1 salvage).
  T? _parseEntry<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
    String file,
  ) {
    try {
      if (raw is! Map<String, dynamic>) {
        _noteSkipped(file);
        return null;
      }
      return fromJson(raw);
    } catch (_) {
      _noteSkipped(file);
      return null;
    }
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    try {
      final Map<String, dynamic> all = await _sessions.readMap();
      all[session.filterKey] = session.toJson();
      // Coalesced: the snapshot holds it immediately, so a load
      // right after this save sees it; the disk write follows
      // within the window or at the next flush point.
      _sessions.scheduleWrite();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    try {
      final Map<String, dynamic> all = await _sessions.readMap();
      final Object? raw = all[filterKey];
      if (raw == null) {
        return const Success<DeckSession?>(null);
      }
      return Success<DeckSession?>(
        _parseEntry<DeckSession>(raw, DeckSession.fromJson, _sessionsFile),
      );
    } catch (_) {
      return Failure<DeckSession?>(_failure);
    }
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    try {
      final Map<String, dynamic> all = await _sessions.readMap();
      final List<DeckSession> sessions = <DeckSession>[];
      for (final Object? raw in all.values) {
        final DeckSession? session = _parseEntry<DeckSession>(
          raw,
          DeckSession.fromJson,
          _sessionsFile,
        );
        if (session != null) {
          sessions.add(session);
        }
      }
      return Success<List<DeckSession>>(sessions);
    } catch (_) {
      return Failure<List<DeckSession>>(_failure);
    }
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    try {
      final Map<String, dynamic> all = await _snoozes.readMap();
      final Map<String, DateTime> snoozes = <String, DateTime>{};
      for (final MapEntry<String, dynamic> entry in all.entries) {
        try {
          snoozes[entry.key] = DateTime.parse(entry.value as String);
        } catch (_) {
          _noteSkipped(_snoozesFile);
        }
      }
      return Success<Map<String, DateTime>>(snoozes);
    } catch (_) {
      return Failure<Map<String, DateTime>>(_failure);
    }
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    try {
      final Map<String, dynamic> all = await _snoozes.readMap();
      if (until == null) {
        all.remove(assetId);
      } else {
        final DateTime day = DateTime(until.year, until.month, until.day);
        all[assetId] = day.toIso8601String();
      }
      await _snoozes.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    try {
      final Map<String, dynamic> all = await _snoozes.readMap();
      bool removed = false;
      for (final String id in ids) {
        removed = all.remove(id) != null || removed;
      }
      // One read-modify-write for the whole batch (solutions 4.1);
      // no write at all when nothing was actually present.
      if (removed) {
        await _snoozes.writeNow();
      }
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    try {
      final Map<String, dynamic> settings = await _settings.readMap();
      final Object? raw = settings['goalTargetMb'];
      if (raw is num) {
        return Success<double>(raw.toDouble());
      }
      return const Success<double>(defaultGoalTargetMb);
    } catch (_) {
      return Failure<double>(_failure);
    }
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    try {
      final Map<String, dynamic> settings = await _settings.readMap();
      settings['goalTargetMb'] = mb;
      await _settings.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    try {
      final List<dynamic> raw = await _completions.readList();
      final List<DateTime> days = <DateTime>[];
      for (final Object? item in raw) {
        try {
          days.add(DateTime.parse(item as String));
        } catch (_) {
          _noteSkipped(_completionsFile);
        }
      }
      days.sort();
      return Success<List<DateTime>>(days);
    } catch (_) {
      return Failure<List<DateTime>>(_failure);
    }
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    try {
      final List<dynamic> raw = await _completions.readList();
      // Drop corrupt entries from the snapshot before sorting:
      // loads already skip them, so this only makes the next
      // write self-healing instead of failing on a mixed sort.
      raw.retainWhere((Object? item) => item is String);
      final DateTime only = DateTime(day.year, day.month, day.day);
      final String encoded = only.toIso8601String();
      if (raw.contains(encoded)) {
        return const Success<void>(null);
      }
      raw.add(encoded);
      raw.sort();
      await _completions.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    try {
      final List<dynamic> raw = await _trash.readList();
      for (final TrashEntry entry in entries) {
        raw.add(entry.toJson());
      }
      // Trash is the only record of trashed assets: immediate,
      // never coalesced (solutions 4.1).
      await _trash.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    try {
      final List<dynamic> raw = await _trash.readList();
      final List<TrashEntry> entries = <TrashEntry>[];
      for (final Object? item in raw) {
        final TrashEntry? entry = _parseEntry<TrashEntry>(
          item,
          TrashEntry.fromJson,
          _trashFile,
        );
        if (entry != null) {
          entries.add(entry);
        }
      }
      entries.sort(
        (TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt),
      );
      return Success<List<TrashEntry>>(entries);
    } catch (_) {
      return Failure<List<TrashEntry>>(_failure);
    }
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    try {
      final List<dynamic> raw = await _trash.readList();
      final Set<String> drop = ids.toSet();
      raw.removeWhere(
        (Object? item) =>
            item is Map<String, dynamic> &&
            item['assetId'] is String &&
            drop.contains(item['assetId'] as String),
      );
      await _trash.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    try {
      final List<dynamic> raw = await _trash.readList();
      raw.clear();
      await _trash.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    try {
      final List<dynamic> raw = await _history.readList();
      raw.add(record.toJson());
      await _history.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    try {
      final List<dynamic> raw = await _history.readList();
      final List<HistoryRecord> records = <HistoryRecord>[];
      for (final Object? item in raw) {
        final HistoryRecord? record = _parseEntry<HistoryRecord>(
          item,
          HistoryRecord.fromJson,
          _historyFile,
        );
        if (record != null) {
          records.add(record);
        }
      }
      records.sort(
        (HistoryRecord a, HistoryRecord b) => b.date.compareTo(a.date),
      );
      return Success<List<HistoryRecord>>(records);
    } catch (_) {
      return Failure<List<HistoryRecord>>(_failure);
    }
  }

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    try {
      final Map<String, dynamic> all = await _analyses.readMap();
      for (final PhotoAnalysis analysis in analyses) {
        all[analysis.assetId] = analysis.toJson();
      }
      await _analyses.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    try {
      final Map<String, dynamic> all = await _analyses.readMap();
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
      for (final MapEntry<String, dynamic> entry in all.entries) {
        final PhotoAnalysis? analysis = _parseEntry<PhotoAnalysis>(
          entry.value,
          PhotoAnalysis.fromJson,
          _analysesFile,
        );
        if (analysis != null) {
          analyses[entry.key] = analysis;
        }
      }
      return Success<Map<String, PhotoAnalysis>>(analyses);
    } catch (_) {
      return Failure<Map<String, PhotoAnalysis>>(_failure);
    }
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    try {
      // Served from the shared settings snapshot after the first
      // load: protection reads no longer pay a fresh full decode
      // per delete run (solutions 4.1).
      final Map<String, dynamic> settings = await _settings.readMap();
      return Success<AppSettings>(AppSettings.fromJson(settings));
    } catch (_) {
      return Failure<AppSettings>(_failure);
    }
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    try {
      final Map<String, dynamic> all = await _settings.readMap();
      all.addAll(settings.toJson());
      await _settings.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    try {
      final Map<String, dynamic> settings = await _settings.readMap();
      return Success<bool>(settings['tutorialSeen'] as bool? ?? false);
    } catch (_) {
      return Failure<bool>(_failure);
    }
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    try {
      final Map<String, dynamic> settings = await _settings.readMap();
      settings['tutorialSeen'] = seen;
      await _settings.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<void> flushPendingWrites() async {
    await Future.wait<void>(<Future<void>>[
      _sessions.flush(),
      _trash.flush(),
      _history.flush(),
      _settings.flush(),
      _analyses.flush(),
      _snoozes.flush(),
      _completions.flush(),
    ]);
  }

  /// Flushes pending writes and stops coalescing timers. Call from
  /// test tearDown; production services live for the process
  /// lifetime and flush on app-pause instead.
  Future<void> dispose() async {
    await Future.wait<void>(<Future<void>>[
      _sessions.close(),
      _trash.close(),
      _history.close(),
      _settings.close(),
      _analyses.close(),
      _snoozes.close(),
      _completions.close(),
    ]);
  }
}
