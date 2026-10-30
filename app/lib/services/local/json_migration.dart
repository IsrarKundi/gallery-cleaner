// One-time JSON -> SQLite migration (solutions 6.2, ADR-006).
//
// Reads through the existing JSON [LocalServiceImpl], so the
// Phase 4 per-entry salvage semantics carry over for free, and
// writes through the Drift stores with primary-key upserts, so
// a re-run after an interrupted import converges instead of
// duplicating ("re-runnable, never half-migrated").
//
// Atomicity, in three steps: (1) the import runs inside ONE
// database transaction, so a crash mid-import leaves either
// all rows or none of that attempt; (2) verification reads
// the committed rows AFTER the transaction (reads must never
// race a transaction's commit); (3) the marker is set only
// after verification passes. A database without a marker
// never claims to be migrated, and a failed verification
// leaves imported rows that the next launch re-imports
// idempotently (upserts converge, never duplicate) — the
// JSON files stay authoritative throughout.
//
// Verification (after commit, before the marker):
// row counts per store must equal the JSON source counts, and
// the first + last entry of each file must match value for
// value. A corrupt JSON entry is salvaged by the reader (counted
// in [JsonMigrationReport.skipped], never fatal); a JSON file
// that cannot be read at all fails the migration, and the
// caller keeps serving JSON.
//
// Stage 4 (ADR-019): the legacy analyses file no longer imports
// into an analyses table — there is none. Its rows convert to
// asset-info FACTS at membership version 0 (groups discarded,
// rescanned by the next scan), exactly like the in-database
// v2 -> v3 upgrade. A JSON membership snapshot written by a
// Stage 4 build still in JSON mode (version >= 1) imports
// whole: facts, groups, duplicate reference and its version.

import 'package:drift/drift.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/trash/trash_entry.dart';

import 'completion_store.dart';
import 'history_store.dart';
import 'meta_store.dart';
import 'scan_membership_store.dart';
import 'session_store.dart';
import 'snooze_store.dart';
import 'trash_store.dart';

/// Outcome of one migration run. [verified] is true only when
/// the import committed, verification passed, and the marker
/// was set — in that order.
class JsonMigrationReport {
  const JsonMigrationReport({
    required this.imported,
    required this.skipped,
    required this.verified,
    this.error,
  });

  /// Rows imported per JSON file name.
  final Map<String, int> imported;

  /// Entries the JSON reader salvaged (skipped) per file name.
  final Map<String, int> skipped;

  final bool verified;

  /// Non-null when verification failed or the import threw.
  final String? error;
}

class JsonMigrationRunner {
  JsonMigrationRunner(this._json, this._db);

  final LocalServiceImpl _json;
  final KlaraDatabase _db;

  Future<JsonMigrationReport> run() async {
    try {
      // 1. Read every source file. Any unreadable file fails the
      // migration outright — an empty import must never verify
      // against a source that could not be read.
      final Result<Map<String, PhotoAnalysis>> analysesResult = await _json
          .loadAnalyses();
      final Result<ScanMemberships> membershipsResult = await _json
          .loadScanMemberships();
      final Result<List<DeckSession>> sessionsResult = await _json
          .listSessions();
      final Result<List<TrashEntry>> trashResult = await _json
          .loadTrashEntries();
      final Result<List<HistoryRecord>> historyResult = await _json
          .loadHistory();
      final Result<Map<String, DateTime>> snoozesResult = await _json
          .loadSnoozes();
      final Result<List<DateTime>> completionsResult = await _json
          .loadCompletionDays();
      if (analysesResult is Failure ||
          membershipsResult is Failure ||
          sessionsResult is Failure ||
          trashResult is Failure ||
          historyResult is Failure ||
          snoozesResult is Failure ||
          completionsResult is Failure) {
        return const JsonMigrationReport(
          imported: <String, int>{},
          skipped: <String, int>{},
          verified: false,
          error: 'a JSON source file could not be read',
        );
      }
      final Map<String, PhotoAnalysis> analyses =
          (analysesResult as Success<Map<String, PhotoAnalysis>>).value;
      // The membership snapshot to import: a real Stage 4
      // snapshot (version >= 1) imports whole; anything else
      // (the JSON reader's facts-only conversion of the legacy
      // analyses) is rebuilt from [analyses] so the two paths
      // agree field for field.
      final ScanMemberships jsonMemberships =
          (membershipsResult as Success<ScanMemberships>).value;
      final ScanMemberships memberships = jsonMemberships.algorithmVersion > 0
          ? jsonMemberships
          : _factsOnly(analyses);
      final List<DeckSession> sessions =
          (sessionsResult as Success<List<DeckSession>>).value;
      final List<TrashEntry> trash =
          (trashResult as Success<List<TrashEntry>>).value;
      final List<HistoryRecord> history =
          (historyResult as Success<List<HistoryRecord>>).value;
      final Map<String, DateTime> snoozes =
          (snoozesResult as Success<Map<String, DateTime>>).value;
      final List<DateTime> completions =
          (completionsResult as Success<List<DateTime>>).value;
      final Map<String, int> skipped = _json.salvageReport;

      // 2. Import, atomically. Upserts make a re-run converge,
      // so a crash here is repaired by the next launch.
      await _db.transaction(() async {
        await _importMemberships(memberships);
        for (final DeckSession session in sessions) {
          await SessionStore(_db).save(session);
        }
        await TrashStore(_db).appendAll(trash);
        for (final HistoryRecord record in history) {
          await HistoryStore(_db).append(record);
        }
        for (final MapEntry<String, DateTime> snooze in snoozes.entries) {
          await SnoozeStore(_db).set(snooze.key, snooze.value);
        }
        for (final DateTime day in completions) {
          await CompletionStore(_db).record(day);
        }
      });

      // 3. Verify AFTER commit (reads must not race the
      // transaction), then mark. A verification failure leaves
      // imported rows without a marker: JSON stays
      // authoritative and the next launch re-imports.
      await _verify(
        memberships: memberships,
        sessions: sessions,
        trash: trash,
        history: history,
        snoozes: snoozes,
        completions: completions,
      );
      // The stamp is the app schema version this import ran
      // under (kDbSchemaVersion in local_service_db_impl.dart):
      // '4' since fix plan Stage 6 — the import writes through
      // the v4 stores (the stamp was '3' under Stage 4, whose
      // stores the membership import still uses unchanged).
      await MetaStore(_db).set('schema_version', '4');
      await MetaStore(_db).set('migration_completed', '1');

      return JsonMigrationReport(
        imported: <String, int>{
          'klara_analyses.json': analyses.length,
          'klara_sessions.json': sessions.length,
          'klara_trash.json': trash.length,
          'klara_history.json': history.length,
          'klara_snoozes.json': snoozes.length,
          'klara_completions.json': completions.length,
        },
        skipped: skipped,
        verified: true,
      );
    } catch (e) {
      // Import rolled back, or verification failed before the
      // marker was set: JSON stays authoritative and the next
      // launch retries (upserts converge, never duplicate).
      return JsonMigrationReport(
        imported: const <String, int>{},
        skipped: const <String, int>{},
        verified: false,
        error: e.toString(),
      );
    }
  }

  /// Facts-only memberships from the legacy analysis cache: the
  /// same conversion the in-database v2 -> v3 upgrade performs
  /// (type 'image', edited false, screenshot marking unknown).
  ScanMemberships _factsOnly(Map<String, PhotoAnalysis> analyses) {
    return ScanMemberships(
      algorithmVersion: 0,
      assetInfos: <String, AssetInfo>{
        for (final PhotoAnalysis a in analyses.values)
          a.assetId: AssetInfo(
            assetId: a.assetId,
            type: MediaAssetType.image,
            width: a.width,
            height: a.height,
            sizeBytes: a.sizeBytes,
            modifiedDateMs: a.modifiedDateMs,
            isEdited: false,
            isScreenshot: false,
          ),
      },
      groups: const <ScanGroup>[],
      duplicateReferences: const <DuplicateReference>[],
    );
  }

  /// Writes [memberships] into the membership tables inside the
  /// caller's transaction (the Drift store's own save() opens
  /// its own transaction, so the import writes the rows
  /// directly here, mirroring ScanMembershipStore's shape).
  Future<void> _importMemberships(ScanMemberships memberships) async {
    await _db.batch((Batch batch) {
      batch.insertAll(_db.assetInfos, <AssetInfosCompanion>[
        for (final AssetInfo info in memberships.assetInfos.values)
          AssetInfosCompanion.insert(
            assetId: info.assetId,
            type: info.type.name,
            width: info.width,
            height: info.height,
            sizeBytes: Value<int?>(info.sizeBytes),
            modifiedDateMs: Value<int?>(info.modifiedDateMs),
            isEdited: info.isEdited,
            isScreenshot: info.isScreenshot,
          ),
      ], mode: InsertMode.insertOrReplace);
    });
    for (final ScanGroup group in memberships.groups) {
      final int groupRowId = await _db
          .into(_db.scanGroups)
          .insert(
            ScanGroupsCompanion.insert(
              kind: group.kind.name,
              seedId: Value<String?>(group.seedId),
              keeperId: Value<String?>(group.keeperId),
            ),
          );
      await _db.batch((Batch batch) {
        batch.insertAll(_db.scanGroupMembers, <ScanGroupMembersCompanion>[
          for (int i = 0; i < group.memberIds.length; i++)
            ScanGroupMembersCompanion.insert(
              groupRowId: groupRowId,
              assetId: group.memberIds[i],
              memberIndex: i,
            ),
        ]);
      });
    }
    for (final DuplicateReference reference
        in memberships.duplicateReferences) {
      final int refRowId = await _db
          .into(_db.duplicateReferences)
          .insert(
            DuplicateReferencesCompanion.insert(mainId: reference.mainId),
          );
      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.duplicateReferenceMembers,
          <DuplicateReferenceMembersCompanion>[
            for (int i = 0; i < reference.duplicateIds.length; i++)
              DuplicateReferenceMembersCompanion.insert(
                referenceRowId: refRowId,
                assetId: reference.duplicateIds[i],
                memberIndex: i,
              ),
          ],
        );
      });
    }
    await _db
        .into(_db.metaEntries)
        .insertOnConflictUpdate(
          MetaEntriesCompanion.insert(
            key: kMembershipVersionKey,
            value: '${memberships.algorithmVersion}',
          ),
        );
  }

  /// Counts + first/last spot-checks, after the import commits.
  /// Throws on any mismatch, which withholds the marker.
  Future<void> _verify({
    required ScanMemberships memberships,
    required List<DeckSession> sessions,
    required List<TrashEntry> trash,
    required List<HistoryRecord> history,
    required Map<String, DateTime> snoozes,
    required List<DateTime> completions,
  }) async {
    void check(bool condition, String what) {
      if (!condition) {
        throw StateError('migration verification failed: $what');
      }
    }

    final Result<ScanMemberships> loaded = await ScanMembershipStore(_db)
        .load();
    final ScanMemberships dbMemberships = loaded.fold(
      onSuccess: (ScanMemberships value) => value,
      onFailure: (_) => throw StateError('membership reload failed'),
    );
    check(
      dbMemberships.algorithmVersion == memberships.algorithmVersion,
      'membership version',
    );
    check(
      dbMemberships.assetInfos.length == memberships.assetInfos.length,
      'asset infos count',
    );
    check(
      dbMemberships.groups.length == memberships.groups.length,
      'scan groups count',
    );
    check(
      dbMemberships.duplicateReferences.length ==
          memberships.duplicateReferences.length,
      'duplicate references count',
    );
    for (final String id in <String>{
      if (memberships.assetInfos.isNotEmpty) memberships.assetInfos.keys.first,
      if (memberships.assetInfos.isNotEmpty) memberships.assetInfos.keys.last,
    }) {
      final AssetInfo? back = dbMemberships.assetInfos[id];
      final AssetInfo source = memberships.assetInfos[id]!;
      check(back != null && back.sameFacts(source), 'asset info $id values');
    }

    final List<DeckSession> dbSessions = await SessionStore(_db).listAll();
    check(dbSessions.length == sessions.length, 'sessions count');
    for (final DeckSession source in <DeckSession>{
      if (sessions.isNotEmpty) sessions.first,
      if (sessions.isNotEmpty) sessions.last,
    }) {
      final DeckSession? back = await SessionStore(_db).load(source.filterKey);
      check(
        back != null &&
            back.currentIndex == source.currentIndex &&
            _mapsEqual(back.marks, source.marks) &&
            back.favouriteIds.length == source.favouriteIds.length &&
            back.favouriteIds.containsAll(source.favouriteIds),
        'session ${source.filterKey} values',
      );
    }

    final List<TrashEntry> dbTrash = await TrashStore(_db).loadAll();
    check(dbTrash.length == trash.length, 'trash count');
    for (final TrashEntry source in <TrashEntry>{
      if (trash.isNotEmpty) trash.first,
      if (trash.isNotEmpty) trash.last,
    }) {
      final TrashEntry back = dbTrash.firstWhere(
        (TrashEntry e) => e.assetId == source.assetId,
      );
      // Millisecond precision: the database stores dates as
      // epoch milliseconds, so sub-millisecond JSON precision
      // is (harmlessly) truncated on import. Day-level display
      // and the 30-day recoverable window are unaffected, and
      // the JSON backup retains full precision.
      check(
        back.typeInt == source.typeInt &&
            back.width == source.width &&
            back.height == source.height &&
            back.sizeBytes == source.sizeBytes &&
            back.trashedAt.millisecondsSinceEpoch ==
                source.trashedAt.millisecondsSinceEpoch,
        'trash ${source.assetId} values',
      );
    }

    final List<HistoryRecord> dbHistory = await HistoryStore(_db).loadAll();
    check(dbHistory.length == history.length, 'history count');
    for (final HistoryRecord source in <HistoryRecord>{
      if (history.isNotEmpty) history.first,
      if (history.isNotEmpty) history.last,
    }) {
      check(
        dbHistory.any(
          (HistoryRecord r) =>
              r.date.millisecondsSinceEpoch ==
                  source.date.millisecondsSinceEpoch &&
              r.count == source.count &&
              r.mbTrashed == source.mbTrashed &&
              r.mbFreed == source.mbFreed,
        ),
        'history ${source.date} values',
      );
    }

    final Map<String, DateTime> dbSnoozes = await SnoozeStore(_db).loadAll();
    check(dbSnoozes.length == snoozes.length, 'snoozes count');
    for (final String id in <String>{
      if (snoozes.isNotEmpty) snoozes.keys.first,
      if (snoozes.isNotEmpty) snoozes.keys.last,
    }) {
      check(dbSnoozes[id] == snoozes[id], 'snooze $id value');
    }

    final List<DateTime> dbCompletions = await CompletionStore(_db).loadAll();
    check(dbCompletions.length == completions.length, 'completions count');
    for (final DateTime day in <DateTime>{
      if (completions.isNotEmpty) completions.first,
      if (completions.isNotEmpty) completions.last,
    }) {
      check(dbCompletions.contains(day), 'completion $day value');
    }
  }

  bool _mapsEqual(Map<String, DeckMark> a, Map<String, DeckMark> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final MapEntry<String, DeckMark> entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
