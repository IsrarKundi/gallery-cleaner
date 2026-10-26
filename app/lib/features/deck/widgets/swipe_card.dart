import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../services/local/local_service.dart';
import '../model/swipe_direction.dart';
import '../model/thumbnail_preloader.dart';

/// Full-bleed photo card (design.md §7): 12–16dp corners, thumbnail
/// with loading placeholder and failure state, and PERSISTENT edge
/// labels KEEP (left), DELETE (right), MAYBE (top), FAVOURITE (bottom)
/// that highlight with drag distance.
///
/// Swipe handling is a custom pan drag (solutions 3.2): while
/// dragging, a plain [Transform.translate] follows the finger 1:1 —
/// no implicit animation, no interpolation lag. On release past the
/// threshold, ONE [AnimationController] tween drives transform +
/// opacity together over the motion ladder, so the photo stays
/// visible while it exits (no vanish-then-dead-pause). Below the
/// threshold the card springs back to centre on the same controller.
/// The photo subtree is the animation's cached child, so drag and
/// animation frames never rebuild the image or clip — only the
/// transform, opacity and edge labels re-render. Reduced motion
/// skips the exit animation and marks immediately. The card itself
/// holds no deck logic: it reports the mark and the controller
/// advances the queue.
///
/// Phase 2.5 readiness rule: the card is interactive ONLY when its
/// thumbnail is visible. Behind a spinner (still loading) or a
/// failure state the pan handlers are null, so no mark gesture can
/// land on a photo the user cannot see. A failed card is a dead
/// end without retry, so [onRetry] (when provided) makes the failure
/// state tappable; the controller clears the failed mark and
/// re-fetches the window.
///
/// Phase 3.2 settled-review gate: [onExitStart] fires when an exit
/// animation begins (the swipe is committed) and [onExitEnd] fires
/// when it completes, just before [onSwiped]. Views forward these to
/// the controller so review navigation can defer until no card is
/// mid-flight; reduced-motion marks skip both (nothing is in flight).
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onSwiped,
    this.onRetry,
    this.onExitStart,
    this.onExitEnd,
  });

  /// Thumbnail bytes, or null while still loading.
  final Uint8List? thumbnail;

  /// True when the thumbnail failed to load (error state, not spinner).
  final bool thumbnailFailed;

  /// Called once, after the exit animation, with the swipe's mark.
  final ValueChanged<DeckMark> onSwiped;

  /// Tap-to-retry for the failure state. Null means the failure
  /// state is inert (no dead-end promise without a handler).
  final VoidCallback? onRetry;

  /// Exit animation began (swipe committed, card in flight).
  final VoidCallback? onExitStart;

  /// Exit animation completed, just before [onSwiped].
  final VoidCallback? onExitEnd;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 80;

  Offset _dragOffset = Offset.zero;
  DeckMark? _exiting;
  bool _springing = false;

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const AppSizes().motionSlow,
  );
  late Animation<Offset> _offsetTween = _tweenTo(Offset.zero);
  late Animation<double> _opacityTween = _constantOpacity();

  Animation<Offset> _tweenTo(Offset end) {
    return Tween<Offset>(
      begin: _dragOffset,
      end: end,
    ).animate(CurvedAnimation(parent: _exitController, curve: _easeOut));
  }

  Animation<double> _constantOpacity() {
    return Tween<double>(begin: 1, end: 1).animate(_exitController);
  }

  Cubic get _easeOut => const AppSizes().easeOut;

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    // Grabbing mid-spring-back cancels the spring at its current
    // offset, so the card never jumps back to the drag start.
    if (_springing) {
      _exitController.stop();
      _dragOffset = _offsetTween.value;
      _springing = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_exiting != null || _springing) {
      return;
    }
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_exiting != null || _springing) {
      return;
    }
    final DeckMark? mark = markForDrag(
      _dragOffset.dx,
      _dragOffset.dy,
      _swipeThreshold,
    );
    if (mark == null) {
      // Below threshold: spring back to centre on the same
      // controller (opacity stays 1 — nothing fades on a cancel).
      if (_dragOffset == Offset.zero) {
        return;
      }
      _springing = true;
      _offsetTween = _tweenTo(Offset.zero);
      _opacityTween = _constantOpacity();
      _exitController.forward(from: 0).then((_) {
        // A grab mid-spring stops the controller and clears
        // _springing first: the stale future must not zero the
        // fresh drag offset.
        if (!mounted || !_springing) {
          return;
        }
        setState(() {
          _springing = false;
          _dragOffset = Offset.zero;
        });
      });
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onSwiped(mark);
      return;
    }
    final Size size = MediaQuery.sizeOf(context);
    final double exit = size.width > size.height ? size.width : size.height;
    final Offset target = switch (mark) {
      DeckMark.keep => Offset(-exit, 0),
      DeckMark.delete => Offset(exit, 0),
      DeckMark.maybe => Offset(0, -exit),
      DeckMark.favourite => Offset(0, exit),
    };
    setState(() {
      _exiting = mark;
      _offsetTween = _tweenTo(target);
      _opacityTween = Tween<double>(
        begin: 1,
        end: 0,
      ).animate(CurvedAnimation(parent: _exitController, curve: _easeOut));
    });
    widget.onExitStart?.call();
    _exitController.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      final DeckMark done = mark;
      setState(() {
        _exiting = null;
        _dragOffset = Offset.zero;
      });
      widget.onExitEnd?.call();
      widget.onSwiped(done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = widget.thumbnail;
    // Phase 2.5: only a visible photo is swipeable. A null
    // thumbnail (spinner or failure) disables the pan handlers,
    // so no mark can land on an unseen card.
    final bool visible = thumbnail != null;
    // The photo subtree is the animation's cached child: drag and
    // animation frames re-run only the transform, opacity and
    // edge labels below, never the image or clip.
    final Widget photo = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: visible ? _onPanStart : null,
      onPanUpdate: visible ? _onPanUpdate : null,
      onPanEnd: visible ? _onPanEnd : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (thumbnail != null)
              // Phase 1.6: decode at display size, never larger
              // than the fetched thumbnail (see decode_size.dart).
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int side = decodeSide(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    sourceSize: ThumbnailPreloader.thumbnailSize,
                  );
                  return Image.memory(
                    thumbnail,
                    fit: BoxFit.cover,
                    cacheWidth: side,
                    cacheHeight: side,
                  );
                },
              )
            else if (widget.thumbnailFailed)
              _FailureBody(onRetry: widget.onRetry)
            else
              Container(
                color: context.palette.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _exitController,
      builder: (BuildContext context, Widget? child) {
        final Offset offset = _exiting != null || _springing
            ? _offsetTween.value
            : _dragOffset;
        final double opacity = _exiting != null ? _opacityTween.value : 1;
        return Transform.translate(
          offset: offset,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                child!,
                // Labels ride the same transform + opacity as the
                // photo, and highlight with the effective offset
                // (drag, or exit flight toward the committed mark).
              ],
            ),
          ),
        );
      },
      child: photo,
    );
  }
}

/// Persistent edge labels (requirements §3, design.md §7): plain
/// text at the four edges, always visible, highlighting toward the
/// drag direction — opacity and scale rise with drag distance up to
/// the swipe threshold, and the label's semantic colour replaces
/// white once any highlight is present. Decorative (the action bar
/// carries the same actions accessibly), so semantics are excluded
/// and gestures pass through.
class _EdgeLabels extends StatelessWidget {
  const _EdgeLabels({required this.drag});

  /// Effective card offset: drag offset, or exit-flight offset.
  final Offset drag;

  static const double _threshold = 80;
  static const double _baseOpacity = 0.45;

  double _intensity(double distance) {
    return (distance / _threshold).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final double keep = _intensity(-drag.dx);
    final double delete = _intensity(drag.dx);
    final double maybe = _intensity(-drag.dy);
    final double favourite = _intensity(drag.dy);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: <Widget>[
            _EdgeLabel(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(left: context.sizes.lg),
              text: AppStrings.tr(AppStrings.edgeKeep),
              highlight: keep,
              highlightColor: context.palette.success,
            ),
            _EdgeLabel(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: context.sizes.lg),
              text: AppStrings.tr(AppStrings.edgeDelete),
              highlight: delete,
              highlightColor: context.palette.error,
            ),
            _EdgeLabel(
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: context.sizes.lg),
              text: AppStrings.tr(AppStrings.edgeMaybe),
              highlight: maybe,
              highlightColor: context.palette.warning,
            ),
            _EdgeLabel(
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(bottom: context.sizes.lg),
              text: AppStrings.tr(AppStrings.edgeFavourite),
              highlight: favourite,
              highlightColor: context.palette.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({
    required this.alignment,
    required this.padding,
    required this.text,
    required this.highlight,
    required this.highlightColor,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final String text;

  /// 0 = resting, 1 = at/over the swipe threshold toward this edge.
  final double highlight;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final double opacity =
        _EdgeLabels._baseOpacity + (1 - _EdgeLabels._baseOpacity) * highlight;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: Transform.scale(
          scale: 1 + 0.15 * highlight,
          child: Opacity(
            opacity: opacity,
            child: Text(
              text,
              style: context.textStyles.labelLarge.copyWith(
                color: highlight > 0 ? highlightColor : context.palette.onScrim,
                fontWeight: FontWeight.w800,
                shadows: <Shadow>[
                  Shadow(
                    color: context.palette.scrim.withValues(alpha: 0.6),
                    offset: Offset(0, context.sizes.xxs),
                    blurRadius: context.sizes.xs,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Failure state (Phase 2.5): error icon + a retry label. Tappable
/// only when [onRetry] is provided — a failure card without a retry
/// handler must not promise one.
class _FailureBody extends StatelessWidget {
  const _FailureBody({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget body = Container(
      color: context.palette.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.error,
              size: context.sizes.iconLg,
              color: context.palette.error,
            ),
            SizedBox(height: context.sizes.sm),
            Text(
              AppStrings.tr(AppStrings.errorRetry),
              style: context.textStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
    final VoidCallback? retry = onRetry;
    if (retry == null) {
      return body;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: retry,
      child: body,
    );
  }
}
