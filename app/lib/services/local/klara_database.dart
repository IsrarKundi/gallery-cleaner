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
//
// Schema v2 (fix plan Stage 3, ADR-018): swipe marks and
// session favourites leave the per-session JSON blobs for
// their own per-row tables ([Marks], [SessionFavourites]), so
// one swipe writes one small mark row instead of re-encoding
// the session's whole marks map into its row. [Sessions] keeps
// only the resume position. The 1 -> 2 upgrade copies every
// blob entry into the row tables BEFORE the blob columns are
// dropped, inside the migration transaction: a crash mid-way
// rolls the whole upgrade back and the next launch retries it.
//
// Schema v3 (fix plan Stage 4, ADR-019): the persisted aHash
// leaves the database. The scan's persisted product is now
// memberships — [AssetInfos] (facts), [ScanGroups] +
// [ScanGroupMembers] (group memberships) and
// [DuplicateReferences] + [DuplicateReferenceMembers] (the
// duplicate reference) — with no hash or score column anywhere.
// The 2 -> 3 upgrade converts each legacy analyses row's FACTS
// into [AssetInfos] (type 'image', edited false, screenshot
// marking unknown/false), stamps the membership version 0 (so
// the converted facts are never mistaken for fresh memberships)
// and drops the analyses table: the old engine's groups are
// discarded and the next scan recomputes them.
//
// Schema v4 (fix plan Stage 6, ADR-021): similar-video groups
// join the membership product. Group kinds are TEXT
// ([ScanGroups.kind]), so the new 'similarVideos' kind needs
// no DDL — the bump exists so the version chain and the
// downgrade guard recognise Stage 6 builds, and the 3 -> 4
// upgrade restamps the membership version 0: a v3 snapshot
// predates video groups, so it must never read as fresh (the
// membership algorithm version also moved to 2 — the stamp is
// the same belt-and-braces the 2 -> 3 upgrade applied).

import 'dart:convert';

import 'package:drift/drift.dart';

part 'klara_database.g.dart';

/// Asset-info facts (schema v3, fix plan Stage 4): the plain
/// per-asset facts the duplicate key and the membership
/// freshness rule need, one row per asset. No hash, no scores —
/// those are recomputed per scan, never persisted (ADR-019).
/// Replaces the v1-v2 analyses table (dropped by the upgrade).
@DataClassName('AssetInfoRow')
class AssetInfos extends Table {
  TextColumn get assetId => text()();

  /// MediaAssetType.name ('image' / 'video').
  TextColumn get type => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get modifiedDateMs => integer().nullable()();
  BoolColumn get isEdited => boolean()();
  BoolColumn get isScreenshot => boolean()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// One scan group (schema v3): its kind plus the group's seed
/// (similar groups) and suggested keeper where it has them.
/// Members live in [ScanGroupMembers], ordered.
@DataClassName('ScanGroupRow')
class ScanGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ScanGroupKind.name: 'similar' / 'duplicate' / 'blurry' /
  /// 'dark' / 'similarVideos' (Stage 6).
  TextColumn get kind => text()();
  TextColumn get seedId => text().nullable()();
  TextColumn get keeperId => text().nullable()();
}

/// One asset's membership in one [ScanGroups] row, with its
/// position so group order (seed first) round-trips exactly.
@DataClassName('ScanGroupMemberRow')
class ScanGroupMembers extends Table {
  IntColumn get groupRowId => integer()();
  TextColumn get assetId => text()();
  IntColumn get memberIndex => integer()();

  @override
  Set<Column> get primaryKey => {groupRowId, assetId};
}

/// One duplicate set's reference (schema v3): the main photo.
/// Its duplicates live in [DuplicateReferenceMembers], ordered.
@DataClassName('DuplicateReferenceRow')
class DuplicateReferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mainId => text()();
}

/// One duplicate's membership in one [DuplicateReferences] row,
/// with its position.
@DataClassName('DuplicateReferenceMemberRow')
class DuplicateReferenceMembers extends Table {
  IntColumn get referenceRowId => integer()();
  TextColumn get assetId => text()();
  IntColumn get memberIndex => integer()();

  @override
  Set<Column> get primaryKey => {referenceRowId, assetId};
}

/// One deck session's resume position, keyed by filter key.
/// The session's marks and favourites live in [Marks] and
/// [SessionFavourites] (schema v2) — this row is only the
/// per-deck progress record.
class Sessions extends Table {
  TextColumn get filterKey => text()();
  IntColumn get currentIndex => integer()();

  @override
  Set<Column> get primaryKey => {filterKey};
}

/// One swipe mark (schema v2, fix plan Stage 3): the marks
/// store. A swipe inserts or replaces exactly one of these
/// rows (an unmark deletes it) — never a rewrite of the
/// session it belongs to. [mark] is the [DeckMark] name, the
/// same string the v1 session blob stored, copied verbatim by
/// the upgrade so no mark can change meaning in transit.
class Marks extends Table {
  TextColumn get filterKey => text()();
  TextColumn get assetId => text()();
  TextColumn get mark => text()();

  @override
  Set<Column> get primaryKey => {filterKey, assetId};
}

/// One favourited (protected) asset within a deck session
/// (schema v2). Same per-row reasoning as [Marks].
class SessionFavourites extends Table {
  TextColumn get filterKey => text()();
  TextColumn get assetId => text()();

  @override
  Set<Column> get primaryKey => {filterKey, assetId};
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
    AssetInfos,
    ScanGroups,
    ScanGroupMembers,
    DuplicateReferences,
    DuplicateReferenceMembers,
    Sessions,
    Marks,
    SessionFavourites,
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await _upgrade1To2(m);
      }
      if (from < 3) {
        await _upgrade2To3(m);
      }
      if (from < 4) {
        await _upgrade3To4(m);
      }
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

  /// Schema 1 -> 2 (fix plan Stage 3, ADR-018): split every
  /// session's marks/favourites blobs into [Marks] /
  /// [SessionFavourites] rows, then rebuild [Sessions] without
  /// the blob columns. Runs inside drift's migration
  /// transaction — a crash anywhere rolls the whole upgrade
  /// back, the database stays at v1, and the next launch
  /// retries; a committed upgrade never re-runs.
  ///
  /// Blob strings are copied VERBATIM (mark names are not
  /// parsed here), so a mark cannot change meaning in transit;
  /// name parsing keeps the one rule it always had
  /// ([DeckSession.fromJson]: unknown names read as keep) at
  /// read time in the session store. A blob that fails to
  /// decode at all is never dropped: its raw text is preserved
  /// in [MetaEntries] under `quarantine:session:<filterKey>`
  /// for a future repair, and the session's progress row still
  /// migrates (the app-level downgrade guard cannot apply —
  /// the database DID open; quarantining is the no-silent-loss
  /// option).
  Future<void> _upgrade1To2(Migrator m) async {
    await m.createTable(marks);
    await m.createTable(sessionFavourites);
    final List<QueryRow> rows = await customSelect(
      'SELECT filter_key, marks_json, favourites_json FROM sessions',
    ).get();
    await batch((Batch b) {
      for (final QueryRow row in rows) {
        final String filterKey = row.read<String>('filter_key');
        final String marksJson = row.read<String>('marks_json');
        final String favouritesJson = row.read<String>('favourites_json');
        try {
          final Map<String, dynamic> marksMap =
              jsonDecode(marksJson) as Map<String, dynamic>;
          for (final MapEntry<String, dynamic> entry in marksMap.entries) {
            b.insert(
              marks,
              MarksCompanion.insert(
                filterKey: filterKey,
                assetId: entry.key,
                mark: entry.value as String,
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
          final List<dynamic> favouriteIds =
              jsonDecode(favouritesJson) as List<dynamic>;
          for (final Object? id in favouriteIds) {
            b.insert(
              sessionFavourites,
              SessionFavouritesCompanion.insert(
                filterKey: filterKey,
                assetId: id as String,
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        } catch (_) {
          b.insert(
            metaEntries,
            MetaEntriesCompanion.insert(
              key: 'quarantine:session:$filterKey',
              value: jsonEncode(<String, String>{
                'marksJson': marksJson,
                'favouritesJson': favouritesJson,
              }),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    });
    await m.alterTable(TableMigration(sessions));
  }

  /// Schema 2 -> 3 (fix plan Stage 4, ADR-019): create the
  /// membership tables, convert every legacy analyses row's
  /// FACTS into [AssetInfos], stamp the membership version 0,
  /// and drop the analyses table (with it, the persisted hash).
  ///
  /// The old rows' groups are NOT converted: they were computed
  /// by the retired aHash/slider engine and cannot be expressed
  /// in the new rules — carrying them over would mint phantom
  /// groups. Version 0 memberships are never "fresh", so the
  /// first Stage 4 scan recomputes everything from the live
  /// library and restamps. The converted facts keep the
  /// asset-info third of the split populated for inspection and
  /// cost nothing: freshness compares them exactly, and any
  /// difference (including the screenshot marking, unknown in
  /// the old cache and converted as false) triggers the rescan
  /// anyway. Runs inside drift's migration transaction like
  /// every upgrade here.
  Future<void> _upgrade2To3(Migrator m) async {
    await m.createTable(assetInfos);
    await m.createTable(scanGroups);
    await m.createTable(scanGroupMembers);
    await m.createTable(duplicateReferences);
    await m.createTable(duplicateReferenceMembers);
    final List<QueryRow> rows = await customSelect(
      'SELECT asset_id, width, height, size_bytes, modified_date_ms '
      'FROM analyses',
    ).get();
    await batch((Batch b) {
      for (final QueryRow row in rows) {
        b.insert(
          assetInfos,
          AssetInfosCompanion.insert(
            assetId: row.read<String>('asset_id'),
            type: 'image',
            width: row.read<int>('width'),
            height: row.read<int>('height'),
            sizeBytes: Value<int?>(row.readNullable<int>('size_bytes')),
            modifiedDateMs: Value<int?>(
              row.readNullable<int>('modified_date_ms'),
            ),
            isEdited: false,
            isScreenshot: false,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      b.insert(
        metaEntries,
        MetaEntriesCompanion.insert(key: 'scan_membership_version', value: '0'),
        mode: InsertMode.insertOrReplace,
      );
    });
    await customStatement('DROP TABLE IF EXISTS analyses');
  }

  /// Schema 3 -> 4 (fix plan Stage 6, ADR-021): no table
  /// changes — group kinds are text, so similar-video groups
  /// fit the v3 tables as they are. The upgrade's one job is
  /// the membership restamp: every v3 snapshot predates video
  /// groups, so its membership version is set to 0 (never
  /// fresh), and the first Stage 6 scan recomputes the whole
  /// matching phase and restamps at the current version. All
  /// v3 rows — facts, groups, the duplicate reference, and
  /// every other store — carry over untouched.
  Future<void> _upgrade3To4(Migrator m) async {
    await into(metaEntries).insert(
      MetaEntriesCompanion.insert(key: 'scan_membership_version', value: '0'),
      mode: InsertMode.insertOrReplace,
    );
  }
}
