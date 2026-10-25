import 'package:get/get.dart';

import '../../../services/media/media_service.dart';
import '../../../services/video/video_compression_service.dart';
import '../controller/compress_controller.dart';

/// Registers the compress controller with constructor injection
/// (AGENTS.md: controllers are registered ONLY in bindings).
class CompressBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CompressController>(
      () => CompressController(
        media: Get.find<MediaService>(),
        video: Get.find<VideoCompressionService>(),
      ),
    );
  }
}
