// Fix plan Stage 3, item 1: every JSON save uses Cleanup's
// atomic pattern — write `<name>.tmp`, flush + sync, rename
// over the target, copy fallback when the rename is refused.
// These tests prove the pattern at the writer level and
// through JsonFileStore (the one write path behind settings,
// the reminder state and the legacy JSON stores).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/local/atomic_file_writer.dart';
import 'package:klara/services/local/json_file_store.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_atomic_test_');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('AtomicFileWriter', () {
    test('write lands the content and leaves no temp file', () async {
      final File target = File('${temp.path}/a.json');
      await const AtomicFileWriter().write(target, '{"a":1}');
      expect(await target.readAsString(), '{"a":1}');
      expect(await File('${target.path}.tmp').exists(), isFalse);
    });

    test('overwrite replaces the old content whole', () async {
      final File target = File('${temp.path}/a.json');
      await target.writeAsString('{"old":"much longer old content"}');
      await const AtomicFileWriter().write(target, '{"b":2}');
      expect(await target.readAsString(), '{"b":2}');
    });

    test(
      'a refused rename falls back to copy and still lands the bytes',
      () async {
        final File target = File('${temp.path}/a.json');
        await target.writeAsString('old');
        final AtomicFileWriter writer = AtomicFileWriter(
          rename: (File tmp, File dest) async =>
              throw const FileSystemException('rename refused'),
        );
        await writer.write(target, 'new content');
        expect(await target.readAsString(), 'new content');
        expect(await File('${target.path}.tmp').exists(), isFalse);
      },
    );
  });

  group('JsonFileStore crash safety', () {
    test('a crash mid-write leaves the old file intact and readable', () async {
      // The state a hard kill leaves behind when it lands
      // between the temp write and the rename: an old intact
      // target plus a half-written .tmp next to it.
      final File target = File('${temp.path}/klara_sessions.json');
      await target.writeAsString('[{"filterKey":"all"}]');
      await File('${target.path}.tmp')
          .writeAsString('[{"filterKey":"al'); // truncated mid-object

      final JsonFileStore store = JsonFileStore(
        fileName: 'klara_sessions.json',
        directoryResolver: () async => temp,
      );
      final List<dynamic> loaded = await store.readList();
      expect(loaded, hasLength(1));
      expect((loaded.single as Map)['filterKey'], 'all');

      // And the next write recovers cleanly over both files.
      loaded.add(<String, dynamic>{'filterKey': 'smart:x'});
      await store.writeNow();
      expect(
        await target.readAsString(),
        '[{"filterKey":"all"},{"filterKey":"smart:x"}]',
      );
      expect(await File('${target.path}.tmp').exists(), isFalse);
    });

    test('store persists through a refused rename (copy fallback)', () async {
      final JsonFileStore store = JsonFileStore(
        fileName: 'klara_settings.json',
        directoryResolver: () async => temp,
        atomicWriter: AtomicFileWriter(
          rename: (File tmp, File dest) async =>
              throw const FileSystemException('rename refused'),
        ),
      );
      final Map<String, dynamic> map = await store.readMap();
      map['goalMb'] = 2048;
      await store.writeNow();
      expect(store.diskWrites, 1);
      final JsonFileStore reread = JsonFileStore(
        fileName: 'klara_settings.json',
        directoryResolver: () async => temp,
      );
      expect((await reread.readMap())['goalMb'], 2048);
    });

    test('when rename AND copy both fail the snapshot stays dirty', () async {
      // Target path occupied by a directory: the rename is
      // refused and the copy has nowhere to land either. The
      // write must fail WITHOUT losing the snapshot — the store
      // keeps it dirty for the next flush instead of pretending
      // the save happened.
      await Directory('${temp.path}/blocked.json').create();
      final JsonFileStore store = JsonFileStore(
        fileName: 'blocked.json',
        directoryResolver: () async => temp,
      );
      final List<dynamic> list = await store.readList();
      list.add(<String, dynamic>{'x': 1});
      await expectLater(store.writeNow(), throwsA(anything));
      store.scheduleWrite();
      expect(store.isDirty, isTrue);
      await store.close();
    });
  });
}
