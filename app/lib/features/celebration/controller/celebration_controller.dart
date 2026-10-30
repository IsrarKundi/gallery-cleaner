// Delete-moment celebration controller (ADR-024).
//
// The hop between a completed delete batch and the finish
// screen: it receives the batch's FinishSummary as its route
// argument, holds it untouched while the view plays the 2 s
// popper animation once, then opens the finish screen with the
// same argument and removes itself when the finish screen
// pops — so the caller's navigation future (the Review branch,
// the deck view's finish watcher) resolves exactly where the
// direct-to-finish navigation resolved before this hop existed,
// and nothing about counting, marks or the summary changes.
//
// Decoration never blocks the landing: reduced motion, a load
// or playback failure, a tap / back skip, and a fallback timer
// all forward to the finish screen the same way.

import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/routes/app_routes.dart';
import '../../finish/model/finish_summary.dart';

class CelebrationController extends GetxController {
  CelebrationController({Duration? fallbackDuration})
    : fallbackDuration =
          fallbackDuration ?? const AppSizes().celebrationFallback;

  /// Never-stuck guarantee: if playback neither completes nor
  /// errors by this long after the hop opens, the finish screen
  /// opens anyway (the splash hold-timer pattern, ADR-024).
  final Duration fallbackDuration;

  /// The batch, forwarded untouched to the finish screen.
  Object? _args;

  bool _forwarded = false;
  bool _closed = false;
  Timer? _fallbackTimer;

  @override
  void onInit() {
    super.onInit();
    _args = Get.arguments;
    if (_args is! FinishSummary) {
      // No batch, no celebration: hand over immediately and
      // let the finish screen's own no-summary fallback run.
      unawaited(Future<void>.microtask(_forward));
      return;
    }
    _fallbackTimer = Timer(fallbackDuration, _forward);
  }

  @override
  void onClose() {
    _closed = true;
    _fallbackTimer?.cancel();
    super.onClose();
  }

  /// The animation played to its end, or the user skipped it
  /// (tap / system back): open the finish screen.
  void onCelebrationEnd() => _forward();

  /// The animation cannot play — reduced motion is on, or the
  /// asset failed to load or play: open the finish screen
  /// instead of blocking on decoration.
  void onCelebrationUnavailable() => _forward();

  Future<void> _forward() async {
    if (_forwarded) {
      return;
    }
    _forwarded = true;
    _fallbackTimer?.cancel();
    await Get.toNamed<dynamic>(AppRoutes.finish, arguments: _args);
    // The finish screen popped (Done / back): remove this hop
    // so the stack — and the original caller's awaited future —
    // ends exactly where it did before the hop existed. When
    // the finish screen instead reset the stack itself (its
    // no-summary fallback), this route is already gone.
    if (!_closed && Get.currentRoute == AppRoutes.celebration) {
      Get.back<dynamic>();
    }
  }
}
