// TrashController tests with in-memory fakes (no device, no
// MediaStore).
//
// Covers: list ordering newest first; restore single/multi removes
// records (the fake mirrors TrashServiceImpl, which owns record
// removal — verified against the real impl in the contract tests);
// empty success appends freed history and clears records; empty
// denied leaves records untouched and writes no history; restore
// denied leaves records; service failures set the error state.
// Navigation is not asserted (see the review controller tests).

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

TrashEntry entry(String id, int size, DateTime at) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: size,
    trashedAt: at,
  );
}

class FakeLocal implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    trash.addAll(entries);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return Success<List<TrashEntry>>(List<TrashEntry>.of(trash));
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    trash.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    trash.clear();
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return Success<List<HistoryRecord>>(List<HistoryRecord>.of(history));
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

/// Trash fake mirroring TrashServiceImpl's record ownership: restored
/// and emptied ids leave the recorded list; denied ids stay.
class FakeTrash implements TrashService {
  FakeTrash({this.grantedIds, this.failCalls = false});

  final Set<String>? grantedIds;
  final bool failCalls;

  final List<TrashEntry> records = <TrashEntry>[];

  List<String> _confirm(List<String> ids) {
    if (grantedIds == null) {
      return ids;
    }
    return ids.where(grantedIds!.contains).toList();
  }

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    return const Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    if (failCalls) {
      return const Failure<RestoreOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
    final Set<String> known = records.map((TrashEntry e) => e.assetId).toSet();
    final List<String> matched = ids.where(known.contains).toList();
    final List<String> failed = ids
        .where((String id) => !known.contains(id))
        .toList();
    final List<String> restored = _confirm(matched);
    final List<String> denied = matched
        .where((String id) => !restored.contains(id))
        .toList();
    records.removeWhere((TrashEntry e) => restored.contains(e.assetId));
    return Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: restored,
        deniedIds: denied,
        failedIds: failed,
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    if (failCalls) {
      return const Failure<List<TrashEntry>>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
    final List<TrashEntry> sorted = List<TrashEntry>.of(
      records,
    )..sort((TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt));
    return Success<List<TrashEntry>>(sorted);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    if (failCalls) {
      return const Failure<EmptyTrashOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
    final List<String> ids = records.map((TrashEntry e) => e.assetId).toList();
    final List<String> removed = _confirm(ids);
    final List<String> denied = ids
        .where((String id) => !removed.contains(id))
        .toList();
    records.removeWhere((TrashEntry e) => removed.contains(e.assetId));
    return Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: removed,
        deniedIds: denied,
        failedIds: <String>[],
      ),
    );
  }
}

TrashController makeController({
  required FakeTrash trash,
  required FakeLocal local,
}) {
  final TrashController controller = TrashController(
    trash: trash,
    local: local,
  );
  controller.onInit();
  return controller;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('TrashController', () {
    test('lists entries newest first', () async {
      final FakeTrash trash = FakeTrash();
      trash.records.addAll(<TrashEntry>[
        entry('old', 1000, DateTime(2026, 10, 20)),
        entry('new', 2000, DateTime(2026, 10, 25)),
      ]);
      final TrashController controller = makeController(
        trash: trash,
        local: FakeLocal(),
      );
      await controller.init();
      expect(
        controller.entries.map((TrashEntry e) => e.assetId).toList(),
        <String>['new', 'old'],
      );
    });

    test('restore single removes only that record', () async {
      final FakeTrash trash = FakeTrash();
      trash.records.addAll(<TrashEntry>[
        entry('a', 1000, DateTime(2026, 10, 25)),
        entry('b', 2000, DateTime(2026, 10, 25)),
      ]);
      final TrashController controller = makeController(
        trash: trash,
        local: FakeLocal(),
      );
      await controller.init();
      final TrashActionOutcome? outcome = await controller.restore(<String>[
        'a',
      ]);
      expect(outcome, TrashActionOutcome.restored);
      expect(
        controller.entries.map((TrashEntry e) => e.assetId).toList(),
        <String>['b'],
      );
    });

    test('restore all removes every record', () async {
      final FakeTrash trash = FakeTrash();
      trash.records.addAll(<TrashEntry>[
        entry('a', 1000, DateTime(2026, 10, 25)),
        entry('b', 2000, DateTime(2026, 10, 25)),
      ]);
      final TrashController controller = makeController(
        trash: trash,
        local: FakeLocal(),
      );
      await controller.init();
      final TrashActionOutcome? outcome = await controller.restore(<String>[
        'a',
        'b',
      ]);
      expect(outcome, TrashActionOutcome.restored);
      expect(controller.entries, isEmpty);
    });

    test('restore denied leaves records untouched', () async {
      final FakeTrash trash = FakeTrash(grantedIds: <String>{});
      trash.records.addAll(<TrashEntry>[
        entry('a', 1000, DateTime(2026, 10, 25)),
      ]);
      final TrashController controller = makeController(
        trash: trash,
        local: FakeLocal(),
      );
      await controller.init();
      final TrashActionOutcome? outcome = await controller.restore(<String>[
        'a',
      ]);
      expect(outcome, TrashActionOutcome.denied);
      expect(controller.entries.length, 1);
    });

    test('empty success appends freed history and clears records', () async {
      final FakeTrash trash = FakeTrash();
      trash.records.addAll(<TrashEntry>[
        entry('a', 1048576, DateTime(2026, 10, 25)),
        entry('b', 2097152, DateTime(2026, 10, 25)),
      ]);
      final FakeLocal local = FakeLocal();
      final TrashController controller = makeController(
        trash: trash,
        local: local,
      );
      await controller.init();
      final TrashActionOutcome? outcome = await controller.emptyTrash();
      expect(outcome, TrashActionOutcome.emptied);
      expect(controller.entries, isEmpty);
      expect(local.history.length, 1);
      expect(local.history.single.count, 2);
      expect(local.history.single.mbTrashed, 0);
      expect(local.history.single.mbFreed, closeTo(3.0, 0.01));
      expect(controller.lastFreedBytes.value, 3145728);
    });

    test('empty denied leaves records and writes no history', () async {
      final FakeTrash trash = FakeTrash(grantedIds: <String>{});
      trash.records.addAll(<TrashEntry>[
        entry('a', 1000, DateTime(2026, 10, 25)),
      ]);
      final FakeLocal local = FakeLocal();
      final TrashController controller = makeController(
        trash: trash,
        local: local,
      );
      await controller.init();
      final TrashActionOutcome? outcome = await controller.emptyTrash();
      expect(outcome, TrashActionOutcome.denied);
      expect(controller.entries.length, 1);
      expect(local.history, isEmpty);
    });

    test('service failure sets the error state', () async {
      final FakeTrash trash = FakeTrash(failCalls: true);
      final TrashController controller = makeController(
        trash: trash,
        local: FakeLocal(),
      );
      await controller.init();
      expect(controller.errorKey.value, AppStrings.errorTrash);
    });
  });
}
