// ReviewAskService tests (fix plan Stage 5, ADR-020 decisions
// 6, 10, 11): the one-time seed counts from the app's real
// records; counters move at the real events; the answers mark
// first and hand over second (store prompt with listing
// fallback; feedback via the share sheet, never sent silently).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/review_ask_store.dart';
import 'package:klara/services/review_ask/review_ask.dart';
import 'package:klara/services/review_ask/review_ask_service_impl.dart';
import 'package:klara/services/review_ask/review_gateway.dart';
import 'package:klara/services/share/share_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

class _Local extends Fake implements LocalService {
  List<HistoryRecord> history = <HistoryRecord>[];
  List<TrashEntry> trashEntries = <TrashEntry>[];
  List<DeckSession> sessions = <DeckSession>[];
  List<DateTime> completionDays = <DateTime>[];

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      Success<List<HistoryRecord>>(history);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      Success<List<TrashEntry>>(trashEntries);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      Success<List<DeckSession>>(sessions);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      Success<List<DateTime>>(completionDays);
}

class _Store implements ReviewAskStore {
  ReviewAskState stored = const ReviewAskState();
  int saves = 0;

  @override
  Future<Result<ReviewAskState>> load() async =>
      Success<ReviewAskState>(stored);

  @override
  Future<Result<void>> save(ReviewAskState state) async {
    stored = state;
    saves++;
    return const Success<void>(null);
  }
}

class _Gateway implements ReviewGateway {
  bool available = true;
  int requests = 0;
  int listings = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requests++;
  }

  @override
  Future<void> openStoreListing() async {
    listings++;
  }
}

class _Share extends Fake implements ShareService {
  final List<String> texts = <String>[];

  @override
  Future<Result<void>> shareSummary({
    required String text,
    Uint8List? imagePng,
  }) async {
    texts.add(text);
    return const Success<void>(null);
  }
}

TrashEntry _entry(String id) => TrashEntry(
  assetId: id,
  typeInt: 1,
  width: 10,
  height: 10,
  sizeBytes: 100,
  trashedAt: DateTime(2026, 10, 20),
);

DeckSession _session(String key, int marks) => DeckSession(
  filterKey: key,
  currentIndex: 0,
  marks: <String, DeckMark>{
    for (int i = 0; i < marks; i++) '$key-$i': DeckMark.keep,
  },
  favouriteIds: const <String>{},
);

void main() {
  late _Local local;
  late _Store store;
  late _Gateway gateway;
  late _Share share;
  late ReviewAskServiceImpl service;

  setUp(() {
    local = _Local();
    store = _Store();
    gateway = _Gateway();
    share = _Share();
    service = ReviewAskServiceImpl(
      local: local,
      store: store,
      gateway: gateway,
      share: share,
    );
  });

  group('seeding from real records', () {
    test('counts history + trash for deletes, session marks for '
        'swipes, completion and history days for usage', () async {
      local.history = <HistoryRecord>[
        HistoryRecord(
          date: DateTime(2026, 10, 28, 15),
          count: 5,
          mbTrashed: 0,
          mbFreed: 4,
        ),
        HistoryRecord(
          date: DateTime(2026, 10, 29, 9),
          count: 3,
          mbTrashed: 0,
          mbFreed: 2,
        ),
      ];
      local.trashEntries = <TrashEntry>[_entry('t1'), _entry('t2')];
      local.sessions = <DeckSession>[_session('all', 7), _session('s', 5)];
      local.completionDays = <DateTime>[DateTime(2026, 10, 30)];

      final ReviewAskState state = await service.state();
      expect(state.seeded, isTrue);
      expect(state.totalDeletes, 5 + 3 + 2);
      expect(state.totalSwipes, 12);
      expect(state.usageDays, <DateTime>[
        DateTime(2026, 10, 28),
        DateTime(2026, 10, 29),
        DateTime(2026, 10, 30),
      ]);
      // The seed is persisted, not recomputed per call.
      expect(store.stored.seeded, isTrue);
      expect(store.stored.totalDeletes, 10);
    });

    test('seeding happens once: later record changes do not re-seed', () async {
      local.history = <HistoryRecord>[
        HistoryRecord(
          date: DateTime(2026, 10, 28),
          count: 4,
          mbTrashed: 0,
          mbFreed: 1,
        ),
      ];
      await service.state();
      local.history = <HistoryRecord>[
        HistoryRecord(
          date: DateTime(2026, 10, 29),
          count: 99,
          mbTrashed: 0,
          mbFreed: 50,
        ),
      ];
      final ReviewAskServiceImpl reloaded = ReviewAskServiceImpl(
        local: local,
        store: store,
        gateway: gateway,
        share: share,
      );
      final ReviewAskState state = await reloaded.state();
      expect(state.totalDeletes, 4);
    });
  });

  group('counting at the real events', () {
    test('recordSwipe accumulates and persists', () async {
      await service.recordSwipe();
      await service.recordSwipe();
      final ReviewAskState state = await service.state();
      expect(state.totalSwipes, 2);
      expect(store.stored.totalSwipes, 2);
    });

    test('recordDeleteBatch adds the count and keeps the batch', () async {
      await service.recordDeleteBatch(count: 7, bytes: 7000);
      await service.recordDeleteBatch(count: 5, bytes: 5000);
      final ReviewAskState state = await service.state();
      expect(state.totalDeletes, 12);
      expect(state.lastBatchCount, 5);
      expect(state.lastBatchBytes, 5000);
    });

    test('an empty batch counts nothing and keeps the last batch', () async {
      await service.recordDeleteBatch(count: 3, bytes: 3000);
      await service.recordDeleteBatch(count: 0, bytes: 0);
      final ReviewAskState state = await service.state();
      expect(state.totalDeletes, 3);
      expect(state.lastBatchCount, 3);
    });

    test('recordUsageDay dedupes within a day', () async {
      await service.recordUsageDay(DateTime(2026, 10, 30, 8));
      await service.recordUsageDay(DateTime(2026, 10, 30, 22));
      await service.recordUsageDay(DateTime(2026, 10, 31));
      final ReviewAskState state = await service.state();
      expect(state.usageDays.length, 2);
    });

    test('the delete ask becomes due by counting real batches', () async {
      expect(await service.isDue(ReviewAskPlace.delete), isFalse);
      await service.recordDeleteBatch(count: 10, bytes: 1);
      expect(await service.isDue(ReviewAskPlace.delete), isFalse);
      await service.recordDeleteBatch(count: 1, bytes: 1);
      expect(await service.isDue(ReviewAskPlace.delete), isTrue);
    });

    test(
      'shown then dismissed re-arms at double through the service',
      () async {
        await service.recordDeleteBatch(count: 15, bytes: 1);
        expect(await service.isDue(ReviewAskPlace.delete), isTrue);
        await service.markShown(ReviewAskPlace.delete);
        await service.markDismissed(ReviewAskPlace.delete);
        expect(await service.isDue(ReviewAskPlace.delete), isFalse);
        await service.recordDeleteBatch(count: 6, bytes: 1);
        expect(await service.isDue(ReviewAskPlace.delete), isTrue);
      },
    );
  });

  group('answers', () {
    test('review: marks answered, then requests the store dialog', () async {
      await service.answerWithReview();
      expect(gateway.requests, 1);
      expect(gateway.listings, 0);
      expect(store.stored.answered, ReviewAnswer.review);
      expect(await service.isDue(ReviewAskPlace.swipe), isFalse);
    });

    test('review: unavailable dialog falls back to the listing', () async {
      gateway.available = false;
      await service.answerWithReview();
      expect(gateway.requests, 0);
      expect(gateway.listings, 1);
      expect(store.stored.answered, ReviewAnswer.review);
    });

    test('feedback: marks answered and hands the text to the '
        'share sheet — nothing is sent anywhere else', () async {
      await service.answerWithFeedback('The deck feels slow');
      expect(store.stored.answered, ReviewAnswer.feedback);
      expect(share.texts, <String>['The deck feels slow']);
      expect(gateway.requests, 0);
      expect(gateway.listings, 0);
    });
  });

  group('fallback amount', () {
    test('prefers the last batch bytes', () async {
      local.history = <HistoryRecord>[
        HistoryRecord(
          date: DateTime(2026, 10, 28),
          count: 9,
          mbTrashed: 0,
          mbFreed: 100,
        ),
      ];
      await service.recordDeleteBatch(count: 2, bytes: 2048);
      expect(await service.fallbackAmountBytes(), 2048);
    });

    test('falls back to lifetime freed bytes from history', () async {
      local.history = <HistoryRecord>[
        HistoryRecord(
          date: DateTime(2026, 10, 28),
          count: 9,
          mbTrashed: 0,
          mbFreed: 1.5,
        ),
      ];
      expect(await service.fallbackAmountBytes(), (1.5 * 1048576).round());
    });

    test('zero when nothing was ever freed or batched', () async {
      expect(await service.fallbackAmountBytes(), 0);
    });
  });
}
