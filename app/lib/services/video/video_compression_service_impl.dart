// video_compress_advanced implementation of
// [VideoCompressionService].
//
// This is the ONLY file importing video_compress_advanced (and,
// for the library write, photo_manager's editor). It never deletes,
// overwrites or replaces an original: `deleteOrigin` is always
// false, the transcoded copy lives in the plugin's cache, and the
// library write creates a NEW asset via `PhotoManager.editor
// .saveVideo`. The original file is read through
// `AssetEntity.originFile` (the full original, not a transcoded
// proxy) and is never written to.
//
// Manifest note (Phase 4 exception, documented not hidden): the
// plugin's own AndroidManifest declares the legacy
// WRITE_EXTERNAL_STORAGE permission, so it appears in the merged
// manifest. Klara's own AndroidManifest is unchanged (the three
// permissions from Phase 3A), Klara never requests this permission
// at runtime, and on Android 13+ it grants nothing — the output
// path is the app cache plus a MediaStore save, i.e. scoped
// storage. MANAGE_EXTERNAL_STORAGE is still never requested.
//
// All failures are string-keyed [AppFailure]s. A cancelled run
// (MediaInfo.isCancel) is a failure with the cancelled key, and
// its partial cache copy is discarded, so a cancel never leaves
// a half-written preview behind.

import 'dart:io';

import 'package:photo_manager/photo_manager.dart';
import 'package:video_compress_advanced/video_compress_advanced.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../media/media_asset.dart';
import 'video_compression_service.dart';

class VideoCompressionServiceImpl implements VideoCompressionService {
  @override
  Future<Result<VideoCompressionPreview>> compressPreview(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    if (asset.type != MediaAssetType.video) {
      return const Failure<VideoCompressionPreview>(
        AppFailure(messageKey: AppStrings.errorCompressNotVideo),
      );
    }
    try {
      final AssetEntity? entity = await AssetEntity.fromId(asset.id);
      final File? originalFile = await entity?.originFile;
      if (entity == null || originalFile == null) {
        return const Failure<VideoCompressionPreview>(
          AppFailure(messageKey: AppStrings.errorCompress),
        );
      }
      final int originalBytes = await originalFile.length();
      Subscription? subscription;
      if (onProgress != null) {
        subscription = VideoCompress.compressProgress$.subscribe(
          (double value) => onProgress(value / 100),
        );
      }
      MediaInfo? info;
      try {
        info = await VideoCompress.compressVideo(
          originalFile.path,
          quality: VideoQuality.DefaultQuality,
          deleteOrigin: false,
        );
      } finally {
        subscription?.unsubscribe();
      }
      final String? outPath = info?.path;
      final int? outSize = info?.filesize;
      if (info?.isCancel == true || outPath == null || outSize == null) {
        if (outPath != null) {
          await _deleteQuietly(File(outPath));
        }
        return Failure<VideoCompressionPreview>(
          AppFailure(
            messageKey: info?.isCancel == true
                ? AppStrings.compressCancelled
                : AppStrings.errorCompress,
          ),
        );
      }
      return Success<VideoCompressionPreview>(
        VideoCompressionPreview(
          original: asset,
          originalBytes: originalBytes,
          compressedBytes: outSize,
          tempPath: outPath,
        ),
      );
    } catch (_) {
      return const Failure<VideoCompressionPreview>(
        AppFailure(messageKey: AppStrings.errorCompress),
      );
    }
  }

  @override
  Future<Result<MediaAsset>> saveCompressed(
    VideoCompressionPreview preview,
  ) async {
    try {
      final File file = File(preview.tempPath);
      if (!await file.exists()) {
        return const Failure<MediaAsset>(
          AppFailure(messageKey: AppStrings.errorCompress),
        );
      }
      final AssetEntity saved = await PhotoManager.editor.saveVideo(
        file,
        title: _compressedTitle(preview.original.title),
      );
      await _deleteQuietly(file);
      int sizeBytes = preview.compressedBytes;
      try {
        sizeBytes = await saved.fileSize;
      } catch (_) {
        // Keep the preview's measured size; the saved copy is the
        // same file, so the preview figure is not invented.
      }
      return Success<MediaAsset>(
        MediaAsset(
          id: saved.id,
          type: MediaAssetType.video,
          width: saved.width,
          height: saved.height,
          sizeBytes: sizeBytes,
          createDate: saved.createDateTime,
          title: saved.title ?? _compressedTitle(preview.original.title),
          albumName: '',
        ),
      );
    } catch (_) {
      return const Failure<MediaAsset>(
        AppFailure(messageKey: AppStrings.errorCompress),
      );
    }
  }

  @override
  Future<void> discardPreview(VideoCompressionPreview preview) async {
    await _deleteQuietly(File(preview.tempPath));
  }

  @override
  Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {
      // Cancellation is best-effort: a failed cancel must not
      // surface as a second error on top of the run's outcome.
    }
  }

  /// "clip.mp4" -> "clip_compressed.mp4"; an empty title becomes
  /// "klara_compressed.mp4". The original's filename is never
  /// reused bare, so the new item cannot masquerade as the
  /// original in the library.
  String _compressedTitle(String title) {
    if (title.isEmpty) {
      return 'klara_compressed.mp4';
    }
    final int dot = title.lastIndexOf('.');
    if (dot <= 0) {
      return '${title}_compressed.mp4';
    }
    return '${title.substring(0, dot)}_compressed${title.substring(dot)}';
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort; the plugin owns its cache
      // folder and a leftover is not a user-facing failure.
    }
  }
}
