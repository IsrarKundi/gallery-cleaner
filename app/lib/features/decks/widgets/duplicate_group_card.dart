// One duplicate group (fix plan Stage 7): a header carrying the
// non-keeper count and their total size, then the group's photos
// LARGE, two per row, filling the card width so two versions can
// really be compared.
//
// Tapping any photo makes it the keeper (the user may always pick
// another); the suggested keeper carries a "Keeper" pill on its
// photo. Every non-keeper carries a round selection mark on the
// photo — filled delete-colour check = it will be marked, empty
// circle = spared — and non-keepers start selected. Tapping the
// MARK toggles that one photo; the mark is its own hit target, so
// the two taps never fight. Nothing here deletes and nothing here
// marks: the controller owns the selection, and the screen's one
// sticky button writes the marks (review + native confirmation
// still own removal, requirements §4).

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/decode_size.dart';
import '../../../core/utils/formatters.dart';
import '../controller/duplicates_controller.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/media/media_asset.dart';

class DuplicateGroupCard extends StatefulWidget {
  const DuplicateGroupCard({
    super.key,
    required this.group,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.selectedIds,
    required this.onKeeperTap,
    required this.onToggleSelection,
  });

  final DuplicateGroup group;
  final Map<String, Uint8List> thumbnails;
  final Set<String> failedThumbnails;

  /// Ids of the non-keepers currently selected for marking
  /// (controller-owned screen state, Stage 7).
  final Set<String> selectedIds;
  final ValueChanged<String> onKeeperTap;
  final ValueChanged<String> onToggleSelection;

  /// Brief 3.5: at most this many previews render collapsed.
  static const int previewCap = 20;

  @override
  State<DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<DuplicateGroupCard> {
  /// Collapsed by default (bounded render); expanding reveals
  /// every member. Display state only — picking and marking
  /// still live in the controller.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final DuplicateGroup group = widget.group;
    // Stage 7: the header counts and sizes the NON-KEEPERS only —
    // the same definition as the screen summary, so the numbers
    // on one screen always agree.
    final int nonKeeperBytes = group.nonKeepers.fold<int>(
      0,
      (int sum, MediaAsset a) => sum + a.sizeBytes,
    );
    // Collapsed previews: the first 20 members, plus the keeper
    // when it sits beyond them (its badge must never hide —
    // the mark action covers every non-keeper, seen or not).
    final List<MediaAsset> shown = _expanded
        ? group.assets
        : <MediaAsset>[
            ...group.assets.take(DuplicateGroupCard.previewCap),
            if (group.assets.length > DuplicateGroupCard.previewCap &&
                !group.assets
                    .take(DuplicateGroupCard.previewCap)
                    .any((MediaAsset a) => a.id == group.keeperId))
              group.assets.firstWhere((MediaAsset a) => a.id == group.keeperId),
          ];
    // Members not yet shown (0 when expanded; accounts for the
    // keeper appended above, so the overflow count is exact).
    final int hidden = _expanded ? 0 : group.assets.length - shown.length;
    final List<Widget> cells = <Widget>[
      for (final MediaAsset asset in shown)
        _Thumb(
          asset: asset,
          bytes: widget.thumbnails[asset.id],
          failed: widget.failedThumbnails.contains(asset.id),
          isKeeper: asset.id == group.keeperId,
          selected: widget.selectedIds.contains(asset.id),
          onTap: () => widget.onKeeperTap(asset.id),
          onMarkTap: () => widget.onToggleSelection(asset.id),
        ),
      // Collapsed overflow: tapping reveals every member
      // (the keeper pick must reach members beyond the
      // cap — there is no detail screen to show them).
      if (!_expanded && hidden > 0)
        _OverflowTile(
          hidden: hidden,
          onTap: () => setState(() => _expanded = true),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      ),
      padding: EdgeInsets.all(context.sizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.tr(
                    AppStrings.duplicatesGroupHeader,
                    <String, String>{
                      'count': group.nonKeepers.length.toString(),
                    },
                  ),
                  style: context.textStyles.titleMedium,
                ),
              ),
              Text(
                Formatters.formatBytes(nonKeeperBytes),
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sizes.md),
          // Two per row, filling the card width; bigger groups
          // wrap in the same grid (Stage 7 — no other layout is
          // invented for them).
          Column(
            children: <Widget>[
              for (int i = 0; i < cells.length; i += 2) ...<Widget>[
                if (i > 0) SizedBox(height: context.sizes.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: cells[i]),
                    SizedBox(width: context.sizes.sm),
                    Expanded(
                      child: i + 1 < cells.length
                          ? cells[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The collapsed "+N" cell: reveals the rest of the group.
class _OverflowTile extends StatelessWidget {
  const _OverflowTile({required this.hidden, required this.onTap});

  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.tr(AppStrings.duplicatesShowMore, <String, String>{
        'count': '$hidden',
      }),
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.border),
              borderRadius: BorderRadius.circular(context.sizes.radiusMd),
            ),
            child: Center(
              child: Text('+$hidden', style: context.textStyles.titleMedium),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round selection mark on a non-keeper photo (Stage 7):
/// filled delete-colour circle with a check = this photo will be
/// marked; empty circle over the photo's scrim = spared. Its own
/// 48dp hit target, independent of the photo's keeper tap.
class DuplicateSelectionMark extends StatelessWidget {
  const DuplicateSelectionMark({
    super.key,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: context.sizes.hitArea,
          height: context.sizes.hitArea,
          child: Center(
            child: Container(
              width: context.sizes.selectionMark,
              height: context.sizes.selectionMark,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? context.palette.error : context.palette.scrim,
                border: Border.all(
                  color: selected
                      ? context.palette.error
                      : context.palette.onScrim,
                  width: context.sizes.xxs,
                ),
              ),
              child: selected
                  ? Icon(
                      AppIcons.check,
                      size: context.sizes.iconSm,
                      color: context.palette.onPrimary,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.asset,
    required this.bytes,
    required this.failed,
    required this.isKeeper,
    required this.selected,
    required this.onTap,
    required this.onMarkTap,
  });

  final MediaAsset asset;
  final Uint8List? bytes;
  final bool failed;
  final bool isKeeper;

  /// Only meaningful for non-keepers (the keeper shows no mark).
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMarkTap;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbBytes = bytes;
    // Phase 3B accessibility (design.md §9): a thumbnail button
    // with no text gave TalkBack nothing to announce. The label
    // names the photo (or "Photo" when it has no title) and its
    // action: pick the keeper, or keep this keeper.
    final String label = asset.title.isEmpty
        ? AppStrings.tr(
            isKeeper
                ? AppStrings.a11yThumbKeeperUntitled
                : AppStrings.a11yThumbUntitled,
          )
        : AppStrings.tr(
            isKeeper ? AppStrings.a11yThumbKeeper : AppStrings.a11yThumb,
            <String, String>{'name': asset.title},
          );
    // The selection mark gets its own node in the same voice:
    // state first, then the action tapping it performs.
    final String markLabel = asset.title.isEmpty
        ? AppStrings.tr(
            selected
                ? AppStrings.a11yDuplicateMarkedUntitled
                : AppStrings.a11yDuplicateSparedUntitled,
          )
        : AppStrings.tr(
            selected
                ? AppStrings.a11yDuplicateMarked
                : AppStrings.a11yDuplicateSpared,
            <String, String>{'name': asset.title},
          );
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Phase 1.6: decode at display size, never larger than
          // the fetched thumbnail (see decode_size.dart).
          final int decode = decodeSide(
            width: constraints.maxWidth,
            height: constraints.maxWidth,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            sourceSize: DuplicatesController.thumbnailSize,
          );
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isKeeper
                            ? context.palette.success
                            : context.palette.border,
                      ),
                      borderRadius: BorderRadius.circular(
                        context.sizes.radiusMd,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        context.sizes.radiusMd,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (thumbBytes != null)
                            Image.memory(
                              thumbBytes,
                              fit: BoxFit.cover,
                              cacheWidth: decode,
                              cacheHeight: decode,
                            )
                          else if (failed)
                            Container(
                              color: context.palette.surfaceVariant,
                              child: Icon(
                                AppIcons.error,
                                size: context.sizes.iconMd,
                                color: context.palette.error,
                              ),
                            )
                          else
                            Container(
                              color: context.palette.surfaceVariant,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          if (isKeeper)
                            Positioned(
                              left: context.sizes.sm,
                              bottom: context.sizes.sm,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.sizes.sm,
                                  vertical: context.sizes.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: context.palette.success,
                                  borderRadius: BorderRadius.circular(
                                    context.sizes.pill,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.tr(AppStrings.duplicatesKeeper),
                                  style: context.textStyles.labelSmall.copyWith(
                                    color: context.palette.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!isKeeper)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: DuplicateSelectionMark(
                    selected: selected,
                    semanticsLabel: markLabel,
                    onTap: onMarkTap,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
