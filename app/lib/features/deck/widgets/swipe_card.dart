import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/local/local_service.dart';
import '../model/swipe_direction.dart';

/// Full-bleed photo card (design.md §7): 12–16dp corners, thumbnail
/// with loading placeholder and failure state, and PERSISTENT edge
/// labels KEEP (left), DELETE (right), MAYBE (top), FAVOURITE (bottom)
/// that highlight with drag distance.
///
/// Swipe handling is a custom pan drag: beyond the threshold the card
/// exits on transform + opacity only (motion ladder, ease-out, no
/// bounce, no celebrations). Below the threshold it springs back.
/// Reduced motion skips the exit animation and marks immediately.
/// The card itself holds no deck logic: it reports the mark and the
/// controller advances the queue.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.thumbnail,
    required this.thumbnailFailed,
    required this.onSwiped,
  });

  /// Thumbnail bytes, or null while still loading.
  final Uint8List? thumbnail;

  /// True when the thumbnail failed to load (error state, not spinner).
  final bool thumbnailFailed;

  /// Called once, after the exit animation, with the swipe's mark.
  final ValueChanged<DeckMark> onSwiped;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  static const double _swipeThreshold = 80;

  Offset _offset = Offset.zero;
  DeckMark? _exiting;

  double _progressFor(DeckMark mark) {
    switch (mark) {
      case DeckMark.keep:
        return (-_offset.dx / _swipeThreshold).clamp(0, 1).toDouble();
      case DeckMark.delete:
        return (_offset.dx / _swipeThreshold).clamp(0, 1).toDouble();
      case DeckMark.maybe:
        return (-_offset.dy / _swipeThreshold).clamp(0, 1).toDouble();
      case DeckMark.favourite:
        return (_offset.dy / _swipeThreshold).clamp(0, 1).toDouble();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_exiting != null) {
      return;
    }
    setState(() {
      _offset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_exiting != null) {
      return;
    }
    final DeckMark? mark = markForDrag(_offset.dx, _offset.dy, _swipeThreshold);
    if (mark == null) {
      // Below threshold: spring back to centre.
      setState(() {
        _offset = Offset.zero;
      });
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onSwiped(mark);
      return;
    }
    final Size size = MediaQuery.sizeOf(context);
    final double exit = size.width > size.height ? size.width : size.height;
    setState(() {
      _exiting = mark;
      switch (mark) {
        case DeckMark.keep:
          _offset = Offset(-exit, 0);
        case DeckMark.delete:
          _offset = Offset(exit, 0);
        case DeckMark.maybe:
          _offset = Offset(0, -exit);
        case DeckMark.favourite:
          _offset = Offset(0, exit);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool exiting = _exiting != null;
    final Uint8List? thumbnail = widget.thumbnail;
    return AnimatedContainer(
      duration: exiting ? context.sizes.motionSlow : context.sizes.motionNormal,
      curve: context.sizes.easeOut,
      transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0),
      onEnd: () {
        final DeckMark? mark = _exiting;
        if (mark != null) {
          _exiting = null;
          widget.onSwiped(mark);
        }
      },
      child: Opacity(
        opacity: exiting ? 0 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.sizes.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (thumbnail != null)
                  Image.memory(thumbnail, fit: BoxFit.cover)
                else if (widget.thumbnailFailed)
                  Container(
                    color: context.palette.surfaceVariant,
                    child: Icon(
                      AppIcons.error,
                      size: context.sizes.iconLg,
                      color: context.palette.error,
                    ),
                  )
                else
                  Container(
                    color: context.palette.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                _EdgeLabel(
                  alignment: Alignment.centerLeft,
                  label: AppStrings.tr(AppStrings.edgeKeep),
                  background: context.palette.successBg,
                  progress: _progressFor(DeckMark.keep),
                ),
                _EdgeLabel(
                  alignment: Alignment.centerRight,
                  label: AppStrings.tr(AppStrings.edgeDelete),
                  background: context.palette.errorBg,
                  progress: _progressFor(DeckMark.delete),
                ),
                _EdgeLabel(
                  alignment: Alignment.topCenter,
                  label: AppStrings.tr(AppStrings.edgeMaybe),
                  background: context.palette.warningBg,
                  progress: _progressFor(DeckMark.maybe),
                ),
                _EdgeLabel(
                  alignment: Alignment.bottomCenter,
                  label: AppStrings.tr(AppStrings.edgeFavourite),
                  background: context.palette.primaryContainer,
                  progress: _progressFor(DeckMark.favourite),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One persistent edge label. Always visible; drag distance towards
/// its edge raises its opacity so the swipe target highlights.
class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({
    required this.alignment,
    required this.label,
    required this.background,
    required this.progress,
  });

  final Alignment alignment;
  final String label;
  final Color background;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.all(context.sizes.lg),
        child: Opacity(
          opacity: 0.6 + (0.4 * progress),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.md,
              vertical: context.sizes.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(context.sizes.pill),
              border: Border.all(color: context.palette.border),
            ),
            child: Text(label, style: context.textStyles.labelMedium),
          ),
        ),
      ),
    );
  }
}
