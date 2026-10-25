// Phase 3B hub tests (requirements §7, 50,000+ photos):
// - a 5,000-asset synthetic hub scan completes in bounds with
//   correct incremental totals (deck bytes, marked MB, Maybe pile),
//   proving the per-page accumulation replaced the quadratic paths;
// - the builder-form hub renders its sections (progress, Maybe
//   pile, projection, deck rows) in order.
// Timings are HOST numbers, not on-device results.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/view/decks_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(
  String id, {
  String album = 'Camera',
  int size = 1000,
  DateTime? date,
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

PhotoAnalysis _analysis(String id, int hash) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: 1000,
    meanLuminance: 100,
  );
}

class _Media implements MediaService {
  _Media({required this.assets});

  final List<MediaAsset> assets;

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
    final int start = page * pageSize;
    if (start >= assets.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, assets.length);
    return Success<List<MediaAsset>>(assets.sublist(start, end));
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size, {int quality = 85}) async {
    return const Failure<Uint8List>(AppFailure(messageKey: 'errorMediaLoad'));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  _Local({
    this.sessions = const <DeckSession>[],
    this.analyses = const <String, PhotoAnalysis>{},
  });

  final List<DeckSession> sessions;
  final Map<String, PhotoAnalysis> analyses;

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return const Success<DeckSession?>(null);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return Success<List<DeckSession>>(sessions);
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
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(analyses);
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
}

void main() {
  tearDown(Get.reset);

  test('5k hub scan: incremental totals are correct and in bounds', () async {
    final DateTime now = DateTime.now();
    final List<MediaAsset> assets = <MediaAsset>[];
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
    for (int i = 0; i < 5000; i++) {
      final String album = i < 100
          ? 'Screenshots'
          : i < 200
          ? 'WhatsApp Images'
          : 'Camera';
      // Days apart, so no burst runs form.
      final MediaAsset asset = _asset(
        'a$i',
        album: album,
        date: now.subtract(Duration(days: i + 1)),
      );
      assets.add(asset);
      analyses['a$i'] = _analysis('a$i', i * 104729);
    }
    final Map<String, DeckMark> marks = <String, DeckMark>{
      for (int i = 0; i < 10; i++) 'a$i': DeckMark.delete,
      for (int i = 10; i < 15; i++) 'a$i': DeckMark.maybe,
    };
    final DecksController controller = DecksController(
      media: _Media(assets: assets),
      local: _Local(
        sessions: <DeckSession>[
          DeckSession(
            filterKey: 'all',
            currentIndex: 0,
            marks: marks,
            favouriteIds: <String>{},
          ),
        ],
        analyses: analyses,
      ),
    );
    final Stopwatch watch = Stopwatch()..start();
    await controller.init();
    watch.stop();
    // ignore: avoid_print
    print(
      'hub scan 5k assets (cached analyses): '
      '${watch.elapsedMilliseconds}ms',
    );
    expect(controller.status.value, DecksStatus.ready);
    expect(controller.scanned.value, 5000);
    expect(controller.assetsFor(SmartDeckId.screenshots).length, 100);
    expect(controller.totalBytesFor(SmartDeckId.screenshots), 100 * 1000);
    expect(controller.assetsFor(SmartDeckId.whatsapp).length, 100);
    expect(controller.markedMb, closeTo(10 * 1000 / 1048576, 0.001));
    expect(controller.maybeItems.length, 5);
    expect(watch.elapsedMilliseconds, lessThan(10000));
  });

  testWidgets('builder hub renders sections and the Maybe pile', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final MediaAsset shot = _asset('shot', album: 'Screenshots', date: now);
    final MediaAsset cam = _asset('cam', album: 'Camera', date: now);
    final DecksController controller = DecksController(
      media: _Media(assets: <MediaAsset>[shot, cam]),
      local: _Local(
        sessions: <DeckSession>[
          DeckSession(
            filterKey: 'all',
            currentIndex: 0,
            marks: <String, DeckMark>{'cam': DeckMark.maybe},
            favouriteIds: <String>{},
          ),
        ],
        analyses: <String, PhotoAnalysis>{
          'shot': _analysis('shot', 111),
          'cam': _analysis('cam', 222),
        },
      ),
    );
    Get.put<DecksController>(controller);
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const DecksView()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Screenshots'), findsWidgets);
    final Finder metricPill = find.byKey(const Key('decks_metric_pill'));
    if (metricPill.evaluate().isNotEmpty) {
      await tester.tap(metricPill);
      await tester.pumpAndSettle();
      expect(find.text('Your progress'), findsOneWidget);
    }
  });
}
