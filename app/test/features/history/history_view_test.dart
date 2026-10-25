// HistoryView widget tests: rows with date/count/MB, and the empty
// state. Fakes are local to this file (no device).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/history/controller/history_controller.dart';
import 'package:klara/features/history/view/history_view.dart';
import 'package:klara/features/history/widgets/history_row.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

class _Local implements LocalService {
  _Local({this.history = const <HistoryRecord>[]});

  final List<HistoryRecord> history;

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
    final List<HistoryRecord> sorted = List<HistoryRecord>.of(history)
      ..sort((HistoryRecord a, HistoryRecord b) => b.date.compareTo(a.date));
    return Success<List<HistoryRecord>>(sorted);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }
}

Future<void> _pump(WidgetTester tester, HistoryController controller) async {
  Get.put<HistoryController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      home: const HistoryView(),
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

void main() {
  tearDown(Get.reset);

  group('HistoryView', () {
    testWidgets('shows rows newest first with counts and MB', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        HistoryController(
          local: _Local(
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
        ),
      );
      expect(find.byType(HistoryRow), findsNWidgets(2));
      expect(find.text('25 Oct 2026'), findsOneWidget);
      expect(find.text('20 Oct 2026'), findsOneWidget);
      expect(find.text('1 photos · Trashed 0 MB · Freed 5 MB'), findsOneWidget);
      expect(find.text('2 photos · Trashed 3 MB · Freed 0 MB'), findsOneWidget);
    });

    testWidgets('shows the empty state when no history exists', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        HistoryController(local: _Local(history: const <HistoryRecord>[])),
      );
      expect(
        find.text(AppStrings.tr(AppStrings.historyEmptyTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.actionBackToDeck)),
        findsOneWidget,
      );
    });
  });
}
