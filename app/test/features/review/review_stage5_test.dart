// Review Stage 5 tests (fix plan Stage 5, ADR-020 decisions
// 1–2, 6): every Review run that permanently deletes photos
// counts them for the review ask — partial runs included — and
// the finish summary carries the run's own count and bytes
// with the freed state (Review deletes are permanent, ADR-014).

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/finish/model/finish_summary.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/review_ask/review_ask_service.dart';
import 'package:klara/services/trash/trash_service.dart';

class _Media extends Fake implements MediaService {}

class _Trash extends Fake implements TrashService {
  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    return Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: List<String>.of(ids),
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }
}

class _Local extends Fake implements LocalService {
  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      const Success<DeckSession?>(null);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      const Success<List<DeckSession>>(<DeckSession>[]);

  @override
  Future<Result<void>> saveSession(DeckSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      const Success<Map<String, DateTime>>(<String, DateTime>{});
}

class _Ask extends Fake implements ReviewAskService {
  final List<({int count, int bytes})> batches = <({int count, int bytes})>[];

  @override
  Future<void> recordDeleteBatch({
    required int count,
    required int bytes,
  }) async {
    batches.add((count: count, bytes: bytes));
  }
}

MediaAsset _asset(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

void main() {
  ReviewController controller(_Ask ask, _Local local) {
    return ReviewController(
      media: _Media(),
      trash: _Trash(),
      local: local,
      initialAssets: <MediaAsset>[_asset('a', 1000), _asset('b', 2000)],
      filterKeyOverride: 'all',
      reviewAsk: ask,
    );
  }

  test('a whole-set delete counts the batch and the finish '
      'summary is the run itself, space freed', () async {
    final _Ask ask = _Ask();
    final ReviewController review = controller(ask, _Local());
    final ReviewDeleteOutcome? outcome = await review.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.deleted);
    expect(review.items, isEmpty);
    expect(ask.batches, <({int count, int bytes})>[(count: 2, bytes: 3000)]);
    final FinishSummary summary = review.finishSummary;
    expect(summary.deletedCount, 2);
    expect(summary.sizeBytes, 3000);
    expect(summary.spaceState, FinishSpaceState.freed);
    expect(summary.recoverableUntil, isNull);
  });

  test('a partial (selection) delete counts its photos too', () async {
    final _Ask ask = _Ask();
    final ReviewController review = controller(ask, _Local());
    final ReviewDeleteOutcome? outcome = await review.deleteSelected(
      onlyIds: <String>['a'],
    );
    expect(outcome, ReviewDeleteOutcome.deleted);
    expect(review.items.map((MediaAsset a) => a.id), <String>['b']);
    expect(ask.batches, <({int count, int bytes})>[(count: 1, bytes: 1000)]);
    expect(review.lastDeletedBytes.value, 1000);
  });
}
