import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../controller/splash_controller.dart';

/// Splash screen (design.md §13): white Phase 1 light background, ink
/// logo version.
///
/// - Motion on: the logo Lottie plays once; its finish completes the
///   splash (the hold timer is fallback only, cancelled on finish).
/// - Reduced motion on (system "Remove animations"): the final frame
///   renders statically as the logo SVG — no Lottie playback — and the
///   hold timer (or a tap) completes the splash.
/// - Tap anywhere skips, cancelling the timer.
///
/// Layout only: all completion logic lives in [SplashController].
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final SplashController _splashController = Get.find<SplashController>();
  late final AnimationController _lottieController = AnimationController(
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _lottieController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _splashController.onLottieFinish();
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: Semantics(
        label: AppStrings.tr(AppStrings.splashSkipLabel),
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _splashController.skip,
          child: Center(
            child: reducedMotion
                ? SvgPicture.asset(
                    'assets/icons/klara_logo.svg',
                    width: context.sizes.splashLogoWidth,
                  )
                : Lottie.asset(
                    'assets/animations/klara_logo_lottie.json',
                    controller: _lottieController,
                    width: context.sizes.splashLogoWidth,
                    height: context.sizes.splashLogoHeight,
                    onLoaded: (LottieComposition composition) {
                      _lottieController
                        ..duration = composition.duration
                        ..forward();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
