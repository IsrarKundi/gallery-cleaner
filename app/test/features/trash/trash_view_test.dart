// TrashView widget tests: list rows with metadata, restore single
// and all, empty-trash confirmation flow, denied explanation, and
// the empty state. Fakes are local to this file (no device).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/features/trash/view/trash_view.dart';
import 'package:klara/features/trash/widgets/trash_row.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

TrashEntry _entry(String id, int size, DateTime at) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: size,
    trashedAt: at,
  );
}

class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return const Success<DeckSession?>(null);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    for (final String id in ids) {
      await setSnooze(id, null);
    }
    return const Success<void>(null);
  }

  @override
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
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

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }
}

/// Trash fake mirroring TrashServiceImpl's record ownership.
class _Trash implements TrashService {
  _Trash({this.grantedIds});

  final Set<String>? grantedIds;

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
    final Set<String> known = records.map((TrashEntry e) => e.assetId).toSet();
    final List<String> matched = ids.where(known.contains).toList();
    final List<String> restored = _confirm(matched);
    final List<String> denied = matched
        .where((String id) => !restored.contains(id))
        .toList();
    records.removeWhere((TrashEntry e) => restored.contains(e.assetId));
    return Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: restored,
        deniedIds: denied,
        failedIds: ids.where((String id) => !known.contains(id)).toList(),
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    final List<TrashEntry> sorted = List<TrashEntry>.of(
      records,
    )..sort((TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt));
    return Success<List<TrashEntry>>(sorted);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
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

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    final List<String> deleted = _confirm(ids);
    final List<String> denied = ids
        .where((String id) => !deleted.contains(id))
        .toList();
    return Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: deleted,
        deniedIds: denied,
        failedIds: <String>[],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, TrashController controller) async {
  Get.put<TrashController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      home: const TrashView(),
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: '/',
          page: () => const Scaffold(body: Text('deck-dummy')),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

TrashController _controller(_Trash trash, _Local local) {
  trash.records.addAll(<TrashEntry>[
    _entry('a', 1048576, DateTime(2026, 10, 25)),
    _entry('b', 2097152, DateTime(2026, 10, 24)),
  ]);
  return TrashController(trash: trash, local: local);
}

void main() {
  tearDown(Get.reset);

  group('TrashView', () {
    testWidgets('shows rows with size and recoverable dates', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _controller(_Trash(), _Local()));
      expect(find.byType(TrashRow), findsNWidgets(2));
      expect(find.text('1 MB'), findsOneWidget);
      expect(find.text('2 MB'), findsOneWidget);
      expect(find.textContaining('Recoverable until'), findsNWidgets(2));
      expect(find.textContaining('Trashed 25 Oct 2026'), findsOneWidget);
    });

    testWidgets('restore single removes the row and snacks', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _controller(_Trash(), _Local()));
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.actionRestore)).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrashRow), findsOneWidget);
      expect(
        find.text(AppStrings.tr(AppStrings.snackRestored)),
        findsOneWidget,
      );
    });

    testWidgets('restore all clears the list and snacks the count', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _controller(_Trash(), _Local()));
      await tester.tap(find.text(AppStrings.tr(AppStrings.trashRestoreAll)));
      await tester.pumpAndSettle();
      expect(find.byType(TrashRow), findsNothing);
      expect(
        find.text(
          AppStrings.tr(AppStrings.snackRestoredMany, <String, String>{
            'count': '2',
          }),
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty trash confirms then empties with feedback', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local();
      await _pump(tester, _controller(_Trash(), local));
      await tester.tap(find.text(AppStrings.tr(AppStrings.trashEmpty)));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.trashEmptyConfirmTitle)),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.tr(AppStrings.trashEmpty)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrashRow), findsNothing);
      expect(
        find.text(AppStrings.tr(AppStrings.trashEmptyTitle)),
        findsOneWidget,
      );
      expect(local.history.length, 1);
      expect(local.history.single.mbFreed, closeTo(3.0, 0.01));
    });

    testWidgets('denied restore shows the explanation', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _controller(_Trash(grantedIds: <String>{}), _Local()),
      );
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.actionRestore)).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.trashDeniedMessage)),
        findsOneWidget,
      );
      expect(find.byType(TrashRow), findsNWidgets(2));
    });

    testWidgets('empty trash shows the empty state', (
      WidgetTester tester,
    ) async {
      await _pump(tester, TrashController(trash: _Trash(), local: _Local()));
      expect(
        find.text(AppStrings.tr(AppStrings.trashEmptyTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.actionBackToDeck)),
        findsOneWidget,
      );
    });
  });
}
