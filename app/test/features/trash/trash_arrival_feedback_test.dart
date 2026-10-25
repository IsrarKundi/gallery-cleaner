// Phase 3.4: one feedback surface per Trash arrival. When the
// auto-empty prompt is pending, the dialog is the surface and no
// snackbar stacks under it; otherwise the arrival snackbar shows
// alone. No device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/features/trash/view/trash_view.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

TrashEntry _entry(String id, DateTime at) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: 1048576,
    trashedAt: at,
  );
}

/// Local fake with a fixed settings object.
class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  _Local({required this.settings});

  final AppSettings settings;

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return Success<AppSettings>(settings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the arrival test: ${invocation.memberName}',
  );
}

/// Trash fake serving a fixed record list.
class _Trash implements TrashService {
  _Trash(this.records);

  final List<TrashEntry> records;

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return Success<List<TrashEntry>>(records);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the arrival test: ${invocation.memberName}',
  );
}

Future<void> _pump(WidgetTester tester, TrashController controller) async {
  Get.put<TrashController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(theme: AppTheme.light, home: const TrashView()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('pending auto-empty prompt suppresses the snackbar', (
    WidgetTester tester,
  ) async {
    // Expired record (trashed Sep 2026, recoverable until early
    // Oct 2026) + prompt ON = the dialog is pending.
    final TrashController controller = TrashController(
      trash: _Trash(<TrashEntry>[_entry('old', DateTime(2026, 9, 1))]),
      local: _Local(settings: const AppSettings(trashAutoEmptyPrompt: true)),
      arrivalSnackDate: '24 November 2026',
    );
    await _pump(tester, controller);
    expect(
      find.text(AppStrings.tr(AppStrings.trashAutoEmptyPromptTitle)),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no prompt pending shows the arrival snackbar alone', (
    WidgetTester tester,
  ) async {
    final TrashController controller = TrashController(
      trash: _Trash(<TrashEntry>[_entry('new', DateTime(2026, 10, 25))]),
      local: _Local(settings: const AppSettings()),
      arrivalSnackDate: '24 November 2026',
    );
    await _pump(tester, controller);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('24 November 2026'), findsOneWidget);
    expect(
      find.text(AppStrings.tr(AppStrings.trashAutoEmptyPromptTitle)),
      findsNothing,
    );
  });
}
