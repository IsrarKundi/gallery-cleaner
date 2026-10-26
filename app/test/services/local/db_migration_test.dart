// Phase 6.2: JSON -> SQLite migration against the checked-in
// fixtures in test/fixtures/phase6 (all 7 files). Fixtures
// carry one corrupt entry each in analyses, sessions and
// trash, one old-version (pre-fingerprint) analysis, and a
// realistic settings file that migration must not touch.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/json_file_store.dart';
import 'package:klara/services/local/json_migration.dart';
import 'package:klara/services/local/klara_database.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_db_impl.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/local/meta_store.dart';
import 'package:klara/services/local/session_store.dart';
import 'package:klara/services/local/trash_store.dart';
import 'package:klara/services/trash/trash_entry.dart';

T ok<T>(Result<T> result) {
  return result.fold(
    onSuccess: (T value) => value,
    onFailure: (_) => throw StateError('expected Success, got Failure'),
  );
}

const List<String> _fixtureFiles = <String>[
  'klara_sessions.json',
  'klara_trash.json',
  'klara_history.json',
  'klara_settings.json',
  'klara_analyses.json',
  'klara_snoozes.json',
  'klara_completions.json',
];

/// Fixtures live under the package's test dir. `flutter test`
/// runs with the package dir as CWD, but a repo-root invocation
/// is one level up — accept both, and fail loudly otherwise
/// (a silently missing fixture would prove nothing).
File fixtureFile(String name) {
  for (final String candidate in <String>[
    'test/fixtures/phase6/$name',
    'app/test/fixtures/phase6/$name',
  ]) {
    final File file = File(candidate);
    if (file.existsSync()) {
      return file;
    }
  }
  throw StateError('fixture not found: $name');
}

Future<Directory> seededTemp() async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'klara_db_migration_test_',
  );
  for (final String name in _fixtureFiles) {
    await File('${temp.path}/$name')
        .writeAsBytes(await fixtureFile(name).readAsBytes());
  }
  return temp;
}

LocalServiceDbImpl openDb(Directory temp) {
  return LocalServiceDbImpl(directoryResolver: () async => temp);
}

/// A JSON source whose analyses read always fails, to prove a
/// failed migration keeps serving JSON instead of an empty DB.
class _FailingJson extends LocalServiceImpl {
  _FailingJson({required DirectoryResolver directoryResolver})
    : super(directoryResolver: directoryResolver);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return const Failure<Map<String, PhotoAnalysis>>(
      AppFailure(messageKey: AppStrings.errorLocal),
    );
  }
}

void main() {
  test('migrates all 6 stores value-for-value, keeps settings '
      'byte-identical, keeps JSON backups', () async {
    final Directory temp = await seededTemp();
    final List<int> settingsBefore = await File(
      '${temp.path}/klara_settings.json',
    ).readAsBytes();
    final LocalServiceDbImpl service = openDb(temp);
    try {
      final Map<String, PhotoAnalysis> analyses = ok(
        await service.loadAnalyses(),
      );
      final JsonMigrationReport report = service.lastMigrationReport!;
      expect(report.verified, isTrue);
      expect(report.imported, <String, int>{
        'klara_analyses.json': 2,
        'klara_sessions.json': 2,
        'klara_trash.json': 2,
        'klara_history.json': 2,
        'klara_snoozes.json': 2,
        'klara_completions.json': 2,
      });
      expect(report.skipped['klara_analyses.json'], 1);
      expect(report.skipped['klara_sessions.json'], 1);
      expect(report.skipped['klara_trash.json'], 1);
      expect(report.skipped['klara_history.json'], 0);

      expect(analyses.length, 2);
      expect(analyses['a1']!.hash, 123);
      expect(analyses['a1']!.sizeBytes, 1000);
      expect(analyses['a1']!.algorithmVersion, 1);
      // Old-version entry migrates as-is: version 0, null
      // fingerprint — freshness logic treats it stale later.
      expect(analyses['a2']!.algorithmVersion, 0);
      expect(analyses['a2']!.sizeBytes, isNull);
      expect(analyses.containsKey('bad'), isFalse);

      final DeckSession? all = ok(await service.loadSession('all'));
      expect(all!.currentIndex, 4);
      expect(all.marks['b'], DeckMark.delete);
      expect(all.marks['d'], DeckMark.favourite);
      expect(all.favouriteIds, <String>{'d'});
      expect(ok(await service.loadSession('photos'))!.currentIndex, 1);
      expect(ok(await service.loadSession('bad')), isNull);
      expect(ok(await service.listSessions()).length, 2);

      final List<TrashEntry> trash = ok(await service.loadTrashEntries());
      expect(trash.map((TrashEntry e) => e.assetId).toList(), <String>[
        't2',
        't1',
      ]);
      expect(trash.first.sizeBytes, 9000);

      final List<HistoryRecord> history = ok(await service.loadHistory());
      expect(history.length, 2);
      expect(history.first.count, 2);
      expect(history.first.mbFreed, 3.25);

      expect(ok(await service.loadSnoozes()), <String, DateTime>{
        's1': DateTime(2026, 5, 6),
        's2': DateTime(2026, 5, 7),
      });
      expect(ok(await service.loadCompletionDays()), <DateTime>[
        DateTime(2026, 5, 6),
        DateTime(2026, 5, 7),
      ]);

      // Settings untouched, JSON backups retained on disk.
      expect(
        await File('${temp.path}/klara_settings.json').readAsBytes(),
        settingsBefore,
      );
      for (final String name in _fixtureFiles) {
        expect(await File('${temp.path}/$name').exists(), isTrue);
      }
      expect(ok(await service.loadSettings()).theme, ThemePreference.dark);
      expect(ok(await service.loadGoalTargetMb()), 512.0);
      expect(ok(await service.isTutorialSeen()), isTrue);

      // Marker set in the database.
      final KlaraDatabase raw = KlaraDatabase(
        NativeDatabase(File('${temp.path}/klara.db')),
      );
      expect(await MetaStore(raw).get(kDbMigrationCompletedKey), '1');
      await raw.close();
    } finally {
      await service.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('second launch does not re-import', () async {
    final Directory temp = await seededTemp();
    final LocalServiceDbImpl first = openDb(temp);
    await first.loadAnalyses();
    await first.dispose();

    final File sessionsFile = File('${temp.path}/klara_sessions.json');
    final Map<String, dynamic> sessions =
        jsonDecode(await sessionsFile.readAsString()) as Map<String, dynamic>;
    sessions['new'] = <String, dynamic>{
      'filterKey': 'new',
      'currentIndex': 0,
      'marks': <String, dynamic>{},
      'favouriteIds': <dynamic>[],
    };
    await sessionsFile.writeAsString(jsonEncode(sessions));

    final LocalServiceDbImpl second = openDb(temp);
    try {
      await second.loadAnalyses();
      expect(second.lastMigrationReport, isNull);
      expect(ok(await second.loadSession('new')), isNull);
      expect(ok(await second.listSessions()).length, 2);
    } finally {
      await second.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('interrupted import reruns cleanly without duplicating', () async {
    final Directory temp = await seededTemp();
    // Simulate a half-populated database with no marker: one
    // trash row and a stale session, as a crash mid-import
    // could once have left behind.
    final KlaraDatabase raw = KlaraDatabase(
      NativeDatabase(File('${temp.path}/klara.db')),
    );
    await TrashStore(raw).appendAll(<TrashEntry>[
      TrashEntry(
        assetId: 't1',
        typeInt: 1,
        width: 100,
        height: 200,
        sizeBytes: 5000,
        trashedAt: DateTime(2026, 1, 1, 10),
      ),
    ]);
    await SessionStore(raw).save(
      const DeckSession(
        filterKey: 'all',
        currentIndex: 99,
        marks: <String, DeckMark>{},
        favouriteIds: <String>{},
      ),
    );
    await raw.close();

    final LocalServiceDbImpl service = openDb(temp);
    try {
      await service.loadAnalyses();
      expect(service.lastMigrationReport!.verified, isTrue);
      expect(ok(await service.loadTrashEntries()).length, 2);
      expect(ok(await service.loadSession('all'))!.currentIndex, 4);
    } finally {
      await service.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('missing database re-imports from the JSON backup', () async {
    final Directory temp = await seededTemp();
    final LocalServiceDbImpl first = openDb(temp);
    await first.loadAnalyses();
    await first.dispose();
    for (final String suffix in <String>['', '-wal', '-shm']) {
      final File file = File('${temp.path}/klara.db$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }

    final LocalServiceDbImpl second = openDb(temp);
    try {
      expect(ok(await second.loadAnalyses()).length, 2);
      expect(ok(await second.listSessions()).length, 2);
      expect(second.lastMigrationReport!.verified, isTrue);
    } finally {
      await second.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('post-migration database serves all stores with JSON '
      'backups deleted', () async {
    final Directory temp = await seededTemp();
    final LocalServiceDbImpl first = openDb(temp);
    await first.loadAnalyses();
    await first.dispose();
    // The 6.3 claim: after migration, no migrated store reads
    // JSON. Deleting every backup must not lose a single row.
    // (Settings is deliberately excluded: it stays JSON.)
    for (final String name in _fixtureFiles) {
      await File('${temp.path}/$name').delete();
    }

    final LocalServiceDbImpl second = openDb(temp);
    try {
      final Map<String, PhotoAnalysis> analyses = ok(
        await second.loadAnalyses(),
      );
      // No migration ran on this launch: the marker path was
      // taken, so the JSON files were never consulted.
      expect(second.lastMigrationReport, isNull);
      expect(analyses.length, 2);
      expect(analyses['a1']!.hash, 123);
      expect((ok(await second.loadSession('all'))!).currentIndex, 4);
      expect(ok(await second.loadTrashEntries()).length, 2);
      expect(ok(await second.loadHistory()).length, 2);
      expect(ok(await second.loadSnoozes()).length, 2);
      expect(ok(await second.loadCompletionDays()).length, 2);
    } finally {
      await second.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('failed migration keeps serving JSON', () async {
    final Directory temp = await seededTemp();
    final LocalServiceDbImpl service = LocalServiceDbImpl(
      directoryResolver: () async => temp,
      jsonSource: _FailingJson(directoryResolver: () async => temp),
    );
    try {
      final Result<Map<String, PhotoAnalysis>> analyses = await service
          .loadAnalyses();
      expect(analyses, isA<Failure<Map<String, PhotoAnalysis>>>());
      expect(service.lastMigrationReport!.verified, isFalse);
      // Other stores still serve JSON, not an empty database.
      expect(ok(await service.loadSession('all'))!.currentIndex, 4);
      final KlaraDatabase raw = KlaraDatabase(
        NativeDatabase(File('${temp.path}/klara.db')),
      );
      expect(await MetaStore(raw).get(kDbMigrationCompletedKey), isNull);
      await raw.close();
    } finally {
      await service.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });
}
