import 'package:get/get.dart';

import '../../../services/lifecycle/app_lifecycle.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/thumbnail/thumbnail_service.dart';
import '../../../services/trash/trash_service.dart';
import '../../../services/warmup/deck_warm_up.dart';
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
        warmUp: Get.isRegistered<DeckWarmUp>() ? Get.find<DeckWarmUp>() : null,
        thumbnailService: Get.isRegistered<ThumbnailService>()
            ? Get.find<ThumbnailService>()
            : null,
        // Optional: without a share backend the finished summary
        // simply shows no share button (never a dead action).
        share: Get.isRegistered<ShareService>()
            ? Get.find<ShareService>()
            : null,
        // Phase 4.4: without a lifecycle service the deck behaves
        // exactly as before (no resume handling).
        lifecycle: Get.isRegistered<AppLifecycle>()
            ? Get.find<AppLifecycle>()
            : null,
      ),
    );
  }
}
