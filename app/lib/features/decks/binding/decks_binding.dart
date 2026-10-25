// Registers the hub controller with constructor injection (AGENTS.md:
// controllers registered ONLY in bindings). Services come from the
// initial binding, behind their interfaces.

import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../controller/decks_controller.dart';

class DecksBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DecksController>(
      () => DecksController(
        media: Get.find<MediaService>(),
        local: Get.find<LocalService>(),
      ),
    );
  }
}
