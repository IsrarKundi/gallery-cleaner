// All Albums screen (owner instruction 31 Oct 2026, ADR-027;
// requirements §7). Layout + Obx only: the album list, covers
// and the album launch live in AlbumsController.
//
// Design consistency is an explicit owner requirement, so this
// screen invents nothing: the frame is the hub's AppScaffold,
// the states are the hub's own (skeleton loading, the same
// denied EmptyView, ErrorView, the hub's empty state), and the
// rows follow the album picker sheet's row shape (cover/name/
// count, divider-separated, design tokens only) with the cover
// rendered through the shared thumbnail service like every hub
// preview.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/error_view.dart';
import '../../../services/media/media_asset.dart';
import '../controller/albums_controller.dart';
import '../model/decks_status.dart';

class AlbumsView extends GetView<AlbumsController> {
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.tr(AppStrings.screenAlbums),
      body: _Body(controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final AlbumsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final DecksStatus status = controller.status.value;
      if (status == DecksStatus.loading || status == DecksStatus.scanning) {
        return const _AlbumsSkeleton();
      }
      if (status == DecksStatus.denied) {
        // The hub's denied state, verbatim (DecksView).
        return EmptyView(
          icon: AppIcons.photos,
          title: AppStrings.tr(AppStrings.permissionDeniedTitle),
          message: AppStrings.tr(AppStrings.permissionDeniedMessage),
          ctaLabel: AppStrings.tr(AppStrings.permissionAllowAccess),
          onCta: controller.retry,
          secondaryCtaLabel: AppStrings.tr(AppStrings.permissionOpenSettings),
          onSecondaryCta: controller.openPermissionSettings,
        );
      }
      if (status == DecksStatus.error) {
        return ErrorView(
          message: AppStrings.tr(
            controller.errorKey.value.isEmpty
                ? AppStrings.errorGeneric
                : controller.errorKey.value,
          ),
          onRetry: controller.retry,
        );
      }
      if (controller.albums.isEmpty) {
        return EmptyView(
          icon: AppIcons.decks,
          title: AppStrings.tr(AppStrings.decksEmpty),
          message: AppStrings.tr(AppStrings.decksEmptyMessage),
          ctaLabel: AppStrings.tr(AppStrings.scanAgain),
          onCta: controller.retry,
        );
      }
      return _AlbumsList(controller: controller);
    });
  }
}

class _AlbumsList extends StatelessWidget {
  const _AlbumsList({required this.controller});

  final AlbumsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String launchError = controller.launchErrorKey.value;
      return Column(
        children: <Widget>[
          if (launchError.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.sizes.screenPadding,
                context.sizes.md,
                context.sizes.screenPadding,
                0,
              ),
              child: ErrorBanner(
                message: AppStrings.tr(launchError),
                onDismiss: () => controller.launchErrorKey.value = '',
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: context.sizes.sm),
              itemCount: controller.albums.length,
              separatorBuilder: (BuildContext context, int index) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sizes.screenPadding,
                ),
                child: Divider(height: 1, color: context.palette.border),
              ),
              itemBuilder: (BuildContext context, int index) {
                final MediaAlbum album = controller.albums[index];
                return _AlbumRow(
                  controller: controller,
                  album: album,
                  onTap: () => controller.openAlbum(album),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

/// One album row: cover (the album's latest asset through the
/// shared thumbnail service), name, item count — the album
/// picker sheet's row, with a cover in place of its icon.
class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.controller,
    required this.album,
    required this.onTap,
  });

  final AlbumsController controller;
  final MediaAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The row carries its own Obx (the hub widgets' pattern —
    // deck_row.dart, smart_deck_grid_card.dart): rows are built
    // by the list during layout, outside the list's Obx scope,
    // so the cover observables must be read under a row-level
    // Obx or their updates would never rebuild the row.
    return Obx(() {
      final String? coverId = controller.coverAssetIds[album.id];
      final Uint8List? bytes = coverId == null
          ? null
          : controller.coverThumbnails[coverId];
      if (coverId != null &&
          bytes == null &&
          !controller.failedCovers.contains(coverId)) {
        // The thumbnail service's widget path: idempotent, safe
        // to call on every build (the hub's previews do the same).
        controller.requestCover(coverId);
      }
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sizes.screenPadding,
            vertical: context.sizes.sm,
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                child: SizedBox(
                  width: context.sizes.listRowMin,
                  height: context.sizes.listRowMin,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Container(
                          color: context.palette.primaryContainer,
                          child: Icon(
                            AppIcons.photos,
                            size: context.sizes.iconMd,
                            color: context.palette.textSecondary,
                          ),
                        ),
                ),
              ),
              SizedBox(width: context.sizes.md),
              Expanded(
                child: Text(
                  album.name,
                  style: context.textStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.sizes.sm),
              Text(
                album.count.toString(),
                style: context.textStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Loading state: skeleton rows in the real rows' shape (the
/// app's standing loading choice — skeletons, never spinners).
class _AlbumsSkeleton extends StatelessWidget {
  const _AlbumsSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.sizes.sm),
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (int i = 0; i < 6; i++) ...<Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
                vertical: context.sizes.sm,
              ),
              child: Row(
                children: <Widget>[
                  Bone(
                    width: context.sizes.listRowMin,
                    height: context.sizes.listRowMin,
                    borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                  ),
                  SizedBox(width: context.sizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Bone(width: 140, height: 14),
                        SizedBox(height: context.sizes.sm),
                        Bone(width: 56, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              child: Divider(height: 1, color: context.palette.border),
            ),
          ],
        ],
      ),
    );
  }
}
