// Registers the duplicates controller with constructor injection
// (AGENTS.md: controllers registered ONLY in bindings).

import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../controller/duplicates_controller.dart';

class DuplicatesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DuplicatesController>(
      () => DuplicatesController(
        media: Get.find<MediaService>(),
        local: Get.find<LocalService>(),
      ),
    );
  }
}
