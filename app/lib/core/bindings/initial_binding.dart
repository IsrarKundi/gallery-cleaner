import 'package:get/get.dart';

import '../../services/local/local_service.dart';
import '../../services/local/local_service_impl.dart';
import '../../services/media/media_service.dart';
import '../../services/media/media_service_impl.dart';
import '../../services/trash/trash_gateway_impl.dart';
import '../../services/trash/trash_service.dart';
import '../../services/trash/trash_service_impl.dart';

/// The ONLY place global Get.put lives (AGENTS.md).
///
/// Phase 1 services, registered permanent behind their interfaces so
/// controllers depend on abstractions, never implementations.
/// Order matters: [TrashServiceImpl] takes [LocalService], so the
/// local service is registered first.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LocalService>(LocalServiceImpl(), permanent: true);
    Get.put<MediaService>(MediaServiceImpl(), permanent: true);
    Get.put<TrashService>(
      TrashServiceImpl(
        gateway: TrashGatewayImpl(),
        local: Get.find<LocalService>(),
      ),
      permanent: true,
    );
  }
}
