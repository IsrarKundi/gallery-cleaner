import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/splash/controller/splash_controller.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/warmup/deck_warm_up.dart';

void main() {
  group('SplashController', () {
    test('Lottie finish cancels the hold timer and completes once', () async {
      int completions = 0;
      final SplashController controller = SplashController(
        onComplete: () => completions++,
        holdDuration: const Duration(milliseconds: 100),
      );
      controller.onInit();
      expect(controller.holdTimerActive, isTrue);
      controller.onLottieFinish();
      expect(controller.completed, isTrue);
      expect(completions, 1);
      expect(controller.holdTimerActive, isFalse);
      // The cancelled timer must not fire a second completion.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(completions, 1);
      controller.onClose();
    });

    test('hold timer fires completion if Lottie never finishes', () async {
      int completions = 0;
      final SplashController controller = SplashController(
        onComplete: () => completions++,
        holdDuration: const Duration(milliseconds: 50),
      );
      controller.onInit();
      expect(controller.completed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.completed, isTrue);
      expect(completions, 1);
      controller.onClose();
    });

    test('skip completes and cancels the hold timer', () async {
      int completions = 0;
      final SplashController controller = SplashController(
        onComplete: () => completions++,
        holdDuration: const Duration(milliseconds: 100),
      );
      controller.onInit();
      controller.skip();
      expect(controller.completed, isTrue);
      expect(completions, 1);
      expect(controller.holdTimerActive, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(completions, 1);
      controller.onClose();
    });

    test(
      'reduced motion exits on the short hold, not the 3.0s timer',
      () async {
        int completions = 0;
        final SplashController controller = SplashController(
          onComplete: () => completions++,
          holdDuration: const Duration(milliseconds: 300),
          reducedMotionHoldDuration: const Duration(milliseconds: 50),
        );
        controller.onInit();
        controller.onReducedMotionShown();
        // The 3.0s-style fallback is cancelled: no completion at 150ms
        // would be wrong — the short hold already fired by then.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(controller.completed, isTrue);
        expect(completions, 1);
        expect(controller.holdTimerActive, isFalse);
        controller.onClose();
      },
    );

    test('reduced motion does not complete before its short hold', () async {
      int completions = 0;
      final SplashController controller = SplashController(
        onComplete: () => completions++,
        holdDuration: const Duration(milliseconds: 300),
        reducedMotionHoldDuration: const Duration(milliseconds: 150),
      );
      controller.onInit();
      controller.onReducedMotionShown();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.completed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(controller.completed, isTrue);
      expect(completions, 1);
      controller.onClose();
    });

    test('reduced-motion signal is idempotent and skippable', () async {
      int completions = 0;
      final SplashController controller = SplashController(
        onComplete: () => completions++,
        holdDuration: const Duration(milliseconds: 300),
        reducedMotionHoldDuration: const Duration(milliseconds: 100),
      );
      controller.onInit();
      controller.onReducedMotionShown();
      controller.onReducedMotionShown();
      controller.skip();
      expect(controller.completed, isTrue);
      expect(completions, 1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(completions, 1);
      controller.onClose();
    });

    test('warm-up starts on init when provided', () async {
      int starts = 0;
      final SplashController controller = SplashController(
        holdDuration: const Duration(milliseconds: 50),
        warmUp: _CountingWarmUp(() => starts++),
      );
      controller.onInit();
      expect(starts, 1);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      controller.onClose();
    });
  });
}

/// Minimal warm-up stand-in: only start() matters here.
class _CountingWarmUp implements DeckWarmUp {
  _CountingWarmUp(this.onStart);

  final void Function() onStart;

  @override
  bool get started => true;

  @override
  void start() => onStart();

  @override
  Future<MediaPermission?> get permission async => null;

  @override
  Future<List<MediaAsset>?> get firstPage async => null;
}
