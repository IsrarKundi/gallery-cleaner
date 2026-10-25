import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/trash/trash_service.dart';
import '../controller/trash_controller.dart';

/// Registers the trash controller with constructor injection
/// (AGENTS.md: controllers are registered ONLY in bindings). Services
/// come from the initial binding, behind their interfaces. The
/// arrival-snackbar date travels as route arguments from review; the
/// controller re-resolves it on init.
class TrashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TrashController>(
      () => TrashController(
        trash: Get.find<TrashService>(),
        local: Get.find<LocalService>(),
        arrivalSnackDate: _routeSnackDate(),
      ),
    );
  }

  String? _routeSnackDate() {
    try {
      final dynamic args = Get.arguments;
      if (args is String) {
        return args;
      }
    } catch (_) {
      // No route yet; the controller falls back on init.
    }
    return null;
  }
}
