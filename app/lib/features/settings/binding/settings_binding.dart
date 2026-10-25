// Settings binding (Phase 3A).
//
// The controller is registered permanent in InitialBinding so the
// persisted theme/haptics/reduced-motion apply at launch. This
// binding therefore REUSES that instance when it exists and only
// creates one (for tests / direct navigation) when it does not —
// registering a second controller would double-apply the theme
// and split the settings state.

import 'package:get/get.dart';

import '../../../services/appinfo/app_info_service.dart';
import '../../../services/local/local_service.dart';
import '../../../services/notifications/notification_service.dart';
import '../controller/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    // Phase 1.7: the early return is gone on purpose. The version
    // read now lives on the settings screen (see
    // SettingsController.loadVersion), so every visit must trigger
    // it — including visits that reuse the InitialBinding instance
    // (the normal case), not just first-time creations.
    final SettingsController controller;
    if (Get.isRegistered<SettingsController>()) {
      controller = Get.find<SettingsController>();
    } else {
      controller = SettingsController(
        local: Get.find<LocalService>(),
        notifications: Get.isRegistered<NotificationService>()
            ? Get.find<NotificationService>()
            : null,
        appInfo: Get.isRegistered<AppInfoService>()
            ? Get.find<AppInfoService>()
            : null,
      );
      Get.put<SettingsController>(controller);
    }
    controller.loadVersion();
  }
}
