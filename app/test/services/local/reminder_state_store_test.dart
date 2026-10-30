// ReminderStateStore tests (fix plan Stage 1): the record
// round-trips through its own JSON file in a temp directory
// (the real implementation, never platform channels), a fresh
// store reads as an empty record, and a save replaces — never
// merges with — the previous record.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/reminder_state_store_impl.dart';
import 'package:klara/services/notifications/reminder.dart';

void main() {
  late Directory dir;
  late ReminderStateStoreImpl store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('klara_reminders');
    store = ReminderStateStoreImpl(directoryResolver: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  ReminderRecord unwrap(Result<ReminderRecord> result) {
    return result.fold(
      onSuccess: (ReminderRecord value) => value,
      onFailure: (_) => throw StateError('load failed'),
    );
  }

  test('a fresh store reads as an empty record', () async {
    final ReminderRecord record = unwrap(await store.load());
    expect(record.tracks, isEmpty);
  });

  test('save then load round-trips the record from disk', () async {
    final ReminderRecord record = ReminderRecord(
      tracks: <ReminderStateKind, ReminderTrack>{
        ReminderStateKind.waiting: ReminderTrack(
          startedAt: DateTime(2026, 11, 2, 10),
          sentCount: 1,
          planned: <int, DateTime>{1: DateTime(2026, 11, 6, 19)},
        ),
        ReminderStateKind.neverSwiped: ReminderTrack(
          startedAt: DateTime(2026, 11, 1, 9),
        ),
      },
    );
    final Result<void> saved = await store.save(record);
    expect(saved.isSuccess, isTrue);

    // A second instance over the same directory proves the
    // record really came from the file, not a shared snapshot.
    final ReminderStateStoreImpl other = ReminderStateStoreImpl(
      directoryResolver: () async => dir,
    );
    final ReminderRecord loaded = unwrap(await other.load());
    expect(loaded.tracks.keys, record.tracks.keys);
    final ReminderTrack waiting = loaded.tracks[ReminderStateKind.waiting]!;
    expect(waiting.startedAt, DateTime(2026, 11, 2, 10));
    expect(waiting.sentCount, 1);
    expect(waiting.planned, <int, DateTime>{1: DateTime(2026, 11, 6, 19)});
  });

  test('a save replaces the previous record wholesale', () async {
    await store.save(
      ReminderRecord(
        tracks: <ReminderStateKind, ReminderTrack>{
          ReminderStateKind.waiting: ReminderTrack(
            startedAt: DateTime(2026, 11, 2, 10),
          ),
        },
      ),
    );
    await store.save(const ReminderRecord());
    final ReminderRecord loaded = unwrap(await store.load());
    expect(loaded.tracks, isEmpty);
  });
}
