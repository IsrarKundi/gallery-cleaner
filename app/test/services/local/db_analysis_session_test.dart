// Phase 6.1: Drift analysis + session stores against an
// in-memory database (no platform channels, no files).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/analysis_store.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/session_store.dart';

PhotoAnalysis analysis(String id, {int hash = 1}) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 100,
    height: 200,
    blurScore: 50.0,
    meanLuminance: 120.0,
    sizeBytes: 1000,
    modifiedDateMs: 1700000000000,
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

  group('AnalysisStore', () {
    test('save/load round-trips values including null fingerprints', () async {
      final AnalysisStore store = AnalysisStore(db);
      await store.saveAll(<PhotoAnalysis>[
        analysis('a'),
        const PhotoAnalysis(
          assetId: 'b',
          hash: 2,
          width: 10,
          height: 20,
          blurScore: 1.0,
          meanLuminance: 2.0,
        ),
      ]);
      final Map<String, PhotoAnalysis> back = await store.loadAll();
      expect(back.length, 2);
      expect(back['a']!.sizeBytes, 1000);
      expect(back['b']!.sizeBytes, null);
      expect(back['b']!.algorithmVersion, 1);
      expect(await store.count(), 2);
    });

    test('re-saving an id replaces it, never duplicates', () async {
      final AnalysisStore store = AnalysisStore(db);
      await store.saveAll(<PhotoAnalysis>[analysis('a', hash: 1)]);
      await store.saveAll(<PhotoAnalysis>[analysis('a', hash: 9)]);
      final Map<String, PhotoAnalysis> back = await store.loadAll();
      expect(back.length, 1);
      expect(back['a']!.hash, 9);
    });

    test('prune removes only orphans and reports the count', () async {
      final AnalysisStore store = AnalysisStore(db);
      await store.saveAll(<PhotoAnalysis>[
        analysis('a'),
        analysis('b'),
        analysis('c'),
      ]);
      expect(await store.prune(<String>{'a'}), 2);
      expect((await store.loadAll()).keys, <String>['a']);
      expect(await store.prune(<String>{}), 1);
      expect(await store.loadAll(), isEmpty);
    });

    test('prune with no orphans removes nothing', () async {
      final AnalysisStore store = AnalysisStore(db);
      await store.saveAll(<PhotoAnalysis>[analysis('a')]);
      expect(await store.prune(<String>{'a'}), 0);
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

    test('a row with unparseable JSON is skipped, never fatal', () async {
      final SessionStore store = SessionStore(db);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              filterKey: 'bad',
              currentIndex: 0,
              marksJson: 'not json',
              favouritesJson: '[]',
            ),
          );
      expect(await store.load('bad'), isNull);
      expect(await store.listAll(), isEmpty);
    });

    test('unknown mark names default to keep, as the file store did', () async {
      final SessionStore store = SessionStore(db);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              filterKey: 'weird',
              currentIndex: 0,
              marksJson: '{"x":"bogus-mark"}',
              favouritesJson: '[]',
            ),
          );
      expect((await store.load('weird'))!.marks['x'], DeckMark.keep);
    });
  });
}
