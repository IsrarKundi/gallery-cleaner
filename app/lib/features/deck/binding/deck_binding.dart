import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../../../services/trash/trash_service.dart';
import '../controller/deck_controller.dart';

/// Registers the deck controller with constructor injection (AGENTS.md:
/// controllers are registered ONLY in bindings). Services come from
/// the initial binding, behind their interfaces.
class DeckBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeckController>(
      () => DeckController(
        media: Get.find<MediaService>(),
        trash: Get.find<TrashService>(),
        local: Get.find<LocalService>(),
      ),
    );
  }
}
