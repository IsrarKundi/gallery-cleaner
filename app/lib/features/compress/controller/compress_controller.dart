// Compress-video screen state (requirements §7, Phase 4).
//
// One video at a time, chosen by the user, never automatic and
// never bulk. The controller owns the two-step flow from
// [VideoCompressionService]: preview first (honest before/after
// sizes, original untouched), then — only on the user's explicit
// "Save compressed copy" — a new library item. The original is
// never deleted, overwritten or replaced here: after a save, the
// view tells the user the original is still in the library and
// that removing it is a separate review + native-confirmation
// step. Space accounting follows requirements §4: the saving is
// "compressed copy is X smaller", never "X freed" while the
// original still exists.

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/video/video_compression_service.dart';

class CompressController extends GetxController {
  CompressController({required this.media, required this.video});

  final MediaService media;
  final VideoCompressionService video;

  /// Thumbnail edge in pixels for the video list.
  static const int thumbnailSize = 256;

  /// Page size for the video listing; paging stops early on a
  /// short page, and the listing caps at [_maxVideos].
  static const int pageSize = 50;
  static const int _maxVideos = 200;

  final RxList<MediaAsset> videos = <MediaAsset>[].obs;
  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxBool isLoading = true.obs;
  final RxString errorKey = ''.obs;

  /// A run in progress: the video being transcoded + its progress.
  final Rx<MediaAsset?> compressing = Rx<MediaAsset?>(null);
  final RxDouble progress = 0.0.obs;

  /// A finished preview awaiting the user's save/discard choice.
  final Rx<VideoCompressionPreview?> preview = Rx<VideoCompressionPreview?>(
    null,
  );

  @override
  void onInit() {
    super.onInit();
    _loadVideos();
  }

  @override
  void onClose() {
    // A preview left behind when the screen is left is discarded:
    // its cache copy must not linger as an invisible almost-item.
    final VideoCompressionPreview? pending = preview.value;
    if (pending != null) {
      video.discardPreview(pending);
    }
    super.onClose();
  }

  /// Loads the library's videos, newest first, in pages. A load
  /// failure leaves the error state (never a silent empty list).
  Future<void> _loadVideos() async {
    isLoading.value = true;
    errorKey.value = '';
    final List<MediaAsset> all = <MediaAsset>[];
    int page = 0;
    while (all.length < _maxVideos) {
      final Result<List<MediaAsset>> result = await media.getAssets(
        type: MediaFilterType.video,
        page: page,
        pageSize: pageSize,
      );
      final List<MediaAsset>? batch = result.fold(
        onSuccess: (List<MediaAsset> value) => value,
        onFailure: (_) => null,
      );
      if (batch == null) {
        isLoading.value = false;
        errorKey.value = AppStrings.errorMediaLoad;
        return;
      }
      all.addAll(batch);
      if (batch.length < pageSize) {
        break;
      }
      page++;
    }
    videos.assignAll(all.take(_maxVideos));
    isLoading.value = false;
    for (final MediaAsset asset in videos) {
      final Result<Uint8List> thumb = await media.getThumbnail(
        asset.id,
        thumbnailSize,
      );
      thumb.fold(
        onSuccess: (Uint8List bytes) => thumbnails[asset.id] = bytes,
        onFailure: (_) {},
      );
    }
  }

  /// Starts a preview run for the chosen video. A second tap while
  /// a run is live is ignored (the backend runs one at a time).
  Future<void> compress(MediaAsset asset) async {
    if (compressing.value != null || preview.value != null) {
      return;
    }
    errorKey.value = '';
    compressing.value = asset;
    progress.value = 0;
    final Result<VideoCompressionPreview> result = await video.compressPreview(
      asset,
      onProgress: (double value) => progress.value = value,
    );
    compressing.value = null;
    result.fold(
      onSuccess: (VideoCompressionPreview value) => preview.value = value,
      onFailure: (AppFailure failure) => errorKey.value = failure.messageKey,
    );
  }

  /// Cancels the live run. The service discards the partial cache
  /// copy; the original is untouched. The run's own future then
  /// resolves as cancelled and sets the same message, so the view
  /// does not need a second state for it.
  Future<void> cancel() async {
    await video.cancelCompression();
  }

  /// Saves the confirmed preview as a new library item. Returns
  /// true on success (the view shows the saved + original-kept
  /// notes); false leaves the preview in place for retry. A
  /// preview that is not smaller is never offered for saving by
  /// the view, and is refused here too if it ever arrives.
  Future<bool> savePreview() async {
    final VideoCompressionPreview? current = preview.value;
    if (current == null || !current.isSmaller) {
      return false;
    }
    final Result<MediaAsset> result = await video.saveCompressed(current);
    return result.fold(
      onSuccess: (MediaAsset saved) {
        preview.value = null;
        videos.insert(0, saved);
        return true;
      },
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
        return false;
      },
    );
  }

  /// Discards the preview's cache copy and returns to the list.
  /// The original was never touched, so nothing else changes.
  Future<void> discardPreview() async {
    final VideoCompressionPreview? current = preview.value;
    if (current == null) {
      return;
    }
    preview.value = null;
    await video.discardPreview(current);
  }
}
