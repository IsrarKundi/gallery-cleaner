import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../services/notifications/reminder_service.dart';
import '../../../services/review_ask/review_ask_service.dart';
import '../../../services/warmup/deck_warm_up.dart';

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
    Duration? reducedMotionHoldDuration,
    this.warmUp,
    this.reminders,
    this.reviewAsk,
  }) : holdDuration = holdDuration ?? const AppSizes().splashHold,
       reducedMotionHoldDuration =
           reducedMotionHoldDuration ??
           const AppSizes().splashReducedMotionHold;

  /// Called exactly once when the splash completes, however it ends.
  final VoidCallback? onComplete;

  /// Phase 1.7: awaited before [onComplete] fires, if provided.
  /// app_pages wires this to the settings load so the persisted
  /// theme applies before the splash leaves (no flash of the wrong
  /// theme). Null in tests, where completion stays synchronous.
  final Future<void> Function()? beforeComplete;

  /// Phase 2.2: started while the splash plays, so permission +
  /// page 0 overlap the animation instead of following it. Null in
  /// tests, where no warm-up runs.
  final DeckWarmUp? warmUp;

  /// Fix plan Stage 1: refreshed while the splash plays, so the
  /// state reminders are re-planned from the persisted state at
  /// every launch (a state finished since the last plan cancels
  /// its reminder here). Fire-and-forget like the warm-up: it
  /// never gates or delays completion. Null in tests.
  final ReminderService? reminders;

  /// Fix plan Stage 5: today's usage day is recorded for the
  /// home review ask at every launch, fire-and-forget in the
  /// same way. Null in tests.
  final ReviewAskService? reviewAsk;

  /// Fallback duration; see the class doc.
  final Duration holdDuration;

  /// Reduced-motion hold (solutions 2.2): no Lottie runs, so the
  /// 3.0s fallback would be the whole wait. A short hold lets the
  /// brand mark register, then completes — far below the fallback.
  final Duration reducedMotionHoldDuration;

  Timer? _holdTimer;
  Timer? _reducedMotionTimer;
  bool _reducedMotionArmed = false;
  bool _completed = false;

  /// True once completion has fired (exactly once, by any path).
  bool get completed => _completed;

  /// True while the fallback timer is still armed.
  bool get holdTimerActive => _holdTimer?.isActive ?? false;

  @override
  void onInit() {
    super.onInit();
    // Phase 2.2: overlap the deck's critical path with the splash.
    // The animation itself is not shortened; this only starts the
    // work early so the deck can join it.
    warmUp?.start();
    // Stage 1: same overlap for the reminder re-plan (see the
    // [reminders] field doc). refresh() never throws.
    unawaited(reminders?.refresh() ?? Future<void>.value());
    // Stage 5: record today's usage day (see [reviewAsk]).
    final ReviewAskService? ask = reviewAsk;
    if (ask != null) {
      unawaited(ask.recordUsageDay(DateTime.now()));
    }
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

  /// Reduced-motion splash shown (static logo, no Lottie): cancel
  /// the 3.0s fallback and complete after the short hold instead.
  /// Idempotent — the view may rebuild and call this again.
  void onReducedMotionShown() {
    if (_completed || _reducedMotionArmed) {
      return;
    }
    _reducedMotionArmed = true;
    cancelHoldTimer();
    _reducedMotionTimer = Timer(reducedMotionHoldDuration, _complete);
  }

  /// Cancels the fallback timer (and any reduced-motion hold timer)
  /// without completing. Exposed so the view and tests can assert
  /// the cancel-timer pattern directly.
  void cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _reducedMotionTimer?.cancel();
    _reducedMotionTimer = null;
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
