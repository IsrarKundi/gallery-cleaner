// Delete-moment celebration (ADR-024).
//
// The 2 s popper Lottie — the finish screen's own popper,
// firing — played once at the moment a delete batch completes,
// immediately before the finish screen. The animation is pure
// decoration: the view reports its end (or its unavailability)
// to the controller, which owns the hand-over. System back
// skips to the finish screen rather than popping the hop
// (the FinishView PopScope pattern), and a tap skips too
// (the SplashView pattern).

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../controller/celebration_controller.dart';

class CelebrationView extends GetView<CelebrationController> {
  const CelebrationView({super.key});

  static const String celebrationAsset =
      'assets/animations/delete_celebration_lottie.json';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.onCelebrationEnd();
        }
      },
      child: AppScaffold(body: _CelebrationPlayer(controller: controller)),
    );
  }
}

/// Owns the Lottie playback (the SplashView player pattern):
/// the composition sets the AnimationController's duration and
/// plays once; completion, an error, or reduced motion is
/// reported to the controller exactly once each.
class _CelebrationPlayer extends StatefulWidget {
  const _CelebrationPlayer({required this.controller});

  final CelebrationController controller;

  @override
  State<_CelebrationPlayer> createState() => _CelebrationPlayerState();
}

class _CelebrationPlayerState extends State<_CelebrationPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
  );

  bool _reducedMotionNotified = false;
  bool _errorNotified = false;

  @override
  void initState() {
    super.initState();
    _animController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.controller.onCelebrationEnd();
      }
    });
  }

  /// Reduced motion (MediaQuery.disableAnimations, which
  /// main.dart derives from the app's reduced-motion setting or
  /// the system setting — the splash contract): no playback at
  /// all, straight to the finish screen. Guarded because
  /// didChangeDependencies runs on every dependency change.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reducedMotionNotified && MediaQuery.disableAnimationsOf(context)) {
      _reducedMotionNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.onCelebrationUnavailable();
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onError() {
    if (_errorNotified) {
      return;
    }
    _errorNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.onCelebrationUnavailable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.controller.onCelebrationEnd,
      child: Center(
        child: Lottie.asset(
          CelebrationView.celebrationAsset,
          controller: _animController,
          width: context.sizes.celebrationAnim,
          onLoaded: (LottieComposition composition) {
            if (!mounted) {
              return;
            }
            _animController
              ..duration = composition.duration
              ..forward();
          },
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                _onError();
                return const SizedBox.shrink();
              },
        ),
      ),
    );
  }
}
