// Trash navigation tests (ADR-011): exits return to the retained
// shell when one is alive (pop, never a rebuild) and fall back to
// a stack reset without one. No device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/shell/controller/shell_controller.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/features/trash/view/trash_view.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

class _Trash implements TrashService {
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by trash navigation tests: ${invocation.memberName}',
  );
}

class _Local implements LocalService {
  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by trash navigation tests: ${invocation.memberName}',
  );
}

/// Pumps a real two-route stack (deck dummy underneath, Trash on
/// top) so pops land somewhere observable. The Trash controller
/// is registered first, like the view test's pump helper.
Future<void> _pump(WidgetTester tester, {bool withShell = false}) async {
  if (withShell) {
    Get.put<ShellController>(ShellController());
  }
  Get.put<TrashController>(TrashController(trash: _Trash(), local: _Local()));
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      initialRoute: '/',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: '/',
          page: () => const Scaffold(body: Text('deck-dummy')),
        ),
        GetPage<dynamic>(name: '/trash', page: () => const TrashView()),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<dynamic>('/trash');
  await tester.pumpAndSettle();
  expect(find.byType(TrashView), findsOneWidget);
}

void main() {
  tearDown(Get.reset);

  group('TrashView navigation', () {
    testWidgets('nav tap pops to the shell deck when a shell is alive', (
      WidgetTester tester,
    ) async {
      await _pump(tester, withShell: true);
      await tester.tap(find.text('Clean'));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
      expect(find.byType(TrashView), findsNothing);
    });

    testWidgets('back button pops to the shell deck when a shell is alive', (
      WidgetTester tester,
    ) async {
      await _pump(tester, withShell: true);
      await tester.tap(find.widgetWithIcon(IconButton, AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
    });

    testWidgets('nav tap resets to the deck without a shell', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('Clean'));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
      expect(find.byType(TrashView), findsNothing);
    });
  });
}
