// Hub + smart-deck widget tests (requirements §7, Phase 2A):
// rows render with counts, tapping a deck opens its swipe deck,
// and the duplicates screen groups, re-keeps and navigates to
// review with the non-keeper list.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/formatters.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/decks/binding/decks_binding.dart';
import 'package:klara/features/decks/binding/duplicates_binding.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/binding/smart_deck_binding.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/view/decks_view.dart';
import 'package:klara/features/decks/view/duplicates_view.dart';
import 'package:klara/features/decks/view/smart_deck_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(
  String id, {
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
  bool screenshot = false,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
    // Stage 4: the screenshots deck follows the enumeration's
    // name marking, not the album name.
    isScreenshot: screenshot,
  );
}

/// Stage 4: the scan makes three worker-isolate hops
/// (fingerprint, blur, membership build). An isolate reply lands
/// only when the fake zone pumps AND real time passes, so waiting
/// interleaves both — bounded, so a broken scan fails the test's
/// expects instead of hanging.
Future<void> _waitForScan(WidgetTester tester, bool Function() done) async {
  int rounds = 0;
  while (!done() && rounds < 100) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    rounds++;
  }
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
    : assets =
          assets ??
          <MediaAsset>[
            _asset('shot', album: 'Screenshots', screenshot: true),
            _asset('cam', album: 'Camera'),
          ];

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

  _Local({Map<String, PhotoAnalysis>? analyses})
    : analyses = analyses ?? <String, PhotoAnalysis>{};

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final Map<String, PhotoAnalysis> analyses;

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

  group('hub view', () {
    testWidgets('rows render and tapping a deck opens its swipe deck', (
      WidgetTester tester,
    ) async {
      Get.put<MediaService>(_Media());
      Get.put<LocalService>(_Local());
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
            GetPage<dynamic>(
              name: '/smart-deck',
              page: SmartDeckView.new,
              binding: SmartDeckBinding(),
            ),
          ],
        ),
      );
      // The hub scan computes on worker isolates; replies starve
      // under fake-async pumps alone — wait interleaved (bounded;
      // a broken scan fails the expects below instead of hanging).
      final DecksController hub = Get.find<DecksController>();
      await _waitForScan(
        tester,
        () =>
            hub.status.value != DecksStatus.loading &&
            hub.status.value != DecksStatus.scanning,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Screenshots'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Screenshots'));
      await tester.pumpAndSettle();
      expect(find.text('Screenshots'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      await tester.tap(find.text('Screenshots'));
      await tester.pumpAndSettle();
      // Smart-deck screen: same title, progress line in app bar.
      expect(find.text('0 of 1 decided'), findsOneWidget);
      expect(find.byType(SwipeCard), findsOneWidget);
    });
  });

  group('duplicates view', () {
    Future<void> pumpDuplicates(WidgetTester tester) async {
      // Stage 4: no seeded cache — the scan computes fingerprints
      // from the fake's thumbnails. All three assets share the
      // same PNG bytes and the same facts, so they form ONE exact
      // -duplicate group with 'a' as keeper (equal blur, equal
      // size, earliest first).
      Get.put<MediaService>(
        _Media(assets: <MediaAsset>[_asset('a'), _asset('b'), _asset('c')]),
      );
      Get.put<LocalService>(_Local());
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          initialRoute: '/duplicates',
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: '/duplicates',
              page: DuplicatesView.new,
              binding: DuplicatesBinding(),
            ),
            GetPage<dynamic>(
              name: '/review',
              page: () => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext context) {
                      final dynamic args = Get.arguments;
                      final int count = args is List ? args.length : -1;
                      return Text('Review $count');
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      // The duplicates screen is fed by the shared library scan
      // (worker isolates) — wait interleaved like the hub test.
      final DuplicatesController controller = Get.find<DuplicatesController>();
      await _waitForScan(
        tester,
        () => controller.status.value == DecksStatus.ready,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('group renders, keeper tap changes keeper', (
      WidgetTester tester,
    ) async {
      await pumpDuplicates(tester);
      // Stage 7 layout: the summary counts the NON-KEEPERS (b, c)
      // and their size; the group header does the same per group.
      expect(
        find.text('2 photos · ${Formatters.formatBytes(2000)}'),
        findsOneWidget,
      );
      expect(find.text('2 duplicates'), findsOneWidget);
      expect(find.text('Keeper'), findsOneWidget);
      // Stage 4 (owner decision, fix plan Stages 4+7): the
      // similarity slider is gone — matching is the scan's fixed
      // rule, there is no threshold control on this screen.
      expect(find.byType(Slider), findsNothing);
      // Second thumbnail is 'b': tapping it makes 'b' the keeper.
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Keeper'), findsOneWidget);
      expect(Get.find<DuplicatesController>().groups.first.keeperId, 'b');
    });

    testWidgets('mark selected navigates to review with two photos', (
      WidgetTester tester,
    ) async {
      await pumpDuplicates(tester);
      // Stage 7: the per-card buttons are gone; the one sticky
      // button carries the live totals of the selected (both
      // non-keepers start selected).
      await tester.tap(
        find.text(
          'Mark 2 duplicates for review · ${Formatters.formatBytes(2000)}',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review 2'), findsOneWidget);
    });
  });

  group('smart deck view', () {
    testWidgets('SwipeCard drag advances and Undo returns', (
      WidgetTester tester,
    ) async {
      final SmartDeckController controller = SmartDeckController(
        media: _Media(),
        local: _Local(),
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[_asset('shot'), _asset('cam')],
        ),
      );
      Get.put<SmartDeckController>(controller);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.light, home: const SmartDeckView()),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 decided'), findsOneWidget);
      // Swipe left to Keep
      await tester.drag(find.byType(SwipeCard), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 decided'), findsOneWidget);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 decided'), findsOneWidget);
    });
  });
}
