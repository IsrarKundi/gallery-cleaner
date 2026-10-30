// History empty-state picture (fix plan Stage 5, ADR-020
// decision 14): the owner's decided scope — History's empty
// state shows the ref-style calendar picture instead of the
// plain icon.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/history/controller/history_controller.dart';
import 'package:klara/features/history/view/history_view.dart';
import 'package:klara/services/local/local_service.dart';

class _Local extends Fake implements LocalService {
  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);
}

void main() {
  tearDown(Get.reset);

  testWidgets('empty History shows the decided calendar picture', (
    WidgetTester tester,
  ) async {
    Get.put<HistoryController>(HistoryController(local: _Local()));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const HistoryView()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No history yet'), findsOneWidget);
    final SvgPicture picture = tester.widget<SvgPicture>(
      find.byType(SvgPicture),
    );
    final dynamic loader = picture.bytesLoader;
    expect(loader.assetName, 'assets/images/img_empty_history.svg');
  });
}
