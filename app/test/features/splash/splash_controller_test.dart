import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/splash/controller/splash_controller.dart';

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
  });
}
