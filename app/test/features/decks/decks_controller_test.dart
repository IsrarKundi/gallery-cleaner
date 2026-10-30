// Decks hub controller tests (requirements §7, Phase 2A): deck
// counts, bursts, duplicates row, denied and page-failure paths.
// Navigation itself is not asserted here (same convention as the
// review controller tests); the hub widget test covers row taps.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(
  String id, {
  int size = 1000,
  DateTime? date,
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
  bool screenshot = false,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date ?? DateTime.now(),
    title: '$id.jpg',
    albumName: album,
    // Stage 4: the screenshots deck follows the enumeration's
    // file-name marking, not the album name.
    isScreenshot: screenshot,
  );
}

/// Dark uniform PNG: identical bytes mean identical fingerprints
/// (so all images group together); its luminance puts every image
/// in the dark deck. Under Stage 4's blur rule a uniform frame has
/// NO blur measures (Cleanup's null rule), so it is never blurry —
/// the old engine flagged it blurry; that difference is the new
/// rule working as specified.
Uint8List _darkPng() {
  final img.Image image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
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

  _Media({
    this.permission = MediaPermission.grantedFull,
    this.failAssets = false,
    List<MediaAsset>? assets,
  }) : assets = assets ?? _defaultAssets();

  static List<MediaAsset> _defaultAssets() {
    final DateTime now = DateTime.now();
    // Non-burst assets sit days apart so they cannot cluster into
    // a burst run (same-instant dates would, gaps being ~0s).
    return <MediaAsset>[
      _asset(
        'shot',
        album: 'Screenshots',
        date: now.subtract(const Duration(days: 10)),
        screenshot: true,
      ),
      _asset(
        'wa',
        album: 'WhatsApp Images',
        date: now.subtract(const Duration(days: 20)),
      ),
      _asset(
        'dl',
        album: 'Downloads',
        date: now.subtract(const Duration(days: 30)),
      ),
      _asset(
        'vid',
        type: MediaAssetType.video,
        date: now.subtract(const Duration(days: 40)),
      ),
      _asset(
        'big',
        size: 11 * 1024 * 1024,
        date: now.subtract(const Duration(days: 50)),
      ),
      _asset('old', date: now.subtract(const Duration(days: 200))),
      _asset('b1', date: now),
      _asset('b2', date: now.add(const Duration(seconds: 2))),
      _asset('b3', date: now.add(const Duration(seconds: 4))),
    ];
  }

  final MediaPermission permission;
  final bool failAssets;
  final List<MediaAsset> assets;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: assets.length),
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
    if (failAssets) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    final int start = page * pageSize;
    if (start >= assets.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, assets.length);
    return Success<List<MediaAsset>>(assets.sublist(start, end));
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_darkPng());
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  // Stage 4: memberships default to "none stored" in this fake.
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
  final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};

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

  group('DecksController', () {
    test('scan fills every deck, bursts and duplicates included', () async {
      final DecksController controller = DecksController(
        media: _Media(),
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.ready);
      // Bursts still land off-isolate AFTER ready, so wait for
      // them; duplicates/blurry/dark now arrive WITH the scan
      // result (Stage 4 memberships) and need no wait.
      for (
        int waits = 0;
        controller.assetsFor(SmartDeckId.bursts).length != 3 && waits < 250;
        waits++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(controller.scanned.value, 9);
      expect(controller.assetsFor(SmartDeckId.screenshots).length, 1);
      expect(controller.assetsFor(SmartDeckId.whatsapp).length, 1);
      expect(controller.assetsFor(SmartDeckId.downloads).length, 1);
      expect(controller.assetsFor(SmartDeckId.videos).length, 1);
      expect(controller.assetsFor(SmartDeckId.large).length, 1);
      expect(controller.assetsFor(SmartDeckId.old).length, 1);
      expect(controller.assetsFor(SmartDeckId.bursts).length, 3);
      // Every image shares the dark thumbnail: the dark deck
      // holds all 8 images and they group as duplicates. The
      // blurry deck is EMPTY: a uniform frame has no blur
      // measures under the new rule (see _darkPng's doc).
      expect(controller.assetsFor(SmartDeckId.blurry).length, 0);
      expect(controller.assetsFor(SmartDeckId.dark).length, 8);
      // 7, not 8: 'shot' is screenshot-class (Stage 2 marking),
      // so it groups only with screenshots — alone, it forms no
      // group and stays out of the duplicates union. Under the
      // old engine it mixed with the photos.
      expect(controller.assetsFor(SmartDeckId.duplicates).length, 7);
      expect(controller.progress, 1.0);
    });

    test('bursts and duplicates are not ready until the scan ends', () async {
      final DecksController controller = DecksController(
        media: _Media(),
        local: _Local(),
      );
      // Before init: nothing is ready.
      expect(controller.deckReady(SmartDeckId.bursts), isFalse);
      await controller.init();
      expect(controller.deckReady(SmartDeckId.bursts), isTrue);
      expect(controller.deckReady(SmartDeckId.duplicates), isTrue);
    });

    test('denied permission shows the denied state', () async {
      final DecksController controller = DecksController(
        media: _Media(permission: MediaPermission.denied),
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.denied);
    });

    test('stage 4: hub reaches ready before bursts land; '
        'membership decks arrive with the scan', () async {
      final Completer<Set<String>> gate = Completer<Set<String>>();
      List<MediaAsset> capturedAssets = <MediaAsset>[];
      final DecksController controller = DecksController(
        media: _Media(),
        local: _Local(),
        burstRunner: (List<MediaAsset> assets) {
          capturedAssets = assets;
          return gate.future;
        },
      );
      await controller.init();
      // Ready, per-page decks filled, and the membership decks
      // (duplicates) already applied from the scan result — but
      // the gated bursts have not landed yet.
      expect(controller.status.value, DecksStatus.ready);
      expect(controller.assetsFor(SmartDeckId.screenshots).length, 1);
      expect(controller.assetsFor(SmartDeckId.duplicates).length, 7);
      expect(controller.assetsFor(SmartDeckId.bursts), isEmpty);
      // Release the gate with the direct computation over the
      // captured inputs: bursts land progressively.
      gate.complete(burstAssetIds(capturedAssets));
      for (
        int waits = 0;
        controller.assetsFor(SmartDeckId.bursts).length != 3 && waits < 250;
        waits++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(controller.assetsFor(SmartDeckId.bursts).length, 3);
    });

    test('stage 4: stale burst result is dropped', () async {
      final Completer<Set<String>> gate = Completer<Set<String>>();
      int calls = 0;
      Future<Set<String>> runner(List<MediaAsset> assets) {
        calls++;
        if (calls == 1) {
          return gate.future;
        }
        return Future<Set<String>>.value(burstAssetIds(assets));
      }

      final DecksController controller = DecksController(
        media: _Media(),
        local: _Local(),
        burstRunner: runner,
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.ready);
      expect(controller.assetsFor(SmartDeckId.bursts), isEmpty);
      // A second scan launches a newer burst computation, which
      // lands first.
      await controller.init();
      for (
        int waits = 0;
        controller.assetsFor(SmartDeckId.bursts).length != 3 && waits < 250;
        waits++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(controller.assetsFor(SmartDeckId.bursts).length, 3);
      // The first computation finally resolves — with an EMPTY
      // set. If it landed, the bursts would be wiped; the guard
      // must drop it.
      gate.complete(<String>{});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.assetsFor(SmartDeckId.bursts).length, 3);
    });

    test('failed first page with no assets shows error', () async {
      final DecksController controller = DecksController(
        media: _Media(failAssets: true),
        local: _Local(),
      );
      await controller.init();
      expect(controller.status.value, DecksStatus.error);
      expect(controller.errorKey.value, AppStrings.errorMediaLoad);
    });
  });
}
