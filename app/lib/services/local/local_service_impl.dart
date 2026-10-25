// JSON-file implementation of [LocalService].
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../detection/photo_analysis.dart';
import '../trash/trash_entry.dart';
import 'local_service.dart';

/// Resolves the directory holding Klara's JSON files.
typedef DirectoryResolver = Future<Directory> Function();

class LocalServiceImpl implements LocalService {
  LocalServiceImpl({DirectoryResolver? directoryResolver})
    : _directoryResolver =
          directoryResolver ?? getApplicationDocumentsDirectory;

  final DirectoryResolver _directoryResolver;

  /// Phase 1.4: the resolved documents directory, cached after the
  /// first resolution. Every local operation previously paid its own
  /// platform-channel round-trip (issues file F-06); concurrent first
  /// callers share the single in-flight resolution.
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

  Future<Directory> _dir() {
    final Future<Directory>? cached = _dirFuture;
    if (cached != null) {
      return cached;
    }
    final Future<Directory> pending = _resolveDir();
    _dirFuture = pending;
    // A failed resolution must not poison the cache: drop it so a
    // later call retries instead of replaying the same error.
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

  Future<File> _file(String name) async {
    final Directory dir = await _dir();
    return File('${dir.path}/$name');
  }

  /// Reads a JSON list file; a missing file reads as empty.
  Future<List<dynamic>> _readList(String name) async {
    final File file = await _file(name);
    if (!await file.exists()) {
      return <dynamic>[];
    }
    final String text = await file.readAsString();
    if (text.trim().isEmpty) {
      return <dynamic>[];
    }
    final Object? decoded = jsonDecode(text);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected a JSON list');
    }
    return decoded;
  }

  /// Reads a JSON map file; a missing file reads as empty.
  Future<Map<String, dynamic>> _readMap(String name) async {
    final File file = await _file(name);
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final String text = await file.readAsString();
    if (text.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  Future<void> _write(String name, Object value) async {
    final File file = await _file(name);
    await file.writeAsString(jsonEncode(value));
  }

  AppFailure get _failure =>
      const AppFailure(messageKey: AppStrings.errorLocal);

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    try {
      final Map<String, dynamic> all = await _readMap(_sessionsFile);
      all[session.filterKey] = session.toJson();
      await _write(_sessionsFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    try {
      final Map<String, dynamic> all = await _readMap(_sessionsFile);
      final Object? raw = all[filterKey];
      if (raw == null) {
        return const Success<DeckSession?>(null);
      }
      return Success<DeckSession?>(
        DeckSession.fromJson(raw as Map<String, dynamic>),
      );
    } catch (_) {
      return Failure<DeckSession?>(_failure);
    }
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    try {
      final Map<String, dynamic> all = await _readMap(_sessionsFile);
      final List<DeckSession> sessions = <DeckSession>[];
      for (final Object? raw in all.values) {
        sessions.add(DeckSession.fromJson(raw as Map<String, dynamic>));
      }
      return Success<List<DeckSession>>(sessions);
    } catch (_) {
      return Failure<List<DeckSession>>(_failure);
    }
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    try {
      final Map<String, dynamic> all = await _readMap(_snoozesFile);
      final Map<String, DateTime> snoozes = <String, DateTime>{};
      for (final MapEntry<String, dynamic> entry in all.entries) {
        snoozes[entry.key] = DateTime.parse(entry.value as String);
      }
      return Success<Map<String, DateTime>>(snoozes);
    } catch (_) {
      return Failure<Map<String, DateTime>>(_failure);
    }
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    try {
      final Map<String, dynamic> all = await _readMap(_snoozesFile);
      if (until == null) {
        all.remove(assetId);
      } else {
        final DateTime day = DateTime(until.year, until.month, until.day);
        all[assetId] = day.toIso8601String();
      }
      await _write(_snoozesFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    try {
      final Map<String, dynamic> settings = await _readMap(_settingsFile);
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
      final Map<String, dynamic> settings = await _readMap(_settingsFile);
      settings['goalTargetMb'] = mb;
      await _write(_settingsFile, settings);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    try {
      final List<dynamic> raw = await _readList(_completionsFile);
      final List<DateTime> days = <DateTime>[
        for (final Object? item in raw) DateTime.parse(item as String),
      ];
      days.sort();
      return Success<List<DateTime>>(days);
    } catch (_) {
      return Failure<List<DateTime>>(_failure);
    }
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    try {
      final List<dynamic> raw = await _readList(_completionsFile);
      final Set<String> days = <String>{
        for (final Object? item in raw) item as String,
      };
      final DateTime only = DateTime(day.year, day.month, day.day);
      days.add(only.toIso8601String());
      final List<String> sorted = days.toList()..sort();
      await _write(_completionsFile, sorted);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    try {
      final List<dynamic> raw = await _readList(_trashFile);
      final List<Map<String, dynamic>> all = <Map<String, dynamic>>[
        for (final Object? item in raw) item as Map<String, dynamic>,
        for (final TrashEntry entry in entries) entry.toJson(),
      ];
      await _write(_trashFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    try {
      final List<dynamic> raw = await _readList(_trashFile);
      final List<TrashEntry> entries = <TrashEntry>[
        for (final Object? item in raw)
          TrashEntry.fromJson(item as Map<String, dynamic>),
      ];
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
      final List<dynamic> raw = await _readList(_trashFile);
      final Set<String> drop = ids.toSet();
      final List<Map<String, dynamic>> kept = <Map<String, dynamic>>[];
      for (final Object? item in raw) {
        final Map<String, dynamic> json = item as Map<String, dynamic>;
        if (!drop.contains(json['assetId'] as String)) {
          kept.add(json);
        }
      }
      await _write(_trashFile, kept);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    try {
      await _write(_trashFile, <dynamic>[]);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    try {
      final List<dynamic> raw = await _readList(_historyFile);
      final List<Map<String, dynamic>> all = <Map<String, dynamic>>[
        for (final Object? item in raw) item as Map<String, dynamic>,
        record.toJson(),
      ];
      await _write(_historyFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    try {
      final List<dynamic> raw = await _readList(_historyFile);
      final List<HistoryRecord> records = <HistoryRecord>[
        for (final Object? item in raw)
          HistoryRecord.fromJson(item as Map<String, dynamic>),
      ];
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
      final Map<String, dynamic> all = await _readMap(_analysesFile);
      for (final PhotoAnalysis analysis in analyses) {
        all[analysis.assetId] = analysis.toJson();
      }
      await _write(_analysesFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    try {
      final Map<String, dynamic> all = await _readMap(_analysesFile);
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
      for (final MapEntry<String, dynamic> entry in all.entries) {
        analyses[entry.key] = PhotoAnalysis.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      return Success<Map<String, PhotoAnalysis>>(analyses);
    } catch (_) {
      return Failure<Map<String, PhotoAnalysis>>(_failure);
    }
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    try {
      final Map<String, dynamic> settings = await _readMap(_settingsFile);
      return Success<AppSettings>(AppSettings.fromJson(settings));
    } catch (_) {
      return Failure<AppSettings>(_failure);
    }
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    try {
      final Map<String, dynamic> all = await _readMap(_settingsFile);
      all.addAll(settings.toJson());
      await _write(_settingsFile, all);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    try {
      final Map<String, dynamic> settings = await _readMap(_settingsFile);
      return Success<bool>(settings['tutorialSeen'] as bool? ?? false);
    } catch (_) {
      return Failure<bool>(_failure);
    }
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    try {
      final Map<String, dynamic> settings = await _readMap(_settingsFile);
      settings['tutorialSeen'] = seen;
      await _write(_settingsFile, settings);
      return const Success<void>(null);
    } catch (_) {
      return Failure<void>(_failure);
    }
  }
}
