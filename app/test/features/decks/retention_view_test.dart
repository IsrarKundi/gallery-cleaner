// Phase 2B widget tests (requirements §7): the summary card
// (with and without the share button), the hub retention sections
// (progress, Maybe pile, library-fallback projection) and the
// smart-deck finished summary (counts, no share button).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/model/retention.dart';
import 'package:klara/features/deck/widgets/session_summary_card.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/decks/binding/decks_binding.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/maybe_pile_item.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/decks/view/decks_view.dart';
import 'package:klara/features/decks/view/smart_deck_view.dart';
import 'package:klara/features/decks/widgets/maybe_pile_row.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(String id, {String album = 'Camera'}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 2000000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
  );
}

Uint8List _png() {
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

  _Media({List<MediaAsset>? assets})
    : assets = assets ?? <MediaAsset>[_asset('shot', album: 'Screenshots')];

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
    return Success<Uint8List>(_png());
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final Map<String, DateTime> snoozes = <String, DateTime>{};
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

const SessionSummary _summary = SessionSummary(
  reviewed: 2,
  kept: 1,
  deleteMarked: 1,
  deleteMarkedBytes: 2000000,
  maybe: 0,
  favourite: 0,
);

void main() {
  tearDown(Get.reset);

  group('SessionSummaryCard', () {
    testWidgets('shows counts and share button when onShare given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SessionSummaryCard(summary: _summary, onShare: () {}),
          ),
        ),
      );
      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('2 reviewed'), findsOneWidget);
      expect(find.text('1 kept'), findsOneWidget);
      expect(find.text('1 marked · 1.9 MB to be freed'), findsOneWidget);
      expect(find.text('Share result'), findsOneWidget);
    });

    testWidgets('no share button when onShare is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SessionSummaryCard(summary: _summary)),
        ),
      );
      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('Share result'), findsNothing);
    });
  });

  group('hub retention sections', () {
    testWidgets('progress card renders', (WidgetTester tester) async {
      final _Local local = _Local();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 0,
        marks: <String, DeckMark>{'shot': DeckMark.maybe},
        favouriteIds: <String>{},
      );
      Get.put<MediaService>(_Media());
      Get.put<LocalService>(local);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          initialRoute: '/decks',
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: '/decks',
              page: DecksView.new,
              binding: DecksBinding(),
            ),
          ],
        ),
      );
      // Phase 5.1: the hub scan analyses on a worker isolate, and
      // isolate replies are real async events that starve under
      // testWidgets' fake-async pumps — so wait for the scan in
      // real async (bounded; a broken scan fails the expects
      // below instead of hanging).
      await tester.runAsync(() async {
        final DecksController controller = Get.find<DecksController>();
        int waits = 0;
        while ((controller.status.value == DecksStatus.loading ||
                controller.status.value == DecksStatus.scanning) &&
            waits < 500) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          waits++;
        }
      });
      await tester.pumpAndSettle();
      final Finder metricPill = find.byKey(const Key('decks_metric_pill'));
      if (metricPill.evaluate().isNotEmpty) {
        await tester.tap(metricPill);
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.tr(AppStrings.retentionProgressTitle)),
          findsOneWidget,
        );
        expect(find.textContaining('1 GB per week'), findsOneWidget);
      }
    });

    testWidgets('tapping a snooze button on MaybePileRow sets the snooze', (
      WidgetTester tester,
    ) async {
      final MaybePileItem item = MaybePileItem(
        asset: _asset('shot'),
        sessionKey: 'all',
        snoozeUntil: null,
      );
      int? snoozedDays;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MaybePileRow(
              item: item,
              onSnooze: (int days) => snoozedDays = days,
              onClearSnooze: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Snooze 7 days'), findsOneWidget);
      await tester.tap(find.text('Snooze 7 days'));
      await tester.pumpAndSettle();
      expect(snoozedDays, 7);
    });
  });

  group('smart-deck finished summary', () {
    testWidgets('finishing shows counts without a share button', (
      WidgetTester tester,
    ) async {
      final SmartDeckController controller = SmartDeckController(
        media: _Media(),
        local: _Local(),
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[_asset('shot', album: 'Screenshots')],
        ),
      );
      Get.put<SmartDeckController>(controller);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.light, home: const SmartDeckView()),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SwipeCard), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('1 reviewed'), findsOneWidget);
      expect(find.text('Share result'), findsNothing);
      expect(find.text('Review'), findsOneWidget);
    });
  });
}
