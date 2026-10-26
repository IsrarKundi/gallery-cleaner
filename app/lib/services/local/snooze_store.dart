// Snooze-until dates over Drift (solutions 6.1).
//
// Dates are normalised to date-only, exactly as the file store
// did: an asset is snoozed while today is before its stored
// date. A null set clears the row.

import 'package:drift/drift.dart';

import 'klara_database.dart';

class SnoozeStore {
  SnoozeStore(this._db);

  final KlaraDatabase _db;

  /// Snooze-until dates by asset id.
  Future<Map<String, DateTime>> loadAll() async {
    final List<Snooze> rows = await _db.select(_db.snoozes).get();
    return <String, DateTime>{
      for (final Snooze row in rows)
        row.assetId: DateTime.fromMillisecondsSinceEpoch(row.untilMs),
    };
  }

  /// Sets the snooze for [assetId], or clears it when [until]
  /// is null.
  Future<void> set(String assetId, DateTime? until) async {
    if (until == null) {
      await (_db.delete(
        _db.snoozes,
      )..where((Snoozes t) => t.assetId.equals(assetId))).go();
      return;
    }
    final DateTime day = DateTime(until.year, until.month, until.day);
    await _db
        .into(_db.snoozes)
        .insert(
          SnoozesCompanion.insert(
            assetId: assetId,
            untilMs: day.millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Clears the snoozes for [ids] in a single statement. A
  /// delete affecting zero rows writes nothing, so no
  /// "skip when nothing present" special case is needed.
  Future<void> clearBatch(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (_db.delete(
      _db.snoozes,
    )..where((Snoozes t) => t.assetId.isIn(ids))).go();
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.snoozes.assetId.count();
    final TypedResult row = await (_db.selectOnly(
      _db.snoozes,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }
}
