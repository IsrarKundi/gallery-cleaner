// Trash empty-state picture (fix plan Stage 5, ADR-020
// decision 14): the owner's decided scope — Trash's empty state
// shows the ref-style bin picture instead of the plain icon.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/features/trash/view/trash_view.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

class _Trash extends Fake implements TrashService {
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);
}

class _Local extends Fake implements LocalService {
  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());
}

void main() {
  tearDown(Get.reset);

  testWidgets('empty Trash shows the decided bin picture', (
    WidgetTester tester,
  ) async {
    Get.put<TrashController>(TrashController(trash: _Trash(), local: _Local()));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const TrashView()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trash is empty'), findsOneWidget);
    final SvgPicture picture = tester.widget<SvgPicture>(
      find.byType(SvgPicture),
    );
    final dynamic loader = picture.bytesLoader;
    expect(loader.assetName, 'assets/images/img_empty_trash.svg');
  });
}
