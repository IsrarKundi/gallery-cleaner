// Registers the All Albums controller with constructor
// injection (AGENTS.md: controllers registered ONLY in
// bindings). Services come from the initial binding, behind
// their interfaces — the same shape as the hub's binding.

import 'package:get/get.dart';

import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../controller/albums_controller.dart';

class AlbumsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AlbumsController>(
      () => AlbumsController(
        media: Get.find<MediaService>(),
        thumbnailService: Get.isRegistered<ThumbnailService>()
            ? Get.find<ThumbnailService>()
            : null,
      ),
    );
  }
}
