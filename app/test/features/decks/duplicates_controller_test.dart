// Duplicates controller tests (requirements §7, Phase 2A;
// Stage 4 rewrite): the screen shows the scan's EXACT-duplicate
// memberships — it groups nothing itself, and the similarity
// slider is gone (ADR-019). Keeper change and the denied path
// are covered here; navigation is covered by the duplicates
// widget test (Get.toNamed needs a GetMaterialApp, like the
// review controller convention).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
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

/// Solid dark PNG (a and b share it byte for byte).
Uint8List _darkPng() {
  final img.Image image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

/// Half-white PNG: a different fingerprint AND a very different
/// colour summary, so c is neither an exact duplicate of a/b
/// nor similar to them.
Uint8List _splitPng() {
  final img.Image image = img.Image(width: 32, height: 32);
  for (int y = 0; y < 32; y++) {
    for (int x = 0; x < 32; x++) {
      if (x < 16) {
        image.setPixelRgb(x, y, 250, 250, 250);
      } else {
        image.setPixelRgb(x, y, 5, 5, 5);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

class _Media implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    // The scanner reads at 128 (fingerprint) and 512 (blur);
    // grid tiles read at 256 and are not analysis.
    if (size == 128 || size == 512) {
      analysisThumbnailCalls++;
    }
    return Success<Uint8List>(assetId == 'c' ? _splitPng() : _darkPng());
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  // Stage 4: memberships default to "none stored" in this fake —
  // the scanner computes them from the fake thumbnails on every
  // init, which is what these tests exercise.
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};

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
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    for (final String id in ids) {
      await setSnooze(id, null);
    }
    return const Success<void>(null);
  }

  @override
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
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
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> list) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
  }
}

void main() {
  tearDown(Get.reset);

  group('DuplicatesController', () {
    test('shows the scan exact-duplicate groups, keeper = the '
        'reference main', () async {
      final _Media media = _Media();
      final DuplicatesController controller = DuplicatesController(
        media: media,
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.ready);
      // a and b are byte-identical with identical facts: one
      // exact-duplicate group. c shares the facts but not the
      // bytes: it is in NO group on this screen.
      expect(controller.groups.length, 1);
      expect(
        controller.groups.first.assets.map((MediaAsset a) => a.id).toList(),
        <String>['a', 'b'],
      );
      // Equal scores and sizes: the main is the earliest (a).
      expect(controller.groups.first.keeperId, 'a');
      // The work happened in the scan: 3 assets x 2 passes.
      expect(media.analysisThumbnailCalls, 6);
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

    test('markSelected writes the selected marks to the duplicates '
        'session', () async {
      final _Local local = _Local();
      final DuplicatesController controller = DuplicatesController(
        media: _Media(),
        local: local,
      );
      await controller.init();
      // Navigation needs a GetMaterialApp (widget test covers
      // it); here only the durable write is asserted — the marks
      // must exist before any navigation would matter.
      await controller.markSelected().catchError((_) {});
      final DeckSession? session = local.sessions['duplicates'];
      expect(session, isNotNull);
      expect(session!.marks['a'], DeckMark.keep);
      expect(session.marks['b'], DeckMark.delete);
    });

    group('selection (Stage 7)', () {
      Future<DuplicatesController> ready(_Local local) async {
        final DuplicatesController controller = DuplicatesController(
          media: _Media(),
          local: local,
        );
        await controller.init();
        return controller;
      }

      test('every non-keeper starts selected; totals follow', () async {
        final DuplicatesController controller = await ready(_Local());
        expect(controller.duplicateCount, 1);
        expect(controller.duplicateBytes, 1000);
        expect(controller.selectedCount, 1);
        expect(controller.selectedBytes, 1000);
        expect(controller.isSelected('b'), isTrue);
        expect(controller.allSelected, isTrue);
        expect(controller.anySelected, isTrue);
      });

      test('toggling spares and re-selects; keepers never toggle', () async {
        final DuplicatesController controller = await ready(_Local());
        controller.toggleSelection('b');
        expect(controller.selectedCount, 0);
        expect(controller.anySelected, isFalse);
        controller.toggleSelection('b');
        expect(controller.selectedCount, 1);
        // The keeper and unknown ids are not selectable.
        controller.toggleSelection('a');
        controller.toggleSelection('ghost');
        expect(controller.selectedIds, <String>{'b'});
      });

      test('select all / deselect all cover every non-keeper', () async {
        final DuplicatesController controller = await ready(_Local());
        controller.deselectAll();
        expect(controller.selectedCount, 0);
        controller.selectAll();
        expect(controller.selectedIds, <String>{'b'});
      });

      test('keeper change moves the selection with the keeper', () async {
        final DuplicatesController controller = await ready(_Local());
        controller.toggleSelection('b'); // spare b first
        controller.changeKeeper(0, 'b');
        // b is the keeper now: unselected. a, the previous keeper,
        // is an ordinary non-keeper: selected by default.
        expect(controller.isSelected('b'), isFalse);
        expect(controller.isSelected('a'), isTrue);
        expect(controller.selectedCount, 1);
      });

      test('markSelected with everything spared writes nothing', () async {
        final _Local local = _Local();
        final DuplicatesController controller = await ready(local);
        controller.deselectAll();
        await controller.markSelected();
        expect(local.sessions.containsKey('duplicates'), isFalse);
      });
      // The mixed case — a spared non-keeper gets no mark while a
      // selected one is marked delete — needs 2+ non-keepers and
      // is covered in duplicates_view_test.dart.
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
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}
