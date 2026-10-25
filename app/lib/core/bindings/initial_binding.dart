import 'package:get/get.dart';

import '../../features/settings/controller/settings_controller.dart';
import '../../services/appinfo/app_info_service.dart';
import '../../services/appinfo/app_info_service_impl.dart';
import '../../services/local/local_service.dart';
import '../../services/local/local_service_impl.dart';
import '../../services/media/media_service.dart';
import '../../services/media/media_service_impl.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/notification_service_impl.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_service_impl.dart';
import '../../services/storage/storage_service.dart';
import '../../services/storage/storage_service_impl.dart';
import '../../services/trash/trash_gateway_impl.dart';
import '../../services/video/video_compression_service.dart';
import '../../services/video/video_compression_service_impl.dart';
import '../../services/trash/trash_service.dart';
import '../../services/trash/trash_service_impl.dart';

/// The ONLY place global Get.put lives (AGENTS.md).
///
/// Phase 1 services, registered permanent behind their interfaces so
/// controllers depend on abstractions, never implementations.
/// Order matters: [TrashServiceImpl] takes [LocalService], so the
/// local service is registered first. Phase 3A adds the
/// notification + app-info services and the permanent
/// [SettingsController], whose onInit applies the persisted theme,
/// haptics and (via main.dart's builder) reduced-motion at launch.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LocalService>(LocalServiceImpl(), permanent: true);
    Get.put<MediaService>(MediaServiceImpl(), permanent: true);
    Get.put<StorageService>(StorageServiceImpl(), permanent: true);
    Get.put<ShareService>(ShareServiceImpl(), permanent: true);
    Get.put<NotificationService>(NotificationServiceImpl(), permanent: true);
    Get.put<AppInfoService>(AppInfoServiceImpl(), permanent: true);
    Get.put<VideoCompressionService>(
      VideoCompressionServiceImpl(),
      permanent: true,
    );
    Get.put<TrashService>(
      TrashServiceImpl(
        gateway: TrashGatewayImpl(),
        local: Get.find<LocalService>(),
      ),
      permanent: true,
    );
    Get.put<SettingsController>(
      SettingsController(
        local: Get.find<LocalService>(),
        notifications: Get.find<NotificationService>(),
        appInfo: Get.find<AppInfoService>(),
      ),
      permanent: true,
    );
  }
}
