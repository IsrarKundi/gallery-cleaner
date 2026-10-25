import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controller/splash_controller.dart';
import '../../../services/warmup/deck_warm_up.dart';

/// Registers the splash controller (AGENTS.md: controllers are registered
/// ONLY in bindings, never with Get.put inside build()).
///
/// [onComplete] is wired by app_pages.dart to the deck route; it stays
/// optional so the controller can still be used standalone in tests.
/// [beforeComplete] (Phase 1.7) is the settings-load gate, also wired
/// by app_pages; null in tests, where completion stays synchronous.
/// Phase 2.2: the controller also starts the deck warm-up, so the
/// splash window overlaps permission + page 0 instead of idling.
class SplashBinding extends Bindings {
  SplashBinding({this.onComplete, this.beforeComplete});

  final VoidCallback? onComplete;
  final Future<void> Function()? beforeComplete;

  @override
  void dependencies() {
    Get.lazyPut<SplashController>(
      () => SplashController(
        onComplete: onComplete,
        beforeComplete: beforeComplete,
        warmUp: Get.isRegistered<DeckWarmUp>() ? Get.find<DeckWarmUp>() : null,
      ),
    );
  }
}
