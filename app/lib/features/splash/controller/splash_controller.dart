import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';

/// Splash completion contract (design.md §13).
///
/// Splash completes on Lottie finish. A hold timer is fallback ONLY: it
/// fires completion if Lottie never finishes, and it is cancelled the
/// moment Lottie finishes (cancel-timer pattern) or the user skips.
/// Tap anywhere also completes, cancelling the timer.
///
/// Hold duration: 3000ms ([AppSizes.splashHold]). The Lottie is ~1.67s,
/// so the timer only fires if Lottie playback fails.
///
/// Navigation is NOT done here: [onComplete] is called exactly once and
/// app_pages.dart wires it to the deck route. Splash IS the initial
/// route (main.dart) and all five Phase 1 routes are wired.
class SplashController extends GetxController {
  SplashController({
    this.onComplete,
    this.beforeComplete,
    Duration? holdDuration,
  }) : holdDuration = holdDuration ?? const AppSizes().splashHold;

  /// Called exactly once when the splash completes, however it ends.
  final VoidCallback? onComplete;

  /// Phase 1.7: awaited before [onComplete] fires, if provided.
  /// app_pages wires this to the settings load so the persisted
  /// theme applies before the splash leaves (no flash of the wrong
  /// theme). Null in tests, where completion stays synchronous.
  final Future<void> Function()? beforeComplete;

  /// Fallback duration; see the class doc.
  final Duration holdDuration;

  Timer? _holdTimer;
  bool _completed = false;

  /// True once completion has fired (exactly once, by any path).
  bool get completed => _completed;

  /// True while the fallback timer is still armed.
  bool get holdTimerActive => _holdTimer?.isActive ?? false;

  @override
  void onInit() {
    super.onInit();
    _holdTimer = Timer(holdDuration, _complete);
  }

  @override
  void onClose() {
    cancelHoldTimer();
    super.onClose();
  }

  /// Lottie playback finished: cancel the fallback and complete.
  void onLottieFinish() {
    cancelHoldTimer();
    _complete();
  }

  /// User tapped anywhere: cancel the fallback and complete.
  void skip() {
    cancelHoldTimer();
    _complete();
  }

  /// Cancels the fallback timer without completing. Exposed so the view
  /// and tests can assert the cancel-timer pattern directly.
  void cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  Future<void> _complete() async {
    if (_completed) {
      return;
    }
    _completed = true;
    // Set before awaiting so a second trigger during the wait is
    // still exactly-once. With no gate the body runs synchronously
    // (no await is reached), so un-gated completion timing is
    // unchanged; with a gate, navigation waits for it.
    final Future<void> Function()? gate = beforeComplete;
    if (gate != null) {
      await gate();
    }
    cancelHoldTimer();
    onComplete?.call();
  }
}
