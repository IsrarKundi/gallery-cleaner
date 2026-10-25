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

  static const String _sessionsFile = 'klara_sessions.json';
  static const String _trashFile = 'klara_trash.json';
  static const String _historyFile = 'klara_history.json';
  static const String _settingsFile = 'klara_settings.json';
  static const String _analysesFile = 'klara_analyses.json';

  Future<Directory> _dir() async {
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
