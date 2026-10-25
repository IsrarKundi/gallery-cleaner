import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../controller/history_controller.dart';

/// Registers the history controller with constructor injection
/// (AGENTS.md: controllers are registered ONLY in bindings). The
/// service comes from the initial binding, behind its interface.
class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryController>(
      () => HistoryController(local: Get.find<LocalService>()),
    );
  }
}
