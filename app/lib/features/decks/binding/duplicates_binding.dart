// Registers the duplicates controller with constructor injection
// (AGENTS.md: controllers registered ONLY in bindings).

import 'package:get/get.dart';

import '../../../services/detection/scan_repository.dart';
import '../../../services/lifecycle/app_lifecycle.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../controller/duplicates_controller.dart';

class DuplicatesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DuplicatesController>(
      () => DuplicatesController(
        media: Get.find<MediaService>(),
        local: Get.find<LocalService>(),
        thumbnailService: Get.isRegistered<ThumbnailService>()
            ? Get.find<ThumbnailService>()
            : null,
        scanRepository: Get.isRegistered<ScanRepository>()
            ? Get.find<ScanRepository>()
            : null,
        // Phase 4.4: without a lifecycle service Duplicates
        // behaves exactly as before (no resume handling).
        lifecycle: Get.isRegistered<AppLifecycle>()
            ? Get.find<AppLifecycle>()
            : null,
      ),
    );
  }
}
