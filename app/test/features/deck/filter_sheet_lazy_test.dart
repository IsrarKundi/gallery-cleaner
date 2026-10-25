// Phase 3.4: the filter sheet builds its rows lazily — 121 rows
// must not all build when the sheet opens. No device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/widgets/filter_sheet.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_service.dart';

/// Media fake: never called by this test (no init runs).
class _Media implements MediaService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the filter-sheet test: ${invocation.memberName}',
  );
}

/// Local fake: never called by this test.
class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the filter-sheet test: ${invocation.memberName}',
  );
}

/// Trash fake: never called by this test.
class _Trash implements TrashService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the filter-sheet test: ${invocation.memberName}',
  );
}

void main() {
  testWidgets('121 rows build only the visible window', (
    WidgetTester tester,
  ) async {
    final DeckController controller = DeckController(
      media: _Media(),
      trash: _Trash(),
      local: _Local(),
    );
    controller.months.addAll(<String>[
      for (int y = 2021; y <= 2025; y++)
        for (int m = 1; m <= 12; m++) '$y-${m.toString().padLeft(2, '0')}',
    ]);
    controller.albums.addAll(<MediaAlbum>[
      for (int i = 0; i < 60; i++)
        MediaAlbum(id: 'al$i', name: 'Album $i', count: 10),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: FilterSheet(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    final int built = tester.widgetList(find.byType(ListTile)).length;
    // 1 All + 60 months + 60 albums + Clear = 122 rows; only the
    // visible window plus cache extent may build.
    expect(built, greaterThan(0));
    expect(built, lessThan(40));
  });
}
