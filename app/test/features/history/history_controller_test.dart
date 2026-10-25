// HistoryController tests with an in-memory fake LocalService.
//
// Covers: records load newest first, the empty state (no records),
// and load failure surfacing as the error key. Navigation is not
// asserted (see the review controller tests).

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/history/controller/history_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

class FakeLocal implements LocalService {
  FakeLocal({this.history = const <HistoryRecord>[], this.fail = false});

  final List<HistoryRecord> history;
  final bool fail;

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return const Success<DeckSession?>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    if (fail) {
      return const Failure<List<HistoryRecord>>(
        AppFailure(messageKey: AppStrings.errorLocal),
      );
    }
    final List<HistoryRecord> sorted = List<HistoryRecord>.of(history)
      ..sort((HistoryRecord a, HistoryRecord b) => b.date.compareTo(a.date));
    return Success<List<HistoryRecord>>(sorted);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  final Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};
  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    for (final PhotoAnalysis a in analyses) {
      _analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(_analyses),
    );
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('HistoryController', () {
    test('loads records newest first', () async {
      final HistoryController controller = HistoryController(
        local: FakeLocal(
          history: <HistoryRecord>[
            HistoryRecord(
              date: DateTime(2026, 10, 20),
              count: 2,
              mbTrashed: 3,
              mbFreed: 0,
            ),
            HistoryRecord(
              date: DateTime(2026, 10, 25),
              count: 1,
              mbTrashed: 0,
              mbFreed: 5,
            ),
          ],
        ),
      );
      await controller.init();
      expect(controller.records.length, 2);
      expect(controller.records.first.date, DateTime(2026, 10, 25));
      expect(controller.records.first.mbFreed, 5);
      expect(controller.records.last.mbTrashed, 3);
    });

    test('empty state when no history exists', () async {
      final HistoryController controller = HistoryController(
        local: FakeLocal(history: const <HistoryRecord>[]),
      );
      await controller.init();
      expect(controller.records, isEmpty);
      expect(controller.errorKey.value, isEmpty);
    });

    test('load failure sets the error key', () async {
      final HistoryController controller = HistoryController(
        local: FakeLocal(fail: true),
      );
      await controller.init();
      expect(controller.errorKey.value, AppStrings.errorLocal);
    });
  });
}
