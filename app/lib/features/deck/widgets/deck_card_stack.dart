import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../settings/controller/settings_controller.dart';
import '../model/thumbnail_preloader.dart';
import 'swipe_card.dart';

/// Card stack (solutions 3.1): the current card on top, with the next
/// 1–2 cards pre-decoded underneath it, so a swipe reveals the next
/// photo with no blank flash and no UI-isolate decode at swipe time.
///
/// The underneath cards are plain photos (no gestures, no exit
/// logic): they exist only to decode early. When the top card swipes
/// away, the next card is already built with the same image provider
/// key (same bytes, same decode size), so the image cache serves it
/// instead of decoding again. The previous card needs no widget: its
/// bytes stay warm in the shared thumbnail service cache, so undo
/// shows it instantly.
///
/// Thumbnail arrivals rebuild only this stack (its own Obx): the
/// parent view reads the queue and index, never the thumbnail maps,
/// so a preload insertion no longer rebuilds the whole deck body.
class DeckCardStack extends StatefulWidget {
  const DeckCardStack({
    super.key,
    required this.current,
    required this.next,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.onSwiped,
    this.onRetry,
    this.onExitStart,
    this.onExitEnd,
  });

  /// The top, interactive card.
  final MediaAsset current;

  /// The next cards, nearest first; at most 2 are rendered.
  final List<MediaAsset> next;

  /// Service-owned bytes for the deck size; read inside the Obx.
  final RxMap<String, Uint8List> thumbnails;

  /// Service-owned failed ids for the deck size.
  final RxSet<String> failedThumbnails;

  /// Top-card swipe commit (see [SwipeCard.onSwiped]).
  final ValueChanged<DeckMark> onSwiped;

  /// Tap-to-retry for a failed top card (see [SwipeCard.onRetry]).
  final VoidCallback? onRetry;

  /// Exit-flight callbacks for the settled-review gate (see
  /// [SwipeCard.onExitStart] / [SwipeCard.onExitEnd]).
  final VoidCallback? onExitStart;
  final VoidCallback? onExitEnd;

  @override
  State<DeckCardStack> createState() => _DeckCardStackState();
}

class _DeckCardStackState extends State<DeckCardStack> {
  final ValueNotifier<Offset> _dragNotifier = ValueNotifier<Offset>(Offset.zero);

  @override
  void didUpdateWidget(DeckCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current.id != widget.current.id) {
      _dragNotifier.value = Offset.zero;
    }
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final SwipeDirections directions = Get.isRegistered<SettingsController>()
          ? Get.find<SettingsController>().swipeDirections
          : SwipeDirections.rightKeepLeftDelete;
      final MediaAsset? second =
          widget.next.isNotEmpty ? widget.next.first : null;
      final MediaAsset? third =
          widget.next.length > 1 ? widget.next[1] : null;
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Deepest first: the second-next card, then the next card,
          // then the background indicator layer, then the interactive top card.
          if (third != null)
            _StackPhoto(
              thumbnail: widget.thumbnails[third.id],
              failed: widget.failedThumbnails.contains(third.id),
            ),
          if (second != null)
            _StackPhoto(
              thumbnail: widget.thumbnails[second.id],
              failed: widget.failedThumbnails.contains(second.id),
            ),
          _DeckBackgroundIndicators(
            dragNotifier: _dragNotifier,
            directions: directions,
          ),
          SwipeCard(
            key: ValueKey<String>(widget.current.id),
            thumbnail: widget.thumbnails[widget.current.id],
            thumbnailFailed: widget.failedThumbnails.contains(widget.current.id),
            swipeDirections: directions,
            dragNotifier: _dragNotifier,
            onSwiped: widget.onSwiped,
            onRetry: widget.onRetry,
            onExitStart: widget.onExitStart,
            onExitEnd: widget.onExitEnd,
          ),
        ],
      );
    });
  }
}

/// Action labels (Keep / Delete) rendered as a separate background layer
/// behind the swipe card (requirements §3 / design §7).
///
/// Anchored to the screen edges (vertically centered) and revealed as the card
/// slides away. Opacity and scale scale with drag progress.
class _DeckBackgroundIndicators extends StatelessWidget {
  const _DeckBackgroundIndicators({
    required this.dragNotifier,
    required this.directions,
  });

  final ValueNotifier<Offset> dragNotifier;
  final SwipeDirections directions;

  static const double _threshold = 80;

  @override
  Widget build(BuildContext context) {
    final bool rightIsKeep = directions == SwipeDirections.rightKeepLeftDelete;

    final Color keepColor = context.palette.success;
    final Color deleteColor = context.palette.error;

    final IconData keepIcon = PhosphorIconsFill.thumbsUp;
    final IconData deleteIcon = PhosphorIconsFill.trash;

    final String keepText = AppStrings.tr(AppStrings.swipeActionKeep);
    final String deleteText = AppStrings.tr(AppStrings.swipeActionDelete);

    // Left indicator: revealed when card translates right (dx > 0).
    final bool leftIsKeep = rightIsKeep;
    final Color leftColor = leftIsKeep ? keepColor : deleteColor;
    final IconData leftIcon = leftIsKeep ? keepIcon : deleteIcon;
    final String leftText = leftIsKeep ? keepText : deleteText;

    // Right indicator: revealed when card translates left (dx < 0).
    final bool rightIsKeepAction = !rightIsKeep;
    final Color rightColor = rightIsKeepAction ? keepColor : deleteColor;
    final IconData rightIcon = rightIsKeepAction ? keepIcon : deleteIcon;
    final String rightText = rightIsKeepAction ? keepText : deleteText;

    return ValueListenableBuilder<Offset>(
      valueListenable: dragNotifier,
      builder: (BuildContext context, Offset offset, Widget? child) {
        final double dx = offset.dx;
        final double leftIntensity = dx > 0
            ? (dx / _threshold).clamp(0.0, 1.0)
            : 0.0;
        final double rightIntensity = dx < 0
            ? (-dx / _threshold).clamp(0.0, 1.0)
            : 0.0;

        if (leftIntensity <= 0.01 && rightIntensity <= 0.01) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (leftIntensity > 0.01)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: context.sizes.md),
                      child: Opacity(
                        opacity: leftIntensity,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * leftIntensity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                leftIcon,
                                size: 64,
                                color: leftColor,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: context.palette.scrim.withValues(
                                      alpha: 0.35,
                                    ),
                                    offset: Offset(0, context.sizes.xxs),
                                    blurRadius: context.sizes.xs,
                                  ),
                                ],
                              ),
                              SizedBox(height: context.sizes.xs),
                              Text(
                                leftText,
                                style: context.textStyles.headlineLarge.copyWith(
                                  color: leftColor,
                                  fontWeight: FontWeight.w800,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: context.palette.scrim.withValues(
                                        alpha: 0.35,
                                      ),
                                      offset: Offset(0, context.sizes.xxs),
                                      blurRadius: context.sizes.xs,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (rightIntensity > 0.01)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: context.sizes.md),
                      child: Opacity(
                        opacity: rightIntensity,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * rightIntensity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                rightIcon,
                                size: 64,
                                color: rightColor,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: context.palette.scrim.withValues(
                                      alpha: 0.35,
                                    ),
                                    offset: Offset(0, context.sizes.xxs),
                                    blurRadius: context.sizes.xs,
                                  ),
                                ],
                              ),
                              SizedBox(height: context.sizes.xs),
                              Text(
                                rightText,
                                style: context.textStyles.headlineLarge.copyWith(
                                  color: rightColor,
                                  fontWeight: FontWeight.w800,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: context.palette.scrim.withValues(
                                        alpha: 0.35,
                                      ),
                                      offset: Offset(0, context.sizes.xxs),
                                      blurRadius: context.sizes.xs,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One pre-decoded card underneath the top card: the photo only, no
/// gestures, no spinner animation (it is hidden behind the top card
/// until revealed). A failed underneath card shows the same static
/// placeholder the top card's failure state uses, minus the retry
/// affordance — retry belongs to the top card once it is revealed.
class _StackPhoto extends StatelessWidget {
  const _StackPhoto({required this.thumbnail, required this.failed});

  final Uint8List? thumbnail;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = this.thumbnail;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.sizes.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (thumbnail != null)
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
          else
            Container(color: context.palette.surfaceVariant),
        ],
      ),
    );
  }
}
