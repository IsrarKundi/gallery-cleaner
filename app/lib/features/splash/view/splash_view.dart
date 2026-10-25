import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../controller/splash_controller.dart';

/// Splash screen (design.md §13, Phase 3A theme adaptation).
///
/// The background comes from the active palette and the brand assets
/// follow the brightness: dark mode → dark background + white logo
/// SVG + white Lottie variant; light (or system-light) → white
/// background + ink logo + normal Lottie. The white assets already
/// existed (Phase 1); this increment wires them, it does not
/// regenerate them.
///
/// - Motion on: the logo Lottie plays once; its finish completes the
///   splash (the hold timer is fallback only, cancelled on finish).
/// - Reduced motion on (system "Remove animations", or the in-app
///   toggle via main.dart's MediaQuery override): the final frame
///   renders statically as the logo SVG — no Lottie playback — and
///   the short reduced-motion hold (or a tap) completes the splash,
///   not the 3.0s fallback.
/// - Tap anywhere skips, cancelling the timer.
///
/// Layout only: all completion logic lives in [SplashController].
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

/// Pure asset selection, unit-tested directly (pumping a Lottie in
/// a widget test would load real animation assets, so the rule
/// itself is tested here, not through the player).
String splashLogoAsset(bool isDark) {
  return isDark
      ? 'assets/icons/klara_logo_white.svg'
      : 'assets/icons/klara_logo.svg';
}

String splashLottieAsset(bool isDark) {
  return isDark
      ? 'assets/animations/klara_logo_lottie_white.json'
      : 'assets/animations/klara_logo_lottie.json';
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

  /// Reduced motion renders the static logo, so no Lottie finish
  /// ever fires: tell the controller once, so it exits on the short
  /// hold instead of the 3.0s fallback (solutions 2.2). Guarded
  /// because didChangeDependencies runs on every theme change too.
  bool _reducedMotionNotified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reducedMotionNotified && MediaQuery.disableAnimationsOf(context)) {
      _reducedMotionNotified = true;
      _splashController.onReducedMotionShown();
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
                    splashLogoAsset(isDark),
                    width: context.sizes.splashLogoWidth,
                  )
                : Lottie.asset(
                    splashLottieAsset(isDark),
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
