import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controller/splash_controller.dart';

/// Registers the splash controller (AGENTS.md: controllers are registered
/// ONLY in bindings, never with Get.put inside build()).
///
/// [onComplete] is wired by app_pages.dart to the deck route; it stays
/// optional so the controller can still be used standalone in tests.
class SplashBinding extends Bindings {
  SplashBinding({this.onComplete});

  final VoidCallback? onComplete;

  @override
  void dependencies() {
    Get.lazyPut<SplashController>(
      () => SplashController(onComplete: onComplete),
    );
  }
}
