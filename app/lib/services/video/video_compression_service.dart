// Video compression (requirements §7, Phase 4): preview + keep the
// original until the user confirms.
//
// Interface only — the implementation is the single file allowed to
// import the transcoding SDK and photo_manager's editor. The flow
// is two explicit steps, and the original is never touched by
// either of them:
//  1. [compressPreview] transcodes a COPY of the chosen video into
//     the app cache and reports honest before/after sizes. The
//     original stays in the library, untouched and uncounted.
//  2. Only if the user confirms the preview does [saveCompressed]
//     write the compressed copy into the library as a NEW media
//     item (photo_manager editor save). The original is still not
//     deleted, overwritten or replaced by this step: if the user
//     then wants the original gone, that goes through the existing
//     review + native-confirmation trash flow as a separate,
//     explicit step, and space accounting must never count the
//     original as freed until it is actually trashed and then
//     emptied or expired (three-state accounting, requirements §4).
//     The saving shown is therefore "compressed copy is X smaller
//     than the original", never "X freed".
// A preview the user discards (or a failed/cancelled run) deletes
// its cache file and leaves no library trace. On failure the
// original is untouched and the error is a string key, never
// exception text. Compression is never automatic and never bulk:
// one video, chosen by the user, per run.

import '../../core/utils/result.dart';
import '../media/media_asset.dart';

/// One transcoded copy, still in the app cache — not yet a library
/// item. [tempPath] is meaningful only to the implementation and
/// to [saveCompressed]/[discardPreview]; callers never open it.
class VideoCompressionPreview {
  const VideoCompressionPreview({
    required this.original,
    required this.originalBytes,
    required this.compressedBytes,
    required this.tempPath,
  });

  /// The library video this preview was made from (still present).
  final MediaAsset original;

  /// Size of the original library video, in bytes.
  final int originalBytes;

  /// Size of the transcoded cache copy, in bytes.
  final int compressedBytes;

  /// Cache path of the transcoded copy (implementation-owned).
  final String tempPath;

  /// Bytes the compressed copy saves versus the original. Never
  /// negative in the UI: a copy that is not smaller saves 0.
  int get savingBytes {
    final int saving = originalBytes - compressedBytes;
    return saving > 0 ? saving : 0;
  }

  /// True only when the compressed copy is actually smaller.
  /// The UI offers "Save compressed copy" only then — saving a
  /// larger copy would waste space for no benefit.
  bool get isSmaller => compressedBytes < originalBytes;
}

abstract class VideoCompressionService {
  /// Transcodes a cache copy of [asset]'s video and reports the
  /// preview. [onProgress] receives 0.0–1.0 while the run is live;
  /// it is best-effort (an SDK that reports no progress simply
  /// never calls it). Fails when [asset] is not a video, when the
  /// original file cannot be read, or when transcoding fails —
  /// in every failure case the original is untouched.
  Future<Result<VideoCompressionPreview>> compressPreview(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  });

  /// Writes a confirmed [preview]'s cache copy into the library as
  /// a new media item and returns that item. The original is not
  /// deleted, and the cache copy is removed after a successful
  /// save. Fails (original untouched, cache copy kept for retry)
  /// when the library write fails.
  Future<Result<MediaAsset>> saveCompressed(VideoCompressionPreview preview);

  /// Deletes a preview's cache copy (user discarded it, or a run
  /// was cancelled). Best-effort: never fails the caller.
  Future<void> discardPreview(VideoCompressionPreview preview);

  /// Cancels a live run, if the backend supports it. The partial
  /// cache copy is discarded and the original is untouched.
  Future<void> cancelCompression();
}
