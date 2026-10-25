import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/bindings/initial_binding.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/media/media_service_impl.dart';
import 'package:klara/services/trash/trash_service.dart';
import 'package:klara/services/trash/trash_service_impl.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('InitialBinding registers all three services behind interfaces', () {
    InitialBinding().dependencies();
    expect(Get.find<LocalService>(), isA<LocalServiceImpl>());
    expect(Get.find<MediaService>(), isA<MediaServiceImpl>());
    expect(Get.find<TrashService>(), isA<TrashServiceImpl>());
  });
}
