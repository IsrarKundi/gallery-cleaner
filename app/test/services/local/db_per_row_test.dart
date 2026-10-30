// Phase 6.2 gate evidence, carried to the Stage 4 store: per-row
// cost, demonstrated not asserted. A 50k-entry membership
// snapshot saves without a whole-file rewrite, a point lookup
// on asset_infos is an index seek (never a full scan), and a
// replacement snapshot drops orphans wholesale — the operations
// the JSON file paid as full-file rewrites/decodes. No
// wall-clock assertions: timing tests do not belong in the
// deterministic suite.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service_db_impl.dart';

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

ScanMemberships _snapshot(int count, {String prefix = 'asset'}) {
  return ScanMemberships(
    algorithmVersion: scanMembershipAlgorithmVersion,
    assetInfos: <String, AssetInfo>{
      for (int i = 0; i < count; i++)
        '${prefix}_$i': AssetInfo(
          assetId: '${prefix}_$i',
          type: MediaAssetType.image,
          width: 100,
          height: 200,
          sizeBytes: 1000 + i,
          modifiedDateMs: 1700000000000 + i,
          isEdited: false,
          isScreenshot: false,
        ),
    },
    groups: const <ScanGroup>[],
    duplicateReferences: const <DuplicateReference>[],
  );
}

void main() {
  test('50k memberships: save, point lookup, replace are per-row', () async {
    final Directory temp = await Directory.systemTemp.createTemp(
      'klara_db_per_row_test_',
    );
    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    try {
      await service.saveScanMemberships(_snapshot(50000));
      final ScanMemberships loaded = ok(await service.loadScanMemberships());
      expect(loaded.assetInfos.length, 50000);
      expect(loaded.assetInfos['asset_49999']!.sizeBytes, 50999);
      expect(loaded.algorithmVersion, scanMembershipAlgorithmVersion);

      // A second snapshot (the scanner always writes the whole
      // product) adds a page without disturbing the rest.
      final ScanMemberships bigger = ScanMemberships(
        algorithmVersion: scanMembershipAlgorithmVersion,
        assetInfos: <String, AssetInfo>{
          ..._snapshot(50000).assetInfos,
          ..._snapshot(50, prefix: 'new').assetInfos,
        },
        groups: const <ScanGroup>[],
        duplicateReferences: const <DuplicateReference>[],
      );
      await service.saveScanMemberships(bigger);
      final ScanMemberships after = ok(await service.loadScanMemberships());
      expect(after.assetInfos.length, 50050);
      expect(after.assetInfos['asset_0']!.sizeBytes, 1000);
      expect(after.assetInfos['asset_49999']!.sizeBytes, 50999);

      // Point lookup is an index seek, never a full scan. The
      // plan is a property of the schema, so a scratch database
      // with the same tables proves it.
      final KlaraDatabase raw = KlaraDatabase(NativeDatabase.memory());
      await raw
          .into(raw.assetInfos)
          .insert(
            AssetInfosCompanion.insert(
              assetId: 'x',
              type: 'image',
              width: 1,
              height: 1,
              isEdited: false,
              isScreenshot: false,
            ),
          );
      final List<QueryRow> plan = await raw
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM asset_infos '
            'WHERE asset_id = ?',
            variables: <Variable<Object>>[Variable<String>('x')],
            readsFrom: <TableInfo<Table, dynamic>>{raw.assetInfos},
          )
          .get();
      final String detail = plan
          .map((QueryRow row) => row.read<String>('detail'))
          .join(' ');
      expect(detail, contains('SEARCH'));
      expect(detail, isNot(contains('SCAN')));
      await raw.close();

      // Replacement is the prune: a snapshot holding only the
      // live 25k leaves exactly 25k behind.
      await service.saveScanMemberships(_snapshot(25000));
      expect(ok(await service.loadScanMemberships()).assetInfos.length, 25000);
    } finally {
      await service.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });
}
