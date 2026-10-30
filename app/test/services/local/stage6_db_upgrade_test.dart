// Fix plan Stage 6 proofs (ADR-021):
// 1. A v3 database (the Stage 4 schema, membership version
//    stamped 1) upgrades to schema v4 with every fact, group,
//    reference, mark and session intact — and its membership
//    version restamped 0, so the pre-video-groups snapshot is
//    never read as fresh and the first Stage 6 scan recomputes.
// 2. After the upgrade, a snapshot carrying similarVideos
//    groups saves and loads back exactly (the kind is a text
//    column — Stage 6 needed no new tables).
// 3. A second launch changes nothing (idempotent).

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_db_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

/// The v3 DDL (dumped from the Stage 4 build's generated
/// schema). Stage 6 changed NO tables — v4's DDL is identical,
/// which is precisely what this fixture relies on: a real v3
/// install's file differs from a v4 one only in user_version
/// and the meta stamps.
const List<String> _v3Ddl = <String>[
  'CREATE TABLE "asset_infos" ("asset_id" TEXT NOT NULL, "type" TEXT NOT NULL, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL, "size_bytes" INTEGER NULL, "modified_date_ms" INTEGER NULL, "is_edited" INTEGER NOT NULL CHECK ("is_edited" IN (0, 1)), "is_screenshot" INTEGER NOT NULL CHECK ("is_screenshot" IN (0, 1)), PRIMARY KEY ("asset_id"))',
  'CREATE TABLE "completions" ("day_ms" INTEGER NOT NULL, PRIMARY KEY ("day_ms"))',
  'CREATE TABLE "duplicate_reference_members" ("reference_row_id" INTEGER NOT NULL, "asset_id" TEXT NOT NULL, "member_index" INTEGER NOT NULL, PRIMARY KEY ("reference_row_id", "asset_id"))',
  'CREATE TABLE "duplicate_references" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "main_id" TEXT NOT NULL)',
  'CREATE TABLE "history_records" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "date_ms" INTEGER NOT NULL, "count" INTEGER NOT NULL, "mb_trashed" REAL NOT NULL, "mb_freed" REAL NOT NULL)',
  'CREATE TABLE "marks" ("filter_key" TEXT NOT NULL, "asset_id" TEXT NOT NULL, "mark" TEXT NOT NULL, PRIMARY KEY ("filter_key", "asset_id"))',
  'CREATE TABLE "meta_entries" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
  'CREATE TABLE "scan_group_members" ("group_row_id" INTEGER NOT NULL, "asset_id" TEXT NOT NULL, "member_index" INTEGER NOT NULL, PRIMARY KEY ("group_row_id", "asset_id"))',
  'CREATE TABLE "scan_groups" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" TEXT NOT NULL, "seed_id" TEXT NULL, "keeper_id" TEXT NULL)',
  'CREATE TABLE "session_favourites" ("filter_key" TEXT NOT NULL, "asset_id" TEXT NOT NULL, PRIMARY KEY ("filter_key", "asset_id"))',
  'CREATE TABLE "sessions" ("filter_key" TEXT NOT NULL, "current_index" INTEGER NOT NULL, PRIMARY KEY ("filter_key"))',
  'CREATE TABLE "snoozes" ("asset_id" TEXT NOT NULL, "until_ms" INTEGER NOT NULL, PRIMARY KEY ("asset_id"))',
  'CREATE TABLE "trash_entries" ("asset_id" TEXT NOT NULL, "type_int" INTEGER NOT NULL, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL, "size_bytes" INTEGER NOT NULL, "trashed_at_ms" INTEGER NOT NULL, PRIMARY KEY ("asset_id"))',
];

void _buildV3Fixture(File file) {
  final sql.Database db = sql.sqlite3.open(file.path);
  try {
    for (final String ddl in _v3Ddl) {
      db.execute(ddl);
    }
    db.execute('PRAGMA user_version = 3');
    // The state a real v3 install carries: JSON import long
    // verified, a Stage 4 scan's memberships stamped 1.
    db.execute(
      "INSERT INTO meta_entries VALUES ('schema_version', '3'), "
      "('migration_completed', '1'), ('scan_membership_version', '1')",
    );
    db.execute(
      "INSERT INTO asset_infos VALUES "
      "('p1', 'image', 100, 200, 1000, 1700000000000, 0, 0), "
      "('p2', 'image', 100, 200, 1000, 1700000000000, 0, 0), "
      "('v1', 'video', 1920, 1080, 5000, 1700000000001, 0, 0)",
    );
    db.execute(
      "INSERT INTO scan_groups (kind, seed_id, keeper_id) "
      "VALUES ('similar', 'p1', 'p1')",
    );
    db.execute(
      "INSERT INTO scan_group_members VALUES (1, 'p1', 0), (1, 'p2', 1)",
    );
    db.execute("INSERT INTO duplicate_references (main_id) VALUES ('p1')");
    db.execute("INSERT INTO duplicate_reference_members VALUES (1, 'p2', 0)");
    db.execute("INSERT INTO sessions VALUES ('all', 3)");
    db.execute("INSERT INTO marks VALUES ('all', 'p1', 'delete')");
    db.execute(
      "INSERT INTO trash_entries VALUES ('t1', 1, 100, 200, 5000, 1700000000000)",
    );
  } finally {
    db.close();
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_stage6_test_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('v3 database upgrades to v4: data intact, membership '
      'version restamped 0', () async {
    _buildV3Fixture(File('${temp.path}/klara.db'));

    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    final ScanMemberships memberships = ok(await service.loadScanMemberships());
    // Restamped: a v3 snapshot predates video groups, so it
    // must never read as fresh under the v2 algorithm.
    expect(memberships.algorithmVersion, 0);
    expect(memberships.isFreshFor(memberships.assetInfos), isFalse);
    // Facts and groups carried over untouched.
    expect(memberships.assetInfos.length, 3);
    expect(memberships.assetInfos['v1']!.type, MediaAssetType.video);
    final List<ScanGroup> similar = memberships.groupsOfKind(
      ScanGroupKind.similar,
    );
    expect(similar.length, 1);
    expect(similar.single.memberIds, <String>['p1', 'p2']);
    expect(similar.single.seedId, 'p1');
    expect(similar.single.keeperId, 'p1');
    expect(memberships.duplicateReferences.single.mainId, 'p1');
    expect(memberships.duplicateReferences.single.duplicateIds, <String>['p2']);
    // Other stores untouched by the upgrade.
    expect(ok(await service.loadSession('all'))!.currentIndex, 3);
    expect(ok(await service.loadSession('all'))!.marks, <String, DeckMark>{
      'p1': DeckMark.delete,
    });
    expect(ok(await service.loadTrashEntries()), hasLength(1));
    await service.dispose();

    // The physical version really moved, once.
    final KlaraDatabase raw = KlaraDatabase(
      NativeDatabase(File('${temp.path}/klara.db')),
    );
    final int version =
        (await raw.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        );
    expect(version, 4);
    await raw.close();
  });

  test('after the upgrade, similarVideos groups round-trip '
      'through the DB store', () async {
    _buildV3Fixture(File('${temp.path}/klara.db'));

    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    final ScanMemberships snapshot = ScanMemberships(
      algorithmVersion: scanMembershipAlgorithmVersion,
      assetInfos: ok(await service.loadScanMemberships()).assetInfos,
      groups: const <ScanGroup>[
        ScanGroup(
          kind: ScanGroupKind.similarVideos,
          memberIds: <String>['v1', 'v9'],
          seedId: 'v1',
        ),
      ],
      duplicateReferences: const <DuplicateReference>[],
    );
    ok(await service.saveScanMemberships(snapshot));
    final ScanMemberships back = ok(await service.loadScanMemberships());
    expect(back.algorithmVersion, scanMembershipAlgorithmVersion);
    final List<ScanGroup> groups = back.groupsOfKind(
      ScanGroupKind.similarVideos,
    );
    expect(groups.length, 1);
    expect(groups.single.memberIds, <String>['v1', 'v9']);
    expect(groups.single.seedId, 'v1');
    expect(groups.single.keeperId, isNull);
    expect(back.allMemberIdsOf(ScanGroupKind.similarVideos), <String>{
      'v1',
      'v9',
    });
    await service.dispose();

    // Second launch: nothing changes (idempotent).
    final LocalServiceDbImpl second = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    final ScanMemberships again = ok(await second.loadScanMemberships());
    expect(again.algorithmVersion, scanMembershipAlgorithmVersion);
    expect(again.groupsOfKind(ScanGroupKind.similarVideos).length, 1);
    await second.dispose();
  });
}
