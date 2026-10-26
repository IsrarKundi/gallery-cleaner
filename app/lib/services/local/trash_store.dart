// Per-row recorded Trash over Drift (solutions 6.1).
//
// Trash is the only record of trashed assets, so every write
// here commits immediately in its own transaction — never
// coalesced, exactly as the file store did (solutions 4.1).
// A re-trash of the same asset replaces its row: the app's
// flow removes the record on restore first, so a duplicate
// cannot arise through the UI (see klara_database.dart).

import 'package:drift/drift.dart';
import 'package:klara/services/trash/trash_entry.dart';

import 'klara_database.dart';

class TrashStore {
  TrashStore(this._db);

  final KlaraDatabase _db;

  /// Appends [entries] (one transaction; replaces any row with
  /// the same asset id).
  Future<void> appendAll(List<TrashEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }
    await _db.transaction(() async {
      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.trashEntries,
          entries.map(_companion).toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  /// Recorded entries, newest first. Ties on trashedAt keep
  /// database order — cosmetic only, the list is a record.
  Future<List<TrashEntry>> loadAll() async {
    final List<TrashEntryRow> rows =
        await (_db.select(_db.trashEntries)
              ..orderBy(<OrderingTerm Function(TrashEntries t)>[
                (TrashEntries t) => OrderingTerm(
                  expression: t.trashedAtMs,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map(_fromRow).toList();
  }

  /// Drops every row whose asset id is in [ids].
  Future<void> removeByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (_db.delete(
      _db.trashEntries,
    )..where((TrashEntries t) => t.assetId.isIn(ids))).go();
  }

  /// Clears the whole recorded Trash list.
  Future<void> clearAll() async {
    await _db.delete(_db.trashEntries).go();
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.trashEntries.assetId.count();
    final TypedResult row = await (_db.selectOnly(
      _db.trashEntries,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  TrashEntriesCompanion _companion(TrashEntry entry) {
    return TrashEntriesCompanion.insert(
      assetId: entry.assetId,
      typeInt: entry.typeInt,
      width: entry.width,
      height: entry.height,
      sizeBytes: entry.sizeBytes,
      trashedAtMs: entry.trashedAt.millisecondsSinceEpoch,
    );
  }

  TrashEntry _fromRow(TrashEntryRow row) {
    return TrashEntry(
      assetId: row.assetId,
      typeInt: row.typeInt,
      width: row.width,
      height: row.height,
      sizeBytes: row.sizeBytes,
      trashedAt: DateTime.fromMillisecondsSinceEpoch(row.trashedAtMs),
    );
  }
}
