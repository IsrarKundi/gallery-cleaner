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
    if (Get.isRegistered<SettingsController>()) {
      return;
    }
    Get.put<SettingsController>(
      SettingsController(
        local: Get.find<LocalService>(),
        notifications: Get.isRegistered<NotificationService>()
            ? Get.find<NotificationService>()
            : null,
        appInfo: Get.isRegistered<AppInfoService>()
            ? Get.find<AppInfoService>()
            : null,
      ),
    );
  }
}
