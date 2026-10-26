// Append-only deletion history over Drift (solutions 6.1).
//
// One row per record; the autoincrement id orders rows with
// equal dates in insertion order.

import 'package:drift/drift.dart';
import 'package:klara/services/local/local_service.dart';

import 'klara_database.dart';

class HistoryStore {
  HistoryStore(this._db);

  final KlaraDatabase _db;

  /// Appends one record.
  Future<void> append(HistoryRecord record) async {
    await _db
        .into(_db.historyRecords)
        .insert(
          HistoryRecordsCompanion.insert(
            dateMs: record.date.millisecondsSinceEpoch,
            count: record.count,
            mbTrashed: record.mbTrashed,
            mbFreed: record.mbFreed,
          ),
        );
  }

  /// Records, newest first.
  Future<List<HistoryRecord>> loadAll() async {
    final List<HistoryRecordRow> rows =
        await (_db.select(_db.historyRecords)
              ..orderBy(<OrderingTerm Function(HistoryRecords t)>[
                (HistoryRecords t) =>
                    OrderingTerm(expression: t.dateMs, mode: OrderingMode.desc),
              ]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.historyRecords.id.count();
    final TypedResult row = await (_db.selectOnly(
      _db.historyRecords,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  HistoryRecord _fromRow(HistoryRecordRow row) {
    return HistoryRecord(
      date: DateTime.fromMillisecondsSinceEpoch(row.dateMs),
      count: row.count,
      mbTrashed: row.mbTrashed,
      mbFreed: row.mbFreed,
    );
  }
}
