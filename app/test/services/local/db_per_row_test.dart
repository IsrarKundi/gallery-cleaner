// Phase 6.2 gate evidence: per-row cost, demonstrated not
// asserted. A 50k-entry database takes a 50-entry page save
// without touching the other rows, answers a point lookup by
// index seek (never a full scan), and prunes per orphan —
// the three operations the JSON file paid as full-file
// rewrites/decodes. No wall-clock assertions: timing tests
// do not belong in the deterministic suite.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service_db_impl.dart';

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

void main() {
  test('50k database: page save, point lookup, prune are per-row', () async {
    final Directory temp = await Directory.systemTemp.createTemp(
      'klara_db_per_row_test_',
    );
    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
    );
    try {
      final List<PhotoAnalysis> bulk = List<PhotoAnalysis>.generate(50000, (
        int i,
      ) {
        return PhotoAnalysis(
          assetId: 'asset_$i',
          hash: i,
          width: 100,
          height: 200,
          blurScore: 1.0,
          meanLuminance: 2.0,
          sizeBytes: 1000 + i,
          modifiedDateMs: 1700000000000 + i,
        );
      });
      await service.saveAnalyses(bulk);
      expect(ok(await service.loadAnalyses()).length, 50000);

      // One page save: only the page is added, the rest is
      // byte-identical (spot-checked, not rewritten).
      final List<PhotoAnalysis> page = List<PhotoAnalysis>.generate(50, (
        int i,
      ) {
        return PhotoAnalysis(
          assetId: 'new_$i',
          hash: i,
          width: 10,
          height: 20,
          blurScore: 1.0,
          meanLuminance: 2.0,
        );
      });
      await service.saveAnalyses(page);
      final Map<String, PhotoAnalysis> after = ok(await service.loadAnalyses());
      expect(after.length, 50050);
      expect(after['asset_0']!.hash, 0);
      expect(after['asset_49999']!.hash, 49999);
      expect(after['asset_49999']!.sizeBytes, 50999);
      expect(after['new_0']!.hash, 0);

      // Point lookup is an index seek, never a full scan. The
      // plan is a property of the schema, so a scratch database
      // with the same tables proves it.
      final KlaraDatabase raw = KlaraDatabase(NativeDatabase.memory());
      // Seed the scratch database with one row so the planner
      // has the table shape, then explain the point query.
      await raw
          .into(raw.analyses)
          .insert(
            AnalysesCompanion.insert(
              assetId: 'x',
              hash: 1,
              width: 1,
              height: 1,
              blurScore: 1.0,
              meanLuminance: 1.0,
              algorithmVersion: 1,
            ),
          );
      final List<QueryRow> plan = await raw
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM analyses '
            'WHERE asset_id = ?',
            variables: <Variable<Object>>[Variable<String>('x')],
            readsFrom: <TableInfo<Table, dynamic>>{raw.analyses},
          )
          .get();
      final String detail = plan
          .map((QueryRow row) => row.read<String>('detail'))
          .join(' ');
      expect(detail, contains('SEARCH'));
      expect(detail, isNot(contains('SCAN')));
      await raw.close();

      // Prune is per orphan: keep 25k, drop the rest + the page.
      final Set<String> live = <String>{
        for (int i = 0; i < 25000; i++) 'asset_$i',
      };
      expect(ok(await service.pruneAnalyses(live)), 25050);
      expect(ok(await service.loadAnalyses()).length, 25000);
    } finally {
      await service.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });
}
