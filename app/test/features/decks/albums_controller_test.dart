// All Albums controller tests (ADR-027, requirements §7): the
// list is the media service's album list; covers resolve to
// each album's latest asset; the launch pages the album's full
// asset list and keys its session `smart:album:<id>` so marks
// flow like every smart deck's.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/albums_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';

MediaAsset _asset(String id, {String album = 'Camera'}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
  );
}

class _Media implements MediaService {
  _Media({
    this.permission = MediaPermission.grantedFull,
    List<MediaAlbum>? albums,
    Map<String, List<MediaAsset>>? assetsByAlbum,
    this.failAlbums = false,
    this.failAssets = false,
  }) : albums = albums ?? <MediaAlbum>[],
       assetsByAlbum = assetsByAlbum ?? <String, List<MediaAsset>>{};

  final MediaPermission permission;
  final List<MediaAlbum> albums;
  final Map<String, List<MediaAsset>> assetsByAlbum;
  final bool failAlbums;
  final bool failAssets;

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      Success<MediaPermission>(permission);

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    if (failAlbums) {
      return const Failure<List<MediaAlbum>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return Success<List<MediaAlbum>>(albums);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (failAssets) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    final List<MediaAsset> all = assetsByAlbum[albumId] ?? const <MediaAsset>[];
    final int start = page * pageSize;
    if (start >= all.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = start + pageSize > all.length
        ? all.length
        : start + pageSize;
    return Success<List<MediaAsset>>(all.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));
}

void main() {
  tearDown(Get.reset);

  AlbumsController build(_Media media) {
    final AlbumsController controller = AlbumsController(media: media);
    addTearDown(controller.onClose);
    return controller;
  }

  test('loads the album list and resolves covers to latest assets', () async {
    final _Media media = _Media(
      albums: const <MediaAlbum>[
        MediaAlbum(id: 'cam', name: 'Camera', count: 2),
        MediaAlbum(id: 'shots', name: 'Screenshots', count: 1),
      ],
      assetsByAlbum: <String, List<MediaAsset>>{
        'cam': <MediaAsset>[_asset('c2'), _asset('c1')],
        'shots': <MediaAsset>[_asset('s1', album: 'Screenshots')],
      },
    );
    final AlbumsController controller = build(media);
    await controller.init();

    expect(controller.status.value, DecksStatus.ready);
    expect(controller.albums.map((MediaAlbum a) => a.name), <String>[
      'Camera',
      'Screenshots',
    ]);
    // Cover = page 0's first asset (the enumeration order is
    // newest first), resolved per album.
    expect(controller.coverAssetIds['cam'], 'c2');
    expect(controller.coverAssetIds['shots'], 's1');
  });

  test('permission denied lands on the denied state', () async {
    final AlbumsController controller = build(
      _Media(permission: MediaPermission.denied),
    );
    await controller.init();

    expect(controller.status.value, DecksStatus.denied);
    expect(controller.albums, isEmpty);
  });

  test('a failed album list lands on the error state', () async {
    final AlbumsController controller = build(_Media(failAlbums: true));
    await controller.init();

    expect(controller.status.value, DecksStatus.error);
    expect(controller.errorKey.value, AppStrings.errorMediaLoad);
  });

  test(
    'buildLaunch pages the whole album, keyed and titled per album',
    () async {
      final List<MediaAsset> sixty = <MediaAsset>[
        for (int i = 0; i < 60; i++) _asset('a$i'),
      ];
      final _Media media = _Media(
        albums: const <MediaAlbum>[
          MediaAlbum(id: 'cam', name: 'Camera', count: 60),
        ],
        assetsByAlbum: <String, List<MediaAsset>>{'cam': sixty},
      );
      final AlbumsController controller = build(media);

      final SmartDeckLaunch? launch = await controller.buildLaunch(
        const MediaAlbum(id: 'cam', name: 'Camera', count: 60),
      );

      expect(launch, isNotNull);
      // Two pages (50 + 10): the launch carries the full list,
      // not just the first page.
      expect(launch!.assets.length, 60);
      expect(launch.deckId, isNull);
      expect(launch.sessionKey, 'smart:album:cam');
      expect(launch.customTitle, 'Camera');
    },
  );

  test('buildLaunch failure returns null and records the reason', () async {
    final AlbumsController controller = build(_Media(failAssets: true));

    final SmartDeckLaunch? launch = await controller.buildLaunch(
      const MediaAlbum(id: 'cam', name: 'Camera', count: 3),
    );

    expect(launch, isNull);
    expect(controller.launchErrorKey.value, AppStrings.errorMediaLoad);
  });
}
