// Release smoke test (Phase 7.2): video compression SHIPS in the
// first Play release, so the route + binding + view wiring it
// ships with must stay green. The native codec itself is
// host-untestable (see compress_controller_test.dart); this test
// proves the shipped wiring end to end with the fake service:
// list renders, tapping a row runs a preview, saving it completes.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/compress/binding/compress_binding.dart';
import 'package:klara/features/compress/view/compress_view.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/video/video_compression_service.dart';

MediaAsset _video(String id, int size) {
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

class _Media implements MediaService {
  final List<MediaAsset> videos = <MediaAsset>[_video('v1', 100000000)];

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Video implements VideoCompressionService {
  int saveCalls = 0;

  @override
  Future<Result<VideoCompressionPreview>> compressPreview(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    return Success<VideoCompressionPreview>(
      VideoCompressionPreview(
        original: asset,
        originalBytes: asset.sizeBytes,
        compressedBytes: 40000000,
        tempPath: '/cache/${asset.id}_compressed.mp4',
      ),
    );
  }

  @override
  Future<Result<MediaAsset>> saveCompressed(
    VideoCompressionPreview preview,
  ) async {
    saveCalls++;
    return Success<MediaAsset>(_video('saved', preview.compressedBytes));
  }

  @override
  Future<void> discardPreview(VideoCompressionPreview preview) async {}

  @override
  Future<void> cancelCompression() async {}
}

void main() {
  tearDown(Get.reset);

  testWidgets('compress route renders, previews and saves', (
    WidgetTester tester,
  ) async {
    final _Video video = _Video();
    Get.put<MediaService>(_Media(), permanent: true);
    Get.put<VideoCompressionService>(video, permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        initialRoute: AppRoutes.compress,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: AppRoutes.compress,
            page: CompressView.new,
            binding: CompressBinding(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.deck,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('v1.mp4'), findsOneWidget);

    await tester.tap(find.text('v1.mp4'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.tr(AppStrings.compressPreviewTitle)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.tr(AppStrings.compressSaveCopy)));
    await tester.pumpAndSettle();
    expect(video.saveCalls, 1);
    expect(
      find.text(AppStrings.tr(AppStrings.compressPreviewTitle)),
      findsNothing,
    );
  });
}
