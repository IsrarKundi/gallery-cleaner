// Compress-video screen (requirements §7, Phase 4). Layout +
// Obx only: the two-step flow (preview, then explicit save) and
// all service calls live in [CompressController].
//
// States, top to bottom: a live run shows determinate progress +
// Cancel; a finished preview shows the honest before/after card
// (original size, compressed size, saving — never "freed", the
// original is still in the library) with Save (only when the copy
// is actually smaller) and Discard; otherwise the video list with
// a tap-to-compress hint. No button here ever deletes, replaces
// or overwrites an original.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/video/video_compression_service.dart';
import '../controller/compress_controller.dart';

class CompressView extends GetView<CompressController> {
  const CompressView({super.key});

  Future<void> _save(BuildContext context) async {
    final bool saved = await controller.savePreview();
    if (!context.mounted) {
      return;
    }
    if (saved) {
      AppSnackbar.show(
        context,
        message: AppStrings.tr(AppStrings.compressSaved),
      );
      AppSnackbar.show(
        context,
        message: AppStrings.tr(AppStrings.compressOriginalKept),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final VideoCompressionPreview? preview = controller.preview.value;
      final MediaAsset? running = controller.compressing.value;
      return AppScaffold(
        title: AppStrings.tr(AppStrings.screenCompress),
        leading: IconButton(
          icon: Icon(AppIcons.back, size: context.sizes.iconMd),
          tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
          onPressed: () => Get.offAllNamed<dynamic>(AppRoutes.deck),
        ),
        body: Column(
          children: <Widget>[
            if (controller.errorKey.value.isNotEmpty)
              ErrorBanner(
                message: AppStrings.tr(controller.errorKey.value),
                onDismiss: () => controller.errorKey.value = '',
              ),
            if (running != null) _Progress(controller: controller),
            if (preview != null)
              _PreviewCard(
                preview: preview,
                onSave: () => _save(context),
                onDiscard: controller.discardPreview,
              ),
            Expanded(
              child: controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : controller.videos.isEmpty
                  ? EmptyView(
                      icon: AppIcons.compress,
                      title: AppStrings.tr(AppStrings.compressEmptyTitle),
                      message: AppStrings.tr(AppStrings.compressEmptyMessage),
                      ctaLabel: AppStrings.tr(AppStrings.actionBackToDeck),
                      onCta: () => Get.offAllNamed<dynamic>(AppRoutes.deck),
                    )
                  : _VideoList(controller: controller),
            ),
          ],
        ),
      );
    });
  }
}

/// Determinate progress for a live run (design.md §6: jobs over
/// ~4 seconds get a progress bar with % + count, not a spinner).
class _Progress extends StatelessWidget {
  const _Progress({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    final int percent = (controller.progress.value * 100).round();
    return Padding(
      padding: EdgeInsets.all(context.sizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.tr(AppStrings.compressing, <String, String>{
              'percent': '$percent',
            }),
            style: context.textStyles.titleMedium,
          ),
          SizedBox(height: context.sizes.sm),
          LinearProgressIndicator(value: controller.progress.value),
          SizedBox(height: context.sizes.sm),
          SecondaryButton(
            label: AppStrings.tr(AppStrings.compressCancel),
            icon: AppIcons.close,
            onPressed: controller.cancel,
          ),
        ],
      ),
    );
  }
}

/// The preview card: honest before/after sizes and the saving for
/// the compressed copy versus the original. "Freed" never appears
/// here — the original still exists, so nothing is freed yet.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.onSave,
    required this.onDiscard,
  });

  final VideoCompressionPreview preview;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sizes.screenPadding,
        context.sizes.screenPadding,
        context.sizes.screenPadding,
        context.sizes.sm,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.tr(AppStrings.compressPreviewTitle),
              style: context.textStyles.titleMedium,
            ),
            SizedBox(height: context.sizes.sm),
            Text(
              AppStrings.tr(AppStrings.compressOriginalLabel, <String, String>{
                'size': Formatters.formatBytes(preview.originalBytes),
              }),
              style: context.textStyles.bodyMedium,
            ),
            Text(
              AppStrings.tr(
                AppStrings.compressCompressedLabel,
                <String, String>{
                  'size': Formatters.formatBytes(preview.compressedBytes),
                },
              ),
              style: context.textStyles.bodyMedium,
            ),
            SizedBox(height: context.sizes.xs),
            Text(
              preview.isSmaller
                  ? AppStrings.tr(AppStrings.compressSaving, <String, String>{
                      'size': Formatters.formatBytes(preview.savingBytes),
                    })
                  : AppStrings.tr(AppStrings.compressNotSmaller),
              style: context.textStyles.bodyMedium.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            SizedBox(height: context.sizes.md),
            if (preview.isSmaller)
              PrimaryButton(
                label: AppStrings.tr(AppStrings.compressSaveCopy),
                icon: AppIcons.check,
                onPressed: onSave,
              ),
            if (preview.isSmaller) SizedBox(height: context.sizes.sm),
            SecondaryButton(
              label: AppStrings.tr(AppStrings.compressDiscard),
              icon: AppIcons.close,
              onPressed: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}

/// The video list: one row per video (thumbnail, title, size +
/// date). Tapping a row starts that video's preview run — the
/// only way compression starts, never automatic, never bulk.
class _VideoList extends StatelessWidget {
  const _VideoList({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sizes.screenPadding,
            context.sizes.sm,
            context.sizes.screenPadding,
            context.sizes.xs,
          ),
          child: Text(
            AppStrings.tr(AppStrings.compressHint),
            style: context.textStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sizes.screenPadding,
            context.sizes.xs,
            context.sizes.screenPadding,
            context.sizes.sm,
          ),
          child: Text(
            AppStrings.tr(AppStrings.compressTapHint),
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: controller.videos.length,
            itemBuilder: (BuildContext context, int index) {
              final MediaAsset asset = controller.videos[index];
              final Uint8List? thumb = controller.thumbnails[asset.id];
              return ListTile(
                leading: thumb == null
                    ? Icon(AppIcons.videos, size: context.sizes.iconMd)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(
                          context.sizes.radiusSm,
                        ),
                        child: Image.memory(
                          thumb,
                          width: context.sizes.listRowMin,
                          height: context.sizes.listRowMin,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(
                  asset.title.isEmpty ? 'Video' : asset.title,
                  style: context.textStyles.titleMedium,
                ),
                subtitle: Text(
                  '${Formatters.formatBytes(asset.sizeBytes)} · '
                  '${Formatters.formatDate(asset.createDate)}',
                  style: context.textStyles.bodySmall,
                ),
                onTap: () => controller.compress(asset),
              );
            },
          ),
        ),
      ],
    );
  }
}
