// Compress controller (requirements §7, Phase 4): one explicit
// video at a time, preview first, save only on confirmation, and
// a non-smaller preview is never offered for saving. The fake
// video service stands in for the native backend, which is
// host-untestable and an owner on-device check.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/compress/controller/compress_controller.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/video/video_compression_service.dart';

MediaAsset video(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 1920,
    height: 1080,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: '$id.mp4',
    albumName: 'Camera',
  );
}

class FakeMedia implements MediaService {
  FakeMedia(this.videos);

  final List<MediaAsset> videos;

  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (page == 0) {
      return Success<List<MediaAsset>>(videos);
    }
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size, {int quality = 85}) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class FakeVideo implements VideoCompressionService {
  /// Compressed size the fake reports, or null to fail the run.
  int? compressedSize;
  bool cancelCalled = false;
  bool discardCalled = false;
  int saveCalls = 0;

  @override
  Future<Result<VideoCompressionPreview>> compressPreview(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    final int? size = compressedSize;
    if (size == null) {
      return const Failure<VideoCompressionPreview>(
        AppFailure(messageKey: AppStrings.errorCompress),
      );
    }
    return Success<VideoCompressionPreview>(
      VideoCompressionPreview(
        original: asset,
        originalBytes: asset.sizeBytes,
        compressedBytes: size,
        tempPath: '/cache/${asset.id}_compressed.mp4',
      ),
    );
  }

  @override
  Future<Result<MediaAsset>> saveCompressed(
    VideoCompressionPreview preview,
  ) async {
    saveCalls++;
    return Success<MediaAsset>(video('saved', preview.compressedBytes));
  }

  @override
  Future<void> discardPreview(VideoCompressionPreview preview) async {
    discardCalled = true;
  }

  @override
  Future<void> cancelCompression() async {
    cancelCalled = true;
  }
}

Future<CompressController> makeController(
  FakeMedia media,
  FakeVideo video,
) async {
  final CompressController controller = CompressController(
    media: media,
    video: video,
  );
  controller.onInit();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return controller;
}

void main() {
  test('loads videos on init', () async {
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000), video('v2', 50000000)]),
      FakeVideo(),
    );
    expect(controller.videos.length, 2);
    expect(controller.isLoading.value, isFalse);
  });

  test('compress produces a smaller preview, save stores it first', () async {
    final FakeVideo fakeVideo = FakeVideo()..compressedSize = 40000000;
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000)]),
      fakeVideo,
    );
    await controller.compress(controller.videos.first);
    final VideoCompressionPreview? preview = controller.preview.value;
    expect(preview, isNotNull);
    expect(preview!.isSmaller, isTrue);
    expect(preview.savingBytes, 60000000);
    // The original is still in the list: compression never
    // removed or replaced it.
    expect(controller.videos.map((MediaAsset a) => a.id), contains('v1'));
    expect(await controller.savePreview(), isTrue);
    expect(controller.preview.value, isNull);
    expect(controller.videos.first.id, 'saved');
    expect(fakeVideo.saveCalls, 1);
  });

  test('non-smaller preview is refused for saving', () async {
    final FakeVideo fakeVideo = FakeVideo()..compressedSize = 120000000;
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000)]),
      fakeVideo,
    );
    await controller.compress(controller.videos.first);
    expect(controller.preview.value!.isSmaller, isFalse);
    expect(await controller.savePreview(), isFalse);
    expect(fakeVideo.saveCalls, 0);
    expect(controller.preview.value, isNotNull);
  });

  test('discard clears the preview and reports the discard', () async {
    final FakeVideo fakeVideo = FakeVideo()..compressedSize = 40000000;
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000)]),
      fakeVideo,
    );
    await controller.compress(controller.videos.first);
    await controller.discardPreview();
    expect(controller.preview.value, isNull);
    expect(fakeVideo.discardCalled, isTrue);
    // Original untouched by the whole round trip.
    expect(controller.videos.length, 1);
  });

  test('failed run sets the error and leaves no preview', () async {
    final FakeVideo fakeVideo = FakeVideo()..compressedSize = null;
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000)]),
      fakeVideo,
    );
    await controller.compress(controller.videos.first);
    expect(controller.preview.value, isNull);
    expect(controller.errorKey.value, AppStrings.errorCompress);
  });

  test('cancel delegates to the service', () async {
    final FakeVideo fakeVideo = FakeVideo();
    final CompressController controller = await makeController(
      FakeMedia(<MediaAsset>[video('v1', 100000000)]),
      fakeVideo,
    );
    await controller.cancel();
    expect(fakeVideo.cancelCalled, isTrue);
  });
}
