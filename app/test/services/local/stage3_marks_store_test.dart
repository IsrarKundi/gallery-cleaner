// Fix plan Stage 3 proofs (ADR-018):
// 1. A v1 database (sessions carrying marks as JSON blobs)
//    upgrades to schema v2 with every mark, favourite,
//    history and trash record intact — and a second launch
//    changes nothing (idempotent).
// 2. Old-format JSON files migrate into the marks store with
//    every mark surviving, exactly, and re-running the app
//    does not duplicate anything.
// 3. One swipe = one small save: a save carrying ONE new mark
//    writes exactly one mark row (plus the tiny progress row)
//    and touches no other store.
// 4. Marks and favourites round-trip save/load exactly.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/local/scan_membership_store.dart';
import 'package:klara/services/local/history_store.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_db_impl.dart';
import 'package:klara/services/local/session_store.dart';
import 'package:klara/services/local/trash_store.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

/// The exact v1 DDL drift generated (dumped from a v1 build's
/// database): the fixture an upgrading install actually has.
const List<String> _v1Ddl = <String>[
  'CREATE TABLE "analyses" ("asset_id" TEXT NOT NULL, "hash" INTEGER NOT NULL, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL, "blur_score" REAL NOT NULL, "mean_luminance" REAL NOT NULL, "size_bytes" INTEGER NULL, "modified_date_ms" INTEGER NULL, "algorithm_version" INTEGER NOT NULL, PRIMARY KEY ("asset_id"))',
  'CREATE TABLE "completions" ("day_ms" INTEGER NOT NULL, PRIMARY KEY ("day_ms"))',
  'CREATE TABLE "history_records" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "date_ms" INTEGER NOT NULL, "count" INTEGER NOT NULL, "mb_trashed" REAL NOT NULL, "mb_freed" REAL NOT NULL)',
  'CREATE TABLE "meta_entries" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
  'CREATE TABLE "sessions" ("filter_key" TEXT NOT NULL, "current_index" INTEGER NOT NULL, "marks_json" TEXT NOT NULL, "favourites_json" TEXT NOT NULL, PRIMARY KEY ("filter_key"))',
  'CREATE TABLE "snoozes" ("asset_id" TEXT NOT NULL, "until_ms" INTEGER NOT NULL, PRIMARY KEY ("asset_id"))',
  'CREATE TABLE "trash_entries" ("asset_id" TEXT NOT NULL, "type_int" INTEGER NOT NULL, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL, "size_bytes" INTEGER NOT NULL, "trashed_at_ms" INTEGER NOT NULL, PRIMARY KEY ("asset_id"))',
];

void _buildV1Fixture(File file) {
  final sql.Database db = sql.sqlite3.open(file.path);
  try {
    for (final String ddl in _v1Ddl) {
      db.execute(ddl);
    }
    db.execute('PRAGMA user_version = 1');
    // The state a real v1 install carries: the JSON import
    // already ran and verified under the old build.
    db.execute(
      "INSERT INTO meta_entries VALUES ('schema_version', '1'), "
      "('migration_completed', '1')",
    );
    final sql.PreparedStatement session = db.prepare(
      'INSERT INTO sessions VALUES (?, ?, ?, ?)',
    );
    session.execute(<Object?>[
      'all',
      7,
      '{"a1":"keep","a2":"delete","a3":"bogus-mark"}',
      '["a1"]',
    ]);
    session.execute(<Object?>['smart:screenshots', 2, '{"b1":"maybe"}', '[]']);
    session.execute(<Object?>['duplicates', 0, '{}', '[]']);
    session.close();
    db.execute(
      "INSERT INTO trash_entries VALUES ('t1', 1, 100, 200, 5000, 1700000000000)",
    );
    db.execute(
      'INSERT INTO history_records (date_ms, count, mb_trashed, mb_freed) '
      'VALUES (1700000000000, 3, 1.5, 0.0)',
    );
  } finally {
    db.close();
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_stage3_test_');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('v1 database upgrades to v2 without losing a mark', () async {
    _buildV1Fixture(File('${temp.path}/klara.db'));

    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    final DeckSession all = ok(await service.loadSession('all'))!;
    expect(all.currentIndex, 7);
    expect(all.marks, <String, DeckMark>{
      'a1': DeckMark.keep,
      'a2': DeckMark.delete,
      // Copied verbatim by the upgrade; the one name rule
      // (unknown -> keep) applies at read, as it always did.
      'a3': DeckMark.keep,
    });
    expect(all.favouriteIds, <String>{'a1'});
    final DeckSession smart = ok(
      await service.loadSession('smart:screenshots'),
    )!;
    expect(smart.marks, <String, DeckMark>{'b1': DeckMark.maybe});
    final DeckSession dup = ok(await service.loadSession('duplicates'))!;
    expect(dup.marks, isEmpty);
    expect(ok(await service.loadTrashEntries()), hasLength(1));
    expect(ok(await service.loadHistory()), hasLength(1));
    await service.dispose();

    // The physical shape really changed, once.
    final KlaraDatabase raw = KlaraDatabase(
      NativeDatabase(File('${temp.path}/klara.db')),
    );
    final int version =
        (await raw.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        );
    // The chain now continues to schema v3 (Stage 4); the v1
    // blob still splits on the way through 1 -> 2.
    expect(version, 3);
    final List<String> sessionColumns = <String>[
      for (final QueryRow row
          in await raw.customSelect('PRAGMA table_info(sessions)').get())
        row.read<String>('name'),
    ];
    expect(sessionColumns, <String>['filter_key', 'current_index']);
    Future<int> rowCount(String table) async {
      final QueryRow row = await raw
          .customSelect('SELECT COUNT(*) AS c FROM $table')
          .getSingle();
      return row.read<int>('c');
    }

    expect(await rowCount('marks'), 4);
    expect(await rowCount('session_favourites'), 1);
    await raw.close();

    // Second launch: identical state, no re-split, no dupes.
    final LocalServiceDbImpl again = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    final DeckSession allAgain = ok(await again.loadSession('all'))!;
    expect(allAgain.marks, all.marks);
    expect(allAgain.favouriteIds, all.favouriteIds);
    expect(ok(await again.loadHistory()), hasLength(1));
    await again.dispose();
  });

  test('old JSON files migrate into the marks store, every mark '
      'surviving, and a relaunch duplicates nothing', () async {
    DeckSession buildSession(String key, int count, int offset) {
      return DeckSession(
        filterKey: key,
        currentIndex: count,
        marks: <String, DeckMark>{
          for (int i = 0; i < count; i++)
            'm${offset + i}': DeckMark.values[(offset + i) % 4],
        },
        favouriteIds: <String>{'m$offset'},
      );
    }

    final List<DeckSession> sessions = <DeckSession>[
      buildSession('all', 200, 0),
      buildSession('smart:videos', 30, 1000),
      buildSession('duplicates', 20, 2000),
    ];
    await File('${temp.path}/klara_sessions.json').writeAsString(
      jsonEncode(<String, dynamic>{
        for (final DeckSession s in sessions) s.filterKey: s.toJson(),
      }),
    );
    await File('${temp.path}/klara_history.json').writeAsString(
      jsonEncode(<Map<String, dynamic>>[
        HistoryRecord(
          date: DateTime.utc(2026, 10, 1),
          count: 5,
          mbTrashed: 2.5,
          mbFreed: 0,
        ).toJson(),
        HistoryRecord(
          date: DateTime.utc(2026, 10, 2),
          count: 7,
          mbTrashed: 0,
          mbFreed: 3.5,
        ).toJson(),
      ]),
    );
    await File('${temp.path}/klara_trash.json').writeAsString(
      jsonEncode(<Map<String, dynamic>>[
        TrashEntry(
          assetId: 't1',
          typeInt: 1,
          width: 10,
          height: 20,
          sizeBytes: 1234,
          trashedAt: DateTime.utc(2026, 10, 3),
        ).toJson(),
      ]),
    );

    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    for (final DeckSession source in sessions) {
      final DeckSession back = ok(await service.loadSession(source.filterKey))!;
      expect(back.currentIndex, source.currentIndex);
      expect(back.marks, source.marks);
      expect(back.favouriteIds, source.favouriteIds);
    }
    expect(ok(await service.loadHistory()), hasLength(2));
    expect(ok(await service.loadTrashEntries()), hasLength(1));
    await service.dispose();

    final KlaraDatabase raw = KlaraDatabase(
      NativeDatabase(File('${temp.path}/klara.db')),
    );
    final int markRows =
        (await raw.customSelect('SELECT COUNT(*) AS c FROM marks').getSingle())
            .read<int>('c');
    expect(markRows, 250);
    await raw.close();

    // Relaunch: the verified marker stops a second import —
    // append-only history must NOT double.
    final LocalServiceDbImpl again = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    expect(ok(await again.loadHistory()), hasLength(2));
    final DeckSession allAgain = ok(await again.loadSession('all'))!;
    expect(allAgain.marks, sessions.first.marks);
    await again.dispose();
  });

  test('one swipe writes one mark row and touches no other store', () async {
    final KlaraDatabase db = KlaraDatabase(NativeDatabase.memory());
    final SessionStore store = SessionStore(db);
    // Neighbouring stores hold data the swipe must not touch.
    await ScanMembershipStore(db).save(
      const ScanMemberships(
        algorithmVersion: 1,
        assetInfos: <String, AssetInfo>{
          'p1': AssetInfo(
            assetId: 'p1',
            type: MediaAssetType.image,
            width: 10,
            height: 10,
            sizeBytes: null,
            modifiedDateMs: null,
            isEdited: false,
            isScreenshot: false,
          ),
          'p2': AssetInfo(
            assetId: 'p2',
            type: MediaAssetType.image,
            width: 10,
            height: 10,
            sizeBytes: null,
            modifiedDateMs: null,
            isEdited: false,
            isScreenshot: false,
          ),
        },
        groups: <ScanGroup>[],
        duplicateReferences: <DuplicateReference>[],
      ),
    );
    await TrashStore(db).appendAll(<TrashEntry>[
      TrashEntry(
        assetId: 't1',
        typeInt: 1,
        width: 1,
        height: 1,
        sizeBytes: 1,
        trashedAt: DateTime.utc(2026),
      ),
    ]);
    await HistoryStore(db).append(
      HistoryRecord(
        date: DateTime.utc(2026),
        count: 1,
        mbTrashed: 1,
        mbFreed: 0,
      ),
    );

    final Map<String, DeckMark> hundred = <String, DeckMark>{
      for (int i = 0; i < 100; i++) 'a$i': DeckMark.keep,
    };
    await store.save(
      DeckSession(
        filterKey: 'all',
        currentIndex: 100,
        marks: hundred,
        favouriteIds: const <String>{},
      ),
    );
    expect(store.markRowsWritten, 100);
    expect(store.sessionRowsWritten, 1);

    store.markRowsWritten = 0;
    store.favouriteRowsWritten = 0;
    store.sessionRowsWritten = 0;

    // The swipe: one new delete mark, index advances by one.
    await store.save(
      DeckSession(
        filterKey: 'all',
        currentIndex: 101,
        marks: <String, DeckMark>{...hundred, 'a100': DeckMark.delete},
        favouriteIds: const <String>{},
      ),
    );
    expect(store.markRowsWritten, 1);
    expect(store.favouriteRowsWritten, 0);
    expect(store.sessionRowsWritten, 1);

    // The unmark after it costs exactly one mark-row delete.
    store.markRowsWritten = 0;
    store.sessionRowsWritten = 0;
    await store.save(
      DeckSession(
        filterKey: 'all',
        currentIndex: 102,
        marks: hundred,
        favouriteIds: const <String>{},
      ),
    );
    expect(store.markRowsWritten, 1);

    // Neighbours untouched, and the session reads back exact.
    expect(
      (await ScanMembershipStore(db).load()).fold(
        onSuccess: (ScanMemberships m) => m.assetInfos.length,
        onFailure: (_) => -1,
      ),
      2,
    );
    expect((await TrashStore(db).loadAll()).length, 1);
    expect((await HistoryStore(db).loadAll()).length, 1);
    final DeckSession back = (await store.load('all'))!;
    expect(back.marks, hundred);
    expect(back.currentIndex, 102);
    await db.close();
  });

  test('marks and favourites round-trip exactly through a cold '
      'store (no mirror help)', () async {
    final KlaraDatabase db = KlaraDatabase(NativeDatabase.memory());
    const DeckSession session = DeckSession(
      filterKey: 'month:2026-10',
      currentIndex: 42,
      marks: <String, DeckMark>{
        'k': DeckMark.keep,
        'd': DeckMark.delete,
        'm': DeckMark.maybe,
        'f': DeckMark.favourite,
      },
      favouriteIds: <String>{'f', 'k'},
    );
    await SessionStore(db).save(session);
    final SessionStore cold = SessionStore(db);
    final DeckSession back = (await cold.load(session.filterKey))!;
    expect(back.currentIndex, 42);
    expect(back.marks, session.marks);
    expect(back.favouriteIds, session.favouriteIds);
    final List<DeckSession> all = await cold.listAll();
    expect(all, hasLength(1));
    expect(all.single.marks, session.marks);
    await db.close();
  });
}
