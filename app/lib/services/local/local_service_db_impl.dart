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
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';

import 'completion_store.dart';
import 'history_store.dart';
import 'json_migration.dart';
import 'json_file_store.dart';
import 'meta_store.dart';
import 'scan_membership_store.dart';
import 'session_store.dart';
import 'snooze_store.dart';
import 'trash_store.dart';

/// Schema version this build writes (see [MetaStore]).
/// v2 = fix plan Stage 3: marks/favourites split into their
/// own tables (ADR-018). v3 = fix plan Stage 4: scan
/// memberships replace the analyses table (ADR-019).
const int kDbSchemaVersion = 3;

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

  /// The one session store for this service's database
  /// (Stage 3): its save-diff mirror must span calls, so it
  /// cannot be rebuilt per method like the stateless stores.
  /// The database future is memoised, so the store is built
  /// once, from the first resolved database.
  SessionStore? _sessionStore;

  SessionStore _sessions(KlaraDatabase db) {
    return _sessionStore ??= SessionStore(db);
  }

  Future<Directory>? _dirFuture;
  Future<KlaraDatabase>? _dbFuture;
  Future<void>? _readyFuture;
  bool _downgraded = false;

  /// True once the database is authoritative for migrated stores.
  /// False until a migration verifies: until then methods serve
  /// JSON, so a failed or interrupted migration costs nothing.
  bool _dbMode = false;

  /// Outcome of the last migration run, if one ran this launch.
  /// Diagnostics for tests and logs; never user data.
  JsonMigrationReport? _lastMigrationReport;

  JsonMigrationReport? get lastMigrationReport => _lastMigrationReport;

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

  /// Opens the database, runs the downgrade guard, then runs
  /// the JSON migration once when no verified marker exists.
  /// Until a migration verifies, [_dbMode] stays false and
  /// migrated methods keep serving JSON — the app works
  /// throughout, and the next launch retries the import.
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
        return;
      }
      final String? migrated = await MetaStore(db)
          .get(kDbMigrationCompletedKey);
      if (migrated == '1') {
        _dbMode = true;
        return;
      }
      final JsonMigrationReport report = await JsonMigrationRunner(
        _json,
        db,
      ).run();
      _lastMigrationReport = report;
      _dbMode = report.verified;
    } catch (_) {
      // A database that cannot even open is treated as a
      // downgrade-equivalent failure: migrated methods fail
      // explicitly instead of serving invented data.
      _downgraded = true;
    }
  }

  /// Runs [run] against the database after init, mapping every
  /// failure (including a database that cannot open) to a
  /// [Failure] — service methods never throw. While the
  /// database is not yet authoritative ([_dbMode] false),
  /// [jsonFallback] serves the JSON files instead.
  Future<Result<T>> _guarded<T>(
    Future<T> Function(KlaraDatabase db) run,
    Future<Result<T>> Function() jsonFallback,
  ) async {
    await _ready;
    if (_downgraded) {
      return Failure<T>(_failure);
    }
    if (!_dbMode) {
      return jsonFallback();
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
    return _guarded(
      (KlaraDatabase db) => _sessions(db).save(session),
      () => _json.saveSession(session),
    );
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return _guarded(
      (KlaraDatabase db) => _sessions(db).load(filterKey),
      () => _json.loadSession(filterKey),
    );
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return _guarded(
      (KlaraDatabase db) => _sessions(db).listAll(),
      () => _json.listSessions(),
    );
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return _guarded(
      (KlaraDatabase db) => SnoozeStore(db).loadAll(),
      () => _json.loadSnoozes(),
    );
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return _guarded(
      (KlaraDatabase db) => SnoozeStore(db).set(assetId, until),
      () => _json.setSnooze(assetId, until),
    );
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    return _guarded(
      (KlaraDatabase db) => SnoozeStore(db).clearBatch(ids),
      () => _json.clearSnoozes(ids),
    );
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
    return _guarded(
      (KlaraDatabase db) => CompletionStore(db).loadAll(),
      () => _json.loadCompletionDays(),
    );
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return _guarded(
      (KlaraDatabase db) => CompletionStore(db).record(day),
      () => _json.recordCompletionDay(day),
    );
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return _guarded(
      (KlaraDatabase db) => TrashStore(db).appendAll(entries),
      () => _json.recordTrashed(entries),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return _guarded(
      (KlaraDatabase db) => TrashStore(db).loadAll(),
      () => _json.loadTrashEntries(),
    );
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return _guarded(
      (KlaraDatabase db) => TrashStore(db).removeByIds(ids),
      () => _json.removeTrashEntries(ids),
    );
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return _guarded(
      (KlaraDatabase db) => TrashStore(db).clearAll(),
      () => _json.clearTrashEntries(),
    );
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return _guarded(
      (KlaraDatabase db) => HistoryStore(db).append(record),
      () => _json.appendHistory(record),
    );
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return _guarded(
      (KlaraDatabase db) => HistoryStore(db).loadAll(),
      () => _json.loadHistory(),
    );
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

  // The analyses trio is LEGACY since fix plan Stage 4
  // (ADR-019): the database no longer has an analyses table —
  // the persisted hash is gone. The trio still runs through
  // _guarded (init, migration and the downgrade guard keep
  // their exact semantics); its database branch is empty by
  // design, and its JSON branch remains the migration source
  // for pre-Stage-4 caches. Nothing writes new analyses.

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    return _guarded(
      (KlaraDatabase db) async {},
      () => _json.saveAnalyses(analyses),
    );
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return _guarded(
      (KlaraDatabase db) async => <String, PhotoAnalysis>{},
      () => _json.loadAnalyses(),
    );
  }

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return _guarded(
      (KlaraDatabase db) async => 0,
      () => _json.pruneAnalyses(liveIds),
    );
  }

  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async {
    return _guarded<ScanMemberships>((KlaraDatabase db) async {
      final Result<ScanMemberships> result = await ScanMembershipStore(db)
          .load();
      return result.fold(
        onSuccess: (ScanMemberships value) => value,
        onFailure: (_) => throw StateError('membership load failed'),
      );
    }, () => _json.loadScanMemberships());
  }

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async {
    return _guarded<void>((KlaraDatabase db) async {
      final Result<void> result = await ScanMembershipStore(db)
          .save(memberships);
      result.fold(
        onSuccess: (_) {},
        onFailure: (_) => throw StateError('membership save failed'),
      );
    }, () => _json.saveScanMemberships(memberships));
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
