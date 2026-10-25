import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/splash/controller/splash_controller.dart';
import 'package:klara/features/splash/view/splash_view.dart';
import 'package:lottie/lottie.dart';

void main() {
  group('SplashView reduced motion', () {
    late SplashController controller;

    setUp(() {
      controller = SplashController(holdDuration: const Duration(hours: 1));
      Get.put<SplashController>(controller);
    });

    tearDown(Get.reset);

    testWidgets('renders the static logo SVG, no Lottie, tap skips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const SplashView(),
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(LottieBuilder), findsNothing);
      expect(controller.completed, isFalse);
      await tester.tap(find.byType(SplashView));
      expect(controller.completed, isTrue);
    });
  });
}
