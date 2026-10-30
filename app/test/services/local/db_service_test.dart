// Phase 6.1: LocalServiceDbImpl through the public interface
// against a real file database in a temp directory — no JSON
// present, so the database is authoritative from the start.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_db_impl.dart';
import 'package:klara/services/local/meta_store.dart';
import 'package:klara/services/trash/trash_entry.dart';

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

void main() {
  late Directory temp;
  late LocalServiceDbImpl service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_db_service_test_');
    service = LocalServiceDbImpl(directoryResolver: () async => temp);
  });

  tearDown(() async {
    await service.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('sessions, memberships, trash, history through the interface', () async {
    await service.saveSession(
      const DeckSession(
        filterKey: 'all',
        currentIndex: 2,
        marks: <String, DeckMark>{'a': DeckMark.delete},
        favouriteIds: <String>{},
      ),
    );
    expect(
      (await service.loadSession('all')).fold(
        onSuccess: (DeckSession? s) => s?.currentIndex,
        onFailure: (_) => -1,
      ),
      2,
    );
    expect(ok(await service.listSessions()).length, 1);

    // Stage 4 (ADR-019): the persisted scan product is the
    // membership snapshot — facts only, no hash/score fields.
    // Saving a smaller snapshot replaces the old one wholesale
    // (the prune analogue: nothing of the old snapshot remains).
    await service.saveScanMemberships(
      const ScanMemberships(
        algorithmVersion: 1,
        assetInfos: <String, AssetInfo>{
          'a': AssetInfo(
            assetId: 'a',
            type: MediaAssetType.image,
            width: 10,
            height: 20,
            sizeBytes: 5,
            modifiedDateMs: null,
            isEdited: false,
            isScreenshot: false,
          ),
        },
        groups: <ScanGroup>[],
        duplicateReferences: <DuplicateReference>[],
      ),
    );
    expect(ok(await service.loadScanMemberships()).assetInfos.length, 1);
    await service.saveScanMemberships(ScanMemberships.empty);
    expect(ok(await service.loadScanMemberships()).assetInfos.length, 0);

    await service.recordTrashed(<TrashEntry>[
      TrashEntry(
        assetId: 'a',
        typeInt: 1,
        width: 10,
        height: 20,
        sizeBytes: 5,
        trashedAt: DateTime(2026, 1, 1),
      ),
    ]);
    expect(ok(await service.loadTrashEntries()).length, 1);
    await service.removeTrashEntries(<String>['a']);
    expect(ok(await service.loadTrashEntries()), isEmpty);

    await service.appendHistory(
      HistoryRecord(
        date: DateTime(2026, 1, 1),
        count: 1,
        mbTrashed: 1.0,
        mbFreed: 0,
      ),
    );
    expect(ok(await service.loadHistory()).length, 1);
  });

  test('snoozes, completions, settings, flush through the interface', () async {
    await service.setSnooze('a', DateTime(2026, 5, 6));
    expect(ok(await service.loadSnoozes()).length, 1);
    await service.clearSnoozes(<String>['a']);
    expect(ok(await service.loadSnoozes()), isEmpty);

    await service.recordCompletionDay(DateTime(2026, 5, 6));
    await service.recordCompletionDay(DateTime(2026, 5, 6));
    expect(ok(await service.loadCompletionDays()).length, 1);

    await service.saveSettings(const AppSettings(protection: true));
    expect(ok(await service.loadSettings()).protection, isTrue);
    await service.saveGoalTargetMb(42.0);
    expect(ok(await service.loadGoalTargetMb()), 42.0);
    await service.setTutorialSeen(true);
    expect(ok(await service.isTutorialSeen()), isTrue);

    await service.flushPendingWrites();
  });

  test('data survives dispose and reopen on the same directory', () async {
    await service.saveSession(
      const DeckSession(
        filterKey: 'all',
        currentIndex: 5,
        marks: <String, DeckMark>{},
        favouriteIds: <String>{},
      ),
    );
    await service.dispose();
    service = LocalServiceDbImpl(directoryResolver: () async => temp);
    expect(
      (await service.loadSession('all')).fold(
        onSuccess: (DeckSession? s) => s?.currentIndex,
        onFailure: (_) => -1,
      ),
      5,
    );
  });

  test('a database stamped by a newer build fails explicitly', () async {
    // Stamp the file database as schema version 99 first.
    final KlaraDatabase raw = KlaraDatabase(
      NativeDatabase(File('${temp.path}/klara.db')),
    );
    await MetaStore(raw).set(kDbSchemaVersionKey, '99');
    await raw.close();

    final LocalServiceDbImpl stamped = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    try {
      final Result<Map<String, PhotoAnalysis>> result = await stamped
          .loadAnalyses();
      expect(result, isA<Failure<Map<String, PhotoAnalysis>>>());
      // Settings are JSON and version-independent: still served.
      expect(ok(await stamped.loadSettings()), isA<AppSettings>());
    } finally {
      await stamped.dispose();
    }
  });
}
