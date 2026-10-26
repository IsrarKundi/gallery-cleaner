// Phase 6.1: Drift trash/history/snooze/completion/meta
// stores + the trash-date index plan, against an in-memory
// database.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/local/completion_store.dart';
import 'package:klara/services/local/history_store.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/meta_store.dart';
import 'package:klara/services/local/snooze_store.dart';
import 'package:klara/services/local/trash_store.dart';
import 'package:klara/services/trash/trash_entry.dart';

TrashEntry trash(String id, int ms) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 20,
    sizeBytes: 100,
    trashedAt: DateTime.fromMillisecondsSinceEpoch(ms),
  );
}

void main() {
  late KlaraDatabase db;

  setUp(() {
    db = KlaraDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('trash: append, newest-first load, remove, clear, replace', () async {
    final TrashStore store = TrashStore(db);
    await store.appendAll(<TrashEntry>[trash('old', 1000), trash('new', 2000)]);
    expect(
      (await store.loadAll()).map((TrashEntry e) => e.assetId).toList(),
      <String>['new', 'old'],
    );
    await store.appendAll(<TrashEntry>[trash('new', 3000)]);
    expect((await store.loadAll()).length, 2);
    expect(
      (await store.loadAll()).first.trashedAt.millisecondsSinceEpoch,
      3000,
    );
    await store.removeByIds(<String>['new']);
    expect(
      (await store.loadAll()).map((TrashEntry e) => e.assetId).toList(),
      <String>['old'],
    );
    await store.clearAll();
    expect(await store.loadAll(), isEmpty);
    expect(await store.count(), 0);
  });

  test('trash newest-first query uses the date index', () async {
    final List<QueryRow> plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM trash_entries '
          'ORDER BY trashed_at_ms DESC',
          readsFrom: <TableInfo<Table, dynamic>>{db.trashEntries},
        )
        .get();
    final String detail = plan
        .map((QueryRow row) => row.read<String>('detail'))
        .join(' ');
    expect(detail, contains('USING INDEX'));
  });

  test('history: append and newest-first load', () async {
    final HistoryStore store = HistoryStore(db);
    await store.append(
      HistoryRecord(
        date: DateTime(2026, 1, 1),
        count: 2,
        mbTrashed: 1.5,
        mbFreed: 0,
      ),
    );
    await store.append(
      HistoryRecord(
        date: DateTime(2026, 1, 2),
        count: 1,
        mbTrashed: 0,
        mbFreed: 3.0,
      ),
    );
    final List<HistoryRecord> back = await store.loadAll();
    expect(back.first.date, DateTime(2026, 1, 2));
    expect(back.first.mbFreed, 3.0);
    expect(await store.count(), 2);
  });

  test('snoozes: set, date-only normalisation, clear, batch clear', () async {
    final SnoozeStore store = SnoozeStore(db);
    await store.set('a', DateTime(2026, 5, 6, 15, 30));
    await store.set('b', DateTime(2026, 5, 7));
    final Map<String, DateTime> back = await store.loadAll();
    expect(back['a'], DateTime(2026, 5, 6));
    expect(back.length, 2);
    await store.set('a', null);
    expect((await store.loadAll()).keys, <String>['b']);
    await store.clearBatch(<String>['b', 'missing']);
    expect(await store.loadAll(), isEmpty);
    expect(await store.count(), 0);
  });

  test('completions: record is idempotent per day', () async {
    final CompletionStore store = CompletionStore(db);
    await store.record(DateTime(2026, 5, 6, 10, 0));
    await store.record(DateTime(2026, 5, 6, 23, 0));
    await store.record(DateTime(2026, 5, 7));
    expect(await store.loadAll(), <DateTime>[
      DateTime(2026, 5, 6),
      DateTime(2026, 5, 7),
    ]);
    expect(await store.count(), 2);
  });

  test('meta: get/set round-trip with null for missing keys', () async {
    final MetaStore store = MetaStore(db);
    expect(await store.get('nope'), isNull);
    await store.set('k', 'v');
    expect(await store.get('k'), 'v');
    await store.set('k', 'v2');
    expect(await store.get('k'), 'v2');
  });
}
