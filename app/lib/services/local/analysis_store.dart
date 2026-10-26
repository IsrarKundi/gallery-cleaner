// Per-row analysis cache over Drift (solutions 6.1).
//
// Thin wrapper: no [Result] here — the owning service maps
// failures. Batch saves run inside one transaction, so a page
// lands whole or not at all; prune deletes by primary key, so
// its cost is per orphan, never per file.

import 'package:drift/drift.dart';
import 'package:klara/services/detection/photo_analysis.dart';

import 'klara_database.dart';

class AnalysisStore {
  AnalysisStore(this._db);

  final KlaraDatabase _db;

  /// Merges [analyses] into the cache (insert or replace by id).
  Future<void> saveAll(List<PhotoAnalysis> analyses) async {
    if (analyses.isEmpty) {
      return;
    }
    await _db.transaction(() async {
      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.analyses,
          analyses.map(_companion).toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  /// The whole cache, asset id -> analysis.
  Future<Map<String, PhotoAnalysis>> loadAll() async {
    final List<Analyse> rows = await _db.select(_db.analyses).get();
    return <String, PhotoAnalysis>{
      for (final Analyse row in rows) row.assetId: _fromRow(row),
    };
  }

  /// Deletes every cached analysis whose id is NOT in [liveIds]
  /// and returns how many were removed. An empty [liveIds] set
  /// deletes everything (a full scan that found nothing alive).
  /// A delete affecting zero rows writes nothing.
  Future<int> prune(Set<String> liveIds) async {
    if (liveIds.isEmpty) {
      return _db.delete(_db.analyses).go();
    }
    return (_db.delete(
      _db.analyses,
    )..where((Analyses t) => t.assetId.isNotIn(liveIds))).go();
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.analyses.assetId.count();
    final TypedResult row = await (_db.selectOnly(
      _db.analyses,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  AnalysesCompanion _companion(PhotoAnalysis analysis) {
    return AnalysesCompanion.insert(
      assetId: analysis.assetId,
      hash: analysis.hash,
      width: analysis.width,
      height: analysis.height,
      blurScore: analysis.blurScore,
      meanLuminance: analysis.meanLuminance,
      sizeBytes: Value<int?>(analysis.sizeBytes),
      modifiedDateMs: Value<int?>(analysis.modifiedDateMs),
      algorithmVersion: analysis.algorithmVersion,
    );
  }

  PhotoAnalysis _fromRow(Analyse row) {
    return PhotoAnalysis(
      assetId: row.assetId,
      hash: row.hash,
      width: row.width,
      height: row.height,
      blurScore: row.blurScore,
      meanLuminance: row.meanLuminance,
      sizeBytes: row.sizeBytes,
      modifiedDateMs: row.modifiedDateMs,
      algorithmVersion: row.algorithmVersion,
    );
  }
}
