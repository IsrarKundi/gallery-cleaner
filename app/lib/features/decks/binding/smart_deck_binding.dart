// Registers the smart-deck controller with constructor injection
// (AGENTS.md: controllers registered ONLY in bindings). The launch
// (deck + precomputed assets) travels as route arguments; the
// controller re-resolves it on init, so binding timing can never
// leave it empty (same pattern as the review binding).

import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../controller/smart_deck_controller.dart';
import '../model/smart_deck_launch.dart';

class SmartDeckBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SmartDeckController>(
      () => SmartDeckController(
        media: Get.find<MediaService>(),
        local: Get.find<LocalService>(),
        initialLaunch: _routeLaunch(),
        thumbnailService: Get.isRegistered<ThumbnailService>()
            ? Get.find<ThumbnailService>()
            : null,
      ),
    );
  }

  SmartDeckLaunch? _routeLaunch() {
    try {
      final dynamic args = Get.arguments;
      if (args is SmartDeckLaunch) {
        return args;
      }
    } catch (_) {
      // No route yet; the controller falls back on init.
    }
    return null;
  }
}
