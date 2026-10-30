// Stage 6 hub wiring (fix plan Stage 6, ADR-021): the
// Similar Videos row is fed by the scan's memberships like
// blurry/dark — populated when the scan completes, scan-gated
// readiness, byte totals from the same incremental path — and
// the deck's meta (title key, icon, hub order) resolves
// through the one shared place. Driven end-to-end: hub ->
// shared repository -> scanner -> video pass (fake gateway)
// -> memberships -> hub.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/model/smart_deck_meta.dart';
import 'package:klara/services/detection/scan_repository_impl.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/media/video_frame_gateway.dart';

Uint8List _framePng(List<int> values) {
  final img.Image image = img.Image(width: 9, height: 8);
  for (int row = 0; row < 8; row++) {
    for (int x = 0; x < 9; x++) {
      final int v = values[x];
      image.setPixelRgb(x, row, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

final Uint8List _x = _framePng(<int>[0, 32, 64, 96, 128, 160, 192, 224, 255]);
final Uint8List _y = _framePng(<int>[0, 100, 50, 150, 100, 200, 150, 250, 200]);
final Uint8List _z = _framePng(<int>[
  250,
  200,
  210,
  150,
  160,
  100,
  110,
  50,
  60,
]);
// w's rhythm (paired bits, 0xCC per row) keeps it at Hamming
// >= 32 from x/y/z, so v3's frames never match v1/v2's, however
// often the sampled cycle repeats them.
final Uint8List _w = _framePng(<int>[0, 50, 100, 90, 80, 130, 180, 170, 160]);

MediaAsset _video(String id, {required int sizeBytes, required int day}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 640,
    height: 360,
    sizeBytes: sizeBytes,
    createDate: DateTime.utc(2026, 1, day),
    title: id,
    albumName: 'Camera',
  );
}

class _Media implements MediaService {
  _Media({required this.assets});

  final List<MediaAsset> assets;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<void>> presentLimitedSelection() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> openAppSettings() {
    throw UnimplementedError();
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
      return Success<List<MediaAsset>>(assets);
    }
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) {
    throw UnimplementedError();
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_x);
  }
}

class _Gateway implements VideoFrameGateway {
  @override
  Future<Duration?> videoDuration(String assetId) async {
    return const Duration(seconds: 20);
  }

  @override
  Future<List<Uint8List?>> extractFrames(
    String assetId,
    List<Duration> timestamps,
  ) async {
    final List<Uint8List> cycle = assetId == 'v3'
        ? <Uint8List>[_z, _w]
        : <Uint8List>[_x, _y];
    return <Uint8List?>[
      for (int i = 0; i < timestamps.length; i++) cycle[i % cycle.length],
    ];
  }
}

void main() {
  tearDown(Get.reset);

  late Directory temp;
  late LocalServiceImpl local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_stage6_hub_test_');
    local = LocalServiceImpl(directoryResolver: () async => temp);
  });

  tearDown(() async {
    await local.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('meta: title, string, icon and hub order resolve', () {
    expect(
      smartDeckTitleKey(SmartDeckId.similarVideos),
      AppStrings.deckSimilarVideos,
    );
    expect(AppStrings.tr(AppStrings.deckSimilarVideos), 'Similar videos');
    expect(smartDeckIcon(SmartDeckId.similarVideos), AppIcons.similarVideos);
    final int dupIndex = smartDeckOrder.indexOf(SmartDeckId.duplicates);
    expect(
      smartDeckOrder.indexOf(SmartDeckId.similarVideos),
      dupIndex + 1,
      reason: 'the similar-videos row sits right after duplicates',
    );
  });

  test('the hub fills the Similar Videos deck from the scan '
      'memberships and gates it on scan completion', () async {
    final _Media media = _Media(
      assets: <MediaAsset>[
        _video('v1', sizeBytes: 1000, day: 1),
        _video('v2', sizeBytes: 2000, day: 2),
        _video('v3', sizeBytes: 4000, day: 3),
      ],
    );
    final DecksController controller = DecksController(
      media: media,
      local: local,
      scanRepository: ScanRepositoryImpl(
        media: media,
        local: local,
        videoFrames: _Gateway(),
      ),
    );
    // Before the scan: a membership deck is not ready.
    expect(controller.deckReady(SmartDeckId.similarVideos), isFalse);
    await controller.init();
    expect(controller.status.value, DecksStatus.ready);
    expect(controller.deckReady(SmartDeckId.similarVideos), isTrue);
    // v1 + v2 group; v3 (different frames) stays out.
    expect(
      controller
          .assetsFor(SmartDeckId.similarVideos)
          .map((MediaAsset a) => a.id)
          .toList(),
      <String>['v1', 'v2'],
    );
    expect(controller.totalBytesFor(SmartDeckId.similarVideos), 3000);
    // The plain Videos deck still holds all three (metadata
    // membership is untouched by the video pass).
    expect(controller.assetsFor(SmartDeckId.videos).length, 3);
    controller.onClose();
  });
}
