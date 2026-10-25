import 'package:get/get.dart';

import '../controller/splash_controller.dart';

/// Registers the splash controller (AGENTS.md: controllers are registered
/// ONLY in bindings, never with Get.put inside build()).
class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(SplashController.new);
  }
}
