// SQLite-backed [LocalService] (solutions 6.1).
//
// Repositories sit behind the existing interface, so
// controllers do not change shape. Migrated stores (analyses,
// sessions, trash, history, snoozes, completions) are served
// from Drift; settings stays JSON by design (solutions 6.1)
// and is delegated to an internal [LocalServiceImpl], which is
// also the JSON reader the 6.2 migration imports from.
//
// Durability change, recorded in ADR-006: with per-row upserts
// a save commits immediately in its transaction, so the Phase 4
// 1.5 s coalescing crash window disappears for migrated stores.
// [flushPendingWrites] therefore awaits init and is otherwise
// immediate; every mandatory flush call site keeps working.
//
// Downgrade guard: the meta table carries the schema version
// this build wrote. A database stamped by a NEWER build makes
// every migrated method fail explicitly — never a silent loss,
// never a crash. Settings methods keep working (they are JSON,
// version-independent).
//
// Mobile note: on Android the sqlite native library comes from
// the `sqlite3_flutter_libs` package (a dependency, no code
// needed); on this host VM the system libsqlite3 is used. The
// release build must confirm the library ships — see the Phase 6
// device checklist, it cannot be proven from this VM.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';

import 'analysis_store.dart';
import 'completion_store.dart';
import 'history_store.dart';
import 'json_file_store.dart';
import 'meta_store.dart';
import 'session_store.dart';
import 'snooze_store.dart';
import 'trash_store.dart';

/// Schema version this build writes (see [MetaStore]).
const int kDbSchemaVersion = 1;

/// Meta key carrying the schema version stamp.
const String kDbSchemaVersionKey = 'schema_version';

/// Meta key set once a migration has been verified (6.2).
const String kDbMigrationCompletedKey = 'migration_completed';

class LocalServiceDbImpl implements LocalService {
  LocalServiceDbImpl({
    DirectoryResolver? directoryResolver,
    KlaraDatabase? database,
    LocalServiceImpl? jsonSource,
  }) : _directoryResolver =
           directoryResolver ?? getApplicationDocumentsDirectory,
       _databaseOverride = database,
       _json =
           jsonSource ??
           LocalServiceImpl(
             directoryResolver:
                 directoryResolver ?? getApplicationDocumentsDirectory,
           );

  final DirectoryResolver _directoryResolver;
  final KlaraDatabase? _databaseOverride;

  /// JSON source: settings store + 6.2 migration reader.
  final LocalServiceImpl _json;

  Future<Directory>? _dirFuture;
  Future<KlaraDatabase>? _dbFuture;
  Future<void>? _readyFuture;
  bool _downgraded = false;

  AppFailure get _failure =>
      const AppFailure(messageKey: AppStrings.errorLocal);

  Future<Directory> _dir() {
    return _dirFuture ??= _resolveDir();
  }

  Future<Directory> _resolveDir() async {
    try {
      final Directory dir = await _directoryResolver();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      _dirFuture = null;
      rethrow;
    }
  }

  Future<KlaraDatabase> get _db {
    return _dbFuture ??= _openDb();
  }

  Future<KlaraDatabase> _openDb() async {
    if (_databaseOverride != null) {
      return _databaseOverride;
    }
    final Directory dir = await _dir();
    return KlaraDatabase(
      LazyDatabase(() async {
        return NativeDatabase.createInBackground(
          File(p.join(dir.path, 'klara.db')),
        );
      }),
    );
  }

  /// Opens the database and runs the downgrade guard. The 6.2
  /// migration step lands here (before [_dbMode] is set) — until
  /// then a fresh database is authoritative immediately.
  Future<void> get _ready {
    return _readyFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      final KlaraDatabase db = await _db;
      final String? stamped = await MetaStore(db).get(kDbSchemaVersionKey);
      final int stored = int.tryParse(stamped ?? '') ?? 0;
      if (stored > kDbSchemaVersion) {
        _downgraded = true;
      }
    } catch (_) {
      // A database that cannot even open is treated as a
      // downgrade-equivalent failure: migrated methods fail
      // explicitly instead of serving invented data.
      _downgraded = true;
    }
  }

  /// Runs [run] against the database after init, mapping every
  /// failure (including a database that cannot open) to a
  /// [Failure] — service methods never throw.
  Future<Result<T>> _guarded<T>(
    Future<T> Function(KlaraDatabase db) run,
  ) async {
    await _ready;
    if (_downgraded) {
      return Failure<T>(_failure);
    }
    try {
      final KlaraDatabase db = await _db;
      return Success<T>(await run(db));
    } catch (_) {
      return Failure<T>(_failure);
    }
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return _guarded((KlaraDatabase db) => SessionStore(db).save(session));
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return _guarded((KlaraDatabase db) => SessionStore(db).load(filterKey));
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return _guarded((KlaraDatabase db) => SessionStore(db).listAll());
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return _guarded((KlaraDatabase db) => SnoozeStore(db).loadAll());
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return _guarded((KlaraDatabase db) => SnoozeStore(db).set(assetId, until));
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    return _guarded((KlaraDatabase db) => SnoozeStore(db).clearBatch(ids));
  }

  @override
  Future<void> flushPendingWrites() async {
    // Migrated stores commit immediately; awaiting init is the
    // only work left. Settings writes were always immediate.
    await _ready;
  }

  @override
  Future<Result<double>> loadGoalTargetMb() => _json.loadGoalTargetMb();

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) =>
      _json.saveGoalTargetMb(mb);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return _guarded((KlaraDatabase db) => CompletionStore(db).loadAll());
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return _guarded((KlaraDatabase db) => CompletionStore(db).record(day));
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return _guarded((KlaraDatabase db) => TrashStore(db).appendAll(entries));
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return _guarded((KlaraDatabase db) => TrashStore(db).loadAll());
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return _guarded((KlaraDatabase db) => TrashStore(db).removeByIds(ids));
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return _guarded((KlaraDatabase db) => TrashStore(db).clearAll());
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return _guarded((KlaraDatabase db) => HistoryStore(db).append(record));
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return _guarded((KlaraDatabase db) => HistoryStore(db).loadAll());
  }

  @override
  Future<Result<bool>> isTutorialSeen() => _json.isTutorialSeen();

  @override
  Future<Result<void>> setTutorialSeen(bool seen) =>
      _json.setTutorialSeen(seen);

  @override
  Future<Result<AppSettings>> loadSettings() => _json.loadSettings();

  @override
  Future<Result<void>> saveSettings(AppSettings settings) =>
      _json.saveSettings(settings);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    return _guarded((KlaraDatabase db) => AnalysisStore(db).saveAll(analyses));
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return _guarded((KlaraDatabase db) => AnalysisStore(db).loadAll());
  }

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return _guarded((KlaraDatabase db) => AnalysisStore(db).prune(liveIds));
  }

  /// Closes the database (if opened) and the JSON settings store.
  Future<void> dispose() async {
    final Future<KlaraDatabase>? opened = _dbFuture;
    if (opened != null) {
      await (await opened).close();
    }
    await _json.dispose();
  }
}
