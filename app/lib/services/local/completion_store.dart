// Completed days over Drift (solutions 6.1).
//
// One row per date-only day; recording the same day twice
// stores it once (insert-or-ignore, matching the file store's
// idempotent record).

import 'package:drift/drift.dart';

import 'klara_database.dart';

class CompletionStore {
  CompletionStore(this._db);

  final KlaraDatabase _db;

  /// Completed days, oldest first.
  Future<List<DateTime>> loadAll() async {
    final List<Completion> rows =
        await (_db.select(_db.completions)
              ..orderBy(<OrderingTerm Function(Completions t)>[
                (Completions t) =>
                    OrderingTerm(expression: t.dayMs, mode: OrderingMode.asc),
              ]))
            .get();
    return rows
        .map((Completion row) => DateTime.fromMillisecondsSinceEpoch(row.dayMs))
        .toList();
  }

  /// Records [day] (normalised to date-only) as completed.
  Future<void> record(DateTime day) async {
    final DateTime only = DateTime(day.year, day.month, day.day);
    await _db
        .into(_db.completions)
        .insert(
          CompletionsCompanion.insert(
            dayMs: Value<int>(only.millisecondsSinceEpoch),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.completions.dayMs.count();
    final TypedResult row = await (_db.selectOnly(
      _db.completions,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }
}
