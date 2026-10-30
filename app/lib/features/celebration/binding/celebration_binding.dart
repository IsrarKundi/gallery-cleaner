// Celebration route binding (ADR-024). The controller needs
// no services: it holds the route argument and owns the
// hand-over timing.

import 'package:get/get.dart';

import '../controller/celebration_controller.dart';

class CelebrationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CelebrationController>(CelebrationController.new);
  }
}
