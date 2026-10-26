// Drift schema for Klara Stage 2 storage (solutions 6.1).
//
// One row per entity, never one file per store: the cost of a
// read or write is per-row, not per-file. Settings stays JSON
// by design (solutions 6.1) and lives outside this schema.
//
// Table/column SQL names are drift's defaults (class name and
// field name converted to snake_case); the index statements in
// [KlaraDatabase.migration] must match the generated names —
// verify against klara_database.g.dart after codegen, do not
// guess them. Dates are INTEGER milliseconds since epoch, never
// drift DateTime columns, so every value round-trips exactly.

import 'package:drift/drift.dart';

part 'klara_database.g.dart';

/// One cached photo analysis, keyed by MediaStore asset id.
/// Columns mirror [PhotoAnalysis] field for field, including the
/// Phase 5.3 fingerprint (sizeBytes, modifiedDateMs,
/// algorithmVersion) so freshness checks work identically.
class Analyses extends Table {
  TextColumn get assetId => text()();
  IntColumn get hash => integer()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  RealColumn get blurScore => real()();
  RealColumn get meanLuminance => real()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get modifiedDateMs => integer().nullable()();
  IntColumn get algorithmVersion => integer()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// One deck session, keyed by filter key. Marks and favourites
/// are stored as the same JSON the file store used, so
/// [DeckSession.fromJson] parses them identically.
class Sessions extends Table {
  TextColumn get filterKey => text()();
  IntColumn get currentIndex => integer()();
  TextColumn get marksJson => text()();
  TextColumn get favouritesJson => text()();

  @override
  Set<Column> get primaryKey => {filterKey};
}

/// One recorded Trash entry, keyed by asset id. A re-trash of
/// the same asset replaces its row: the app's flow removes the
/// record on restore first, so a duplicate row cannot arise
/// through the UI, and replace-on-conflict is the safe rule if
/// it ever does (solutions 6.1, ADR-006).
@DataClassName('TrashEntryRow')
class TrashEntries extends Table {
  TextColumn get assetId => text()();
  IntColumn get typeInt => integer()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get sizeBytes => integer()();
  IntColumn get trashedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// One deletion-history record. Append-only; `id` orders rows
/// with equal dates in insertion order.
@DataClassName('HistoryRecordRow')
class HistoryRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dateMs => integer()();
  IntColumn get count => integer()();
  RealColumn get mbTrashed => real()();
  RealColumn get mbFreed => real()();
}

/// Snooze-until dates by asset id, date-only milliseconds.
class Snoozes extends Table {
  TextColumn get assetId => text()();
  IntColumn get untilMs => integer()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// Completed days, date-only milliseconds. One row per day.
class Completions extends Table {
  IntColumn get dayMs => integer()();

  @override
  Set<Column> get primaryKey => {dayMs};
}

/// Small string key/value table: migration marker and schema
/// guard live here, never in a JSON file (solutions 6.2).
class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Analyses,
    Sessions,
    TrashEntries,
    HistoryRecords,
    Snoozes,
    Completions,
    MetaEntries,
  ],
)
class KlaraDatabase extends _$KlaraDatabase {
  KlaraDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      // WAL mode (solutions 6.1): readers never block writers
      // during scanner batch commits.
      await customStatement('PRAGMA journal_mode = WAL;');
      // Hot-path indexes (solutions 6.1): trash and history
      // are always read newest-first.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trash_date '
        'ON trash_entries (trashed_at_ms);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_history_date '
        'ON history_records (date_ms);',
      );
    },
  );
}
