// ReviewAskStore tests (fix plan Stage 5): the record
// round-trips through its own JSON file in a temp directory
// (the real implementation, never platform channels), a fresh
// store reads as the unseeded default, and a save replaces —
// never merges with — the previous record.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/review_ask_store_impl.dart';
import 'package:klara/services/review_ask/review_ask.dart';

void main() {
  late Directory dir;
  late ReviewAskStoreImpl store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('klara_review_ask');
    store = ReviewAskStoreImpl(directoryResolver: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  ReviewAskState unwrap(Result<ReviewAskState> result) {
    return result.fold(
      onSuccess: (ReviewAskState value) => value,
      onFailure: (_) => throw StateError('load failed'),
    );
  }

  test('a fresh store reads as the unseeded default record', () async {
    final ReviewAskState state = unwrap(await store.load());
    expect(state.seeded, isFalse);
    expect(state.totalSwipes, 0);
    expect(state.totalDeletes, 0);
  });

  test('save then load round-trips the record from disk', () async {
    final ReviewAskState state = ReviewAskState(
      seeded: true,
      totalSwipes: 64,
      totalDeletes: 12,
      usageDays: <DateTime>[DateTime(2026, 10, 29), DateTime(2026, 10, 30)],
      deleteShown: 1,
      lastBatchCount: 12,
      lastBatchBytes: 987654,
    );
    expect((await store.save(state)).isSuccess, isTrue);

    // A second instance over the same directory proves the
    // record really came from the file, not a shared snapshot.
    final ReviewAskStoreImpl other = ReviewAskStoreImpl(
      directoryResolver: () async => dir,
    );
    final ReviewAskState back = unwrap(await other.load());
    expect(back.seeded, isTrue);
    expect(back.totalSwipes, 64);
    expect(back.totalDeletes, 12);
    expect(back.usageDays, state.usageDays);
    expect(back.deleteShown, 1);
    expect(back.lastBatchBytes, 987654);
  });

  test('a save replaces the previous record wholesale', () async {
    await store.save(
      const ReviewAskState(seeded: true, totalSwipes: 10, totalDeletes: 3),
    );
    await store.save(const ReviewAskState(seeded: true, totalSwipes: 4));
    final ReviewAskState back = unwrap(await store.load());
    expect(back.totalSwipes, 4);
    expect(back.totalDeletes, 0);
  });
}
