// One duplicate / similar group: thumbnails in a row, the keeper
// badged, and the "mark others for deletion" action.
//
// Tapping any thumbnail makes it the keeper (the user may always
// pick another); the button then marks exactly the non-keepers.
// Nothing here deletes — the controller navigates to review, and
// review + native confirmation still own removal (requirements §4).

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
import '../../../core/widgets/secondary_button.dart';

class DuplicateGroupCard extends StatefulWidget {
  const DuplicateGroupCard({
    super.key,
    required this.group,
    required this.thumbnails,
    required this.failedThumbnails,
    required this.onKeeperTap,
    required this.onMarkNonKeepers,
  });

  final DuplicateGroup group;
  final Map<String, Uint8List> thumbnails;
  final Set<String> failedThumbnails;
  final ValueChanged<String> onKeeperTap;
  final VoidCallback onMarkNonKeepers;

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
    final int totalBytes = group.assets.fold<int>(
      0,
      (int sum, MediaAsset a) => sum + a.sizeBytes,
    );
    // Collapsed previews: the first 20 members, plus the keeper
    // when it sits beyond them (its badge must never hide —
    // the button below marks every non-keeper, seen or not).
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(context.sizes.radiusMd),
      ),
      padding: EdgeInsets.all(context.sizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.tr(AppStrings.duplicatesGroupCount, <String, String>{
              'count': group.assets.length.toString(),
            }),
            style: context.textStyles.titleMedium,
          ),
          SizedBox(height: context.sizes.xs),
          Text(
            '${Formatters.formatBytes(totalBytes)} · '
            '${AppStrings.tr(AppStrings.duplicatesTapToKeep)}',
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          SizedBox(height: context.sizes.md),
          Wrap(
            spacing: context.sizes.sm,
            runSpacing: context.sizes.sm,
            children: <Widget>[
              for (final MediaAsset asset in shown)
                _Thumb(
                  asset: asset,
                  bytes: widget.thumbnails[asset.id],
                  failed: widget.failedThumbnails.contains(asset.id),
                  isKeeper: asset.id == group.keeperId,
                  onTap: () => widget.onKeeperTap(asset.id),
                ),
              // Collapsed overflow: tapping reveals every member
              // (the keeper pick must reach members beyond the
              // cap — there is no detail screen to show them).
              if (!_expanded && hidden > 0)
                Semantics(
                  button: true,
                  label: AppStrings.tr(
                    AppStrings.duplicatesShowMore,
                    <String, String>{'count': '$hidden'},
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = true),
                    child: Container(
                      width: context.sizes.duplicateThumb,
                      height: context.sizes.duplicateThumb,
                      decoration: BoxDecoration(
                        border: Border.all(color: context.palette.border),
                        borderRadius: BorderRadius.circular(
                          context.sizes.radiusMd,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '+$hidden',
                          style: context.textStyles.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: context.sizes.md),
          SecondaryButton(
            label: AppStrings.tr(AppStrings.duplicatesMarkNonKeepers),
            icon: AppIcons.delete,
            onPressed: widget.onMarkNonKeepers,
          ),
        ],
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
    required this.onTap,
  });

  final MediaAsset asset;
  final Uint8List? bytes;
  final bool failed;
  final bool isKeeper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double size = context.sizes.duplicateThumb;
    // Phase 1.6: decode at display size, never larger than the
    // fetched thumbnail (see decode_size.dart).
    final int decode = decodeSide(
      width: size,
      height: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      sourceSize: DuplicatesController.thumbnailSize,
    );
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
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(
              color: isKeeper
                  ? context.palette.success
                  : context.palette.border,
            ),
            borderRadius: BorderRadius.circular(context.sizes.radiusMd),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.sizes.radiusMd),
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
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                if (isKeeper)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: context.palette.successBg,
                      padding: EdgeInsets.symmetric(vertical: context.sizes.xs),
                      child: Text(
                        AppStrings.tr(AppStrings.duplicatesKeeper),
                        style: context.textStyles.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
