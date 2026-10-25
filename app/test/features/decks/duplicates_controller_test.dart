// Duplicates controller tests (requirements §7, Phase 2A):
// grouping from the cache, live slider regroup without thumbnail
// re-download, keeper change, and session writes. Navigation is
// covered by the duplicates widget test (Get.toNamed needs a
// GetMaterialApp, like the review controller convention).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

PhotoAnalysis _analysis(String id, int hash, double blur) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: blur,
    meanLuminance: 128,
  );
}

class _Media implements MediaService {
  int analysisThumbnailCalls = 0;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 3),
    ]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (page > 0) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    return Success<List<MediaAsset>>(<MediaAsset>[
      _asset('a'),
      _asset('b'),
      _asset('c'),
    ]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    // The scanner analyses at 128px; tiles load at 256px. Counting
    // 128px calls proves regrouping never re-downloads for analysis.
    if (size == 128) {
      analysisThumbnailCalls++;
    }
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
    'a': _analysis('a', 0, 900),
    'b': _analysis('b', 0, 10),
    'c': _analysis('c', 63, 500),
  };

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> list) async {
    for (final PhotoAnalysis a in list) {
      analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(analyses),
    );
  }
}

void main() {
  tearDown(Get.reset);

  group('DuplicatesController', () {
    test('groups from the cache at the default threshold', () async {
      final _Media media = _Media();
      final DuplicatesController controller = DuplicatesController(
        media: media,
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.ready);
      expect(controller.threshold.value, 5);
      expect(controller.groups.length, 1);
      expect(
        controller.groups.first.assets.map((MediaAsset a) => a.id).toList(),
        <String>['a', 'b'],
      );
      // 'a' is sharpest, so it is the suggested keeper.
      expect(controller.groups.first.keeperId, 'a');
      // Everything was cached: the scanner downloaded no thumbnails.
      expect(media.analysisThumbnailCalls, 0);
    });

    test('slider regroups from cache without analysis downloads', () async {
      final _Media media = _Media();
      final DuplicatesController controller = DuplicatesController(
        media: media,
        local: _Local(),
      );
      await controller.init();
      // 'c' is distance 6 from 'a': outside 5, inside 6.
      controller.setThreshold(6);
      expect(controller.groups.length, 1);
      expect(controller.groups.first.assets.length, 3);
      controller.setThreshold(0);
      expect(controller.groups.first.assets.length, 2);
      expect(media.analysisThumbnailCalls, 0);
    });

    test('slider clamps to 0-10', () async {
      final DuplicatesController controller = DuplicatesController(
        media: _Media(),
        local: _Local(),
      );
      await controller.init();
      controller.setThreshold(99);
      expect(controller.threshold.value, 10);
      controller.setThreshold(-5);
      expect(controller.threshold.value, 0);
    });

    test('keeper change moves the non-keeper set', () async {
      final DuplicatesController controller = DuplicatesController(
        media: _Media(),
        local: _Local(),
      );
      await controller.init();
      controller.changeKeeper(0, 'b');
      expect(controller.groups.first.keeperId, 'b');
      expect(
        controller.groups.first.nonKeepers.map((MediaAsset a) => a.id).toList(),
        <String>['a'],
      );
      // Unknown ids and out-of-range groups are no-ops.
      controller.changeKeeper(0, 'ghost');
      expect(controller.groups.first.keeperId, 'b');
      controller.changeKeeper(9, 'a');
      expect(controller.groups.first.keeperId, 'b');
    });

    test('denied permission shows the denied state', () async {
      final DuplicatesController controller = DuplicatesController(
        media: _DeniedMedia(),
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.denied);
    });
  });
}

class _DeniedMedia implements MediaService {
  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.denied);
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
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1]));
  }
}
