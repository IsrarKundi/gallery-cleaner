// Phase 2B hub retention controller tests (requirements §7):
// Maybe pile gathering + snooze actions, goal progress, streaks,
// storage projection (device + library fallback) and the On This
// Day deck. Navigation is not asserted (same convention as the
// other hub controller tests).

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
import 'package:klara/services/storage/storage_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(
  String id, {
  int size = 1000,
  DateTime? date,
  String album = 'Camera',
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date ?? DateTime.now(),
    title: '$id.jpg',
    albumName: album,
  );
}

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

  _Media({List<MediaAsset>? assets}) : assets = assets ?? _defaultAssets();

  static List<MediaAsset> _defaultAssets() {
    final DateTime now = DateTime.now();
    return <MediaAsset>[
      _asset('maybe1', date: now.subtract(const Duration(days: 10))),
      _asset('onthisday', date: DateTime(now.year - 1, now.month, now.day)),
      _asset(
        'pastMonthDiffDay',
        date: DateTime(now.year - 2, now.month, now.day == 1 ? 2 : 1),
      ),
      _asset('today', date: now),
      _asset(
        'shot',
        album: 'Screenshots',
        date: now.subtract(const Duration(days: 20)),
      ),
    ];
  }

  final List<MediaAsset> assets;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
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
    if (page > 0) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    return Success<List<MediaAsset>>(assets);
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
  final Map<String, DateTime> snoozes = <String, DateTime>{};
  final List<HistoryRecord> history = <HistoryRecord>[];
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<DateTime> completions = <DateTime>[];
  double goalMb = 1024;
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
    return Success<List<DeckSession>>(sessions.values.toList());
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return Success<Map<String, DateTime>>(Map<String, DateTime>.of(snoozes));
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    if (until == null) {
      snoozes.remove(assetId);
    } else {
      snoozes[assetId] = until;
    }
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
    return Success<double>(goalMb);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    goalMb = mb;
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return Success<List<DateTime>>(List<DateTime>.of(completions));
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    completions.add(day);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    trash.addAll(entries);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return Success<List<TrashEntry>>(List<TrashEntry>.of(trash));
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    trash.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    trash.clear();
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return Success<List<HistoryRecord>>(List<HistoryRecord>.of(history));
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

class _Storage implements StorageService {
  _Storage({this.freeMb = 1200});

  final double? freeMb;

  @override
  Future<Result<double>> getFreeMb() async {
    if (freeMb == null) {
      return const Failure<double>(
        AppFailure(messageKey: AppStrings.errorStorage),
      );
    }
    return Success<double>(freeMb!);
  }
}

TrashEntry _trash(String id, int size) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: size,
    trashedAt: DateTime.now(),
  );
}

Future<DecksController> _readyController(
  _Local local, {
  StorageService? storage,
}) async {
  final DecksController controller = DecksController(
    media: _Media(),
    local: local,
    storage: storage,
  );
  await controller.init();
  expect(controller.status.value, DecksStatus.ready);
  return controller;
}

void main() {
  tearDown(Get.reset);

  group('DecksController retention', () {
    test('maybe pile gathers maybe marks with snooze state', () async {
      final _Local local = _Local();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 0,
        marks: <String, DeckMark>{
          'maybe1': DeckMark.maybe,
          'shot': DeckMark.keep,
        },
        favouriteIds: <String>{},
      );
      local.snoozes['maybe1'] = DateTime.now().add(const Duration(days: 7));
      final DecksController controller = await _readyController(local);
      final items = controller.maybeItems;
      expect(items.length, 1);
      expect(items.first.asset.id, 'maybe1');
      expect(items.first.snoozeUntil, isNotNull);
    });

    test('snooze and clear-snooze update the record', () async {
      final _Local local = _Local();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 0,
        marks: <String, DeckMark>{'maybe1': DeckMark.maybe},
        favouriteIds: <String>{},
      );
      final DecksController controller = await _readyController(local);
      final item = controller.maybeItems.first;
      await controller.snoozeItem(item, 14);
      expect(local.snoozes['maybe1'], isNotNull);
      expect(controller.snoozes['maybe1'], isNotNull);
      await controller.clearSnoozeItem(item);
      expect(local.snoozes.containsKey('maybe1'), isFalse);
    });

    test('goal progress counts freed MB this week only', () async {
      final _Local local = _Local();
      final DateTime monday = DateTime.now().subtract(
        Duration(days: DateTime.now().weekday - 1),
      );
      local.history.addAll(<HistoryRecord>[
        HistoryRecord(date: monday, count: 1, mbTrashed: 900, mbFreed: 256),
        HistoryRecord(
          date: monday.subtract(const Duration(days: 7)),
          count: 1,
          mbTrashed: 0,
          mbFreed: 9999,
        ),
      ]);
      final DecksController controller = await _readyController(local);
      expect(controller.weekFreedMbValue, 256);
      expect(controller.goalProgress, closeTo(0.25, 0.001));
      await controller.setGoal(512);
      expect(controller.goalTargetMb.value, 512);
      expect(local.goalMb, 512);
    });

    test('streak combines completion days and history days', () async {
      final _Local local = _Local();
      final DateTime today = DateTime.now();
      local.completions.add(today.subtract(const Duration(days: 1)));
      local.history.add(
        HistoryRecord(date: today, count: 1, mbTrashed: 10, mbFreed: 0),
      );
      final DecksController controller = await _readyController(local);
      expect(controller.streak.current, 2);
      expect(controller.streak.best, 2);
    });

    test('projection adds in-trash MB to device free storage', () async {
      final _Local local = _Local();
      local.trash.add(_trash('x', 350 * 1024 * 1024));
      final DecksController controller = await _readyController(
        local,
        storage: _Storage(freeMb: 1200),
      );
      expect(controller.freeMb.value, 1200);
      expect(controller.inTrashMb, closeTo(350, 0.001));
      expect(controller.projectedFreeMbValue, closeTo(1550, 0.001));
    });

    test('without a storage backend the projection is library-only', () async {
      final _Local local = _Local();
      local.trash.add(_trash('x', 1000));
      final DecksController controller = await _readyController(local);
      expect(controller.freeMb.value, isNull);
      expect(controller.projectedFreeMbValue, isNull);
      expect(controller.inTrashMb, greaterThan(0));
    });

    test(
      'On This Day holds previous-year same-month matches and today photos',
      () async {
        final DecksController controller = await _readyController(_Local());
        final List<String> ids = controller
            .assetsFor(SmartDeckId.onThisDay)
            .map((MediaAsset a) => a.id)
            .toList();
        expect(ids, contains('onthisday'));
        expect(ids, contains('pastMonthDiffDay'));
        expect(ids, contains('today'));
        expect(ids, isNot(contains('maybe1')));
      },
    );
  });
}
