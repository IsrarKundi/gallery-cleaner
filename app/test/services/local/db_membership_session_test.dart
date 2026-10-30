// Membership + session stores against an in-memory database
// (no platform channels, no files). Stage 4 (ADR-019): the
// membership store replaced the analysis store — its round-trip
// must preserve groups and the duplicate reference exactly, and
// its tables must carry NO hash or score column anywhere.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/scan_membership_store.dart';
import 'package:klara/services/local/session_store.dart';
import 'package:klara/services/media/media_asset.dart';

ScanMemberships _snapshot() {
  return ScanMemberships(
    algorithmVersion: scanMembershipAlgorithmVersion,
    assetInfos: <String, AssetInfo>{
      'a': const AssetInfo(
        assetId: 'a',
        type: MediaAssetType.image,
        width: 100,
        height: 200,
        sizeBytes: 1000,
        modifiedDateMs: 1700000000000,
        isEdited: false,
        isScreenshot: false,
      ),
      'b': const AssetInfo(
        assetId: 'b',
        type: MediaAssetType.image,
        width: 100,
        height: 200,
        sizeBytes: null,
        modifiedDateMs: null,
        isEdited: false,
        isScreenshot: true,
      ),
      'v': const AssetInfo(
        assetId: 'v',
        type: MediaAssetType.video,
        width: 1920,
        height: 1080,
        sizeBytes: 5000,
        modifiedDateMs: 1700000000001,
        isEdited: false,
        isScreenshot: false,
      ),
    },
    groups: const <ScanGroup>[
      ScanGroup(
        kind: ScanGroupKind.similar,
        memberIds: <String>['a', 'b'],
        seedId: 'a',
        keeperId: 'b',
      ),
      ScanGroup(kind: ScanGroupKind.blurry, memberIds: <String>['b']),
    ],
    duplicateReferences: const <DuplicateReference>[
      DuplicateReference(mainId: 'a', duplicateIds: <String>['b']),
    ],
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

  group('ScanMembershipStore', () {
    test('save/load round-trips facts, groups and the reference', () async {
      final ScanMembershipStore store = ScanMembershipStore(db);
      final Result<void> saved = await store.save(_snapshot());
      expect(saved.isSuccess, isTrue);
      final Result<ScanMemberships> loaded = await store.load();
      final ScanMemberships back = loaded.fold(
        onSuccess: (ScanMemberships v) => v,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(back.algorithmVersion, scanMembershipAlgorithmVersion);
      expect(back.assetInfos.length, 3);
      expect(back.assetInfos['a']!.sizeBytes, 1000);
      expect(back.assetInfos['b']!.sizeBytes, isNull);
      expect(back.assetInfos['b']!.isScreenshot, isTrue);
      expect(back.assetInfos['v']!.type, MediaAssetType.video);
      final List<ScanGroup> similar = back.groupsOfKind(ScanGroupKind.similar);
      expect(similar.length, 1);
      expect(similar.single.memberIds, <String>['a', 'b']);
      expect(similar.single.seedId, 'a');
      expect(similar.single.keeperId, 'b');
      expect(back.memberSetOf(ScanGroupKind.blurry), <String>{'b'});
      expect(back.duplicateReferences.length, 1);
      expect(back.duplicateReferences.single.mainId, 'a');
      expect(back.duplicateReferences.single.duplicateIds, <String>['b']);
    });

    test('re-saving replaces wholesale, never merges', () async {
      final ScanMembershipStore store = ScanMembershipStore(db);
      await store.save(_snapshot());
      await store.save(ScanMemberships.empty);
      final Result<ScanMemberships> loaded = await store.load();
      final ScanMemberships back = loaded.fold(
        onSuccess: (ScanMemberships v) => v,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(back.assetInfos, isEmpty);
      expect(back.groups, isEmpty);
      expect(back.duplicateReferences, isEmpty);
    });

    test('an unsaved database loads as version 0, empty', () async {
      final ScanMembershipStore store = ScanMembershipStore(db);
      final Result<ScanMemberships> loaded = await store.load();
      final ScanMemberships back = loaded.fold(
        onSuccess: (ScanMemberships v) => v,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(back.algorithmVersion, 0);
      expect(back.assetInfos, isEmpty);
    });

    test('the schema carries no hash or score anywhere', () async {
      final List<QueryRow> rows = await db
          .customSelect(
            "SELECT name, sql FROM sqlite_master WHERE type = 'table'",
          )
          .get();
      final Map<String, String> tables = <String, String>{
        for (final QueryRow row in rows)
          row.read<String>('name'): row.read<String>('sql'),
      };
      // The analyses table (and its hash column) is gone.
      expect(tables.containsKey('analyses'), isFalse);
      for (final String table in <String>[
        'asset_infos',
        'scan_groups',
        'scan_group_members',
        'duplicate_references',
        'duplicate_reference_members',
      ]) {
        expect(tables.containsKey(table), isTrue, reason: table);
        final String ddl = tables[table]!.toLowerCase();
        expect(ddl.contains('hash'), isFalse, reason: table);
        expect(ddl.contains('score'), isFalse, reason: table);
        expect(ddl.contains('blur'), isFalse, reason: table);
      }
    });
  });

  group('SessionStore', () {
    DeckSession session(String key, int index) {
      return DeckSession(
        filterKey: key,
        currentIndex: index,
        marks: <String, DeckMark>{'x': DeckMark.keep, 'y': DeckMark.delete},
        favouriteIds: <String>{'x'},
      );
    }

    test('save/load/list round-trips marks and favourites', () async {
      final SessionStore store = SessionStore(db);
      await store.save(session('all', 3));
      final DeckSession? back = await store.load('all');
      expect(back!.currentIndex, 3);
      expect(back.marks['y'], DeckMark.delete);
      expect(back.favouriteIds, <String>{'x'});
      expect(await store.load('missing'), isNull);
      expect((await store.listAll()).length, 1);
      await store.save(session('all', 9));
      expect((await store.load('all'))!.currentIndex, 9);
      expect(await store.count(), 1);
    });

    test('a progress row with no mark rows loads as an empty '
        'session, never fatal', () async {
      // Schema v2: there is no JSON blob left to be unparseable
      // (the v1 failure this test guarded). The structural case
      // that remains — a session row whose marks are absent —
      // reads as an empty session, not as a crash or a skip.
      final SessionStore store = SessionStore(db);
      await db
          .into(db.sessions)
          .insert(SessionsCompanion.insert(filterKey: 'bare', currentIndex: 4));
      final DeckSession? back = await store.load('bare');
      expect(back, isNotNull);
      expect(back!.currentIndex, 4);
      expect(back.marks, isEmpty);
      expect(back.favouriteIds, isEmpty);
      expect((await store.listAll()).length, 1);
    });

    test('unknown mark names default to keep, as the file store did', () async {
      final SessionStore store = SessionStore(db);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(filterKey: 'weird', currentIndex: 0),
          );
      await db
          .into(db.marks)
          .insert(
            MarksCompanion.insert(
              filterKey: 'weird',
              assetId: 'x',
              mark: 'bogus-mark',
            ),
          );
      expect((await store.load('weird'))!.marks['x'], DeckMark.keep);
    });
  });
}
