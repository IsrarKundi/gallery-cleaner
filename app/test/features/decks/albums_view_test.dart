// All Albums widget tests (ADR-027, requirements §7): the
// list renders albums with counts and covers; the hub's
// "See all" navigates here; tapping an album opens the swipe
// deck titled with the album's name, holding the album's
// photos. Harnesses follow decks_view_test.dart (fake services
// registered in Get, real bindings, small route tables).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/decks/binding/albums_binding.dart';
import 'package:klara/features/decks/binding/decks_binding.dart';
import 'package:klara/features/decks/binding/smart_deck_binding.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/view/albums_view.dart';
import 'package:klara/features/decks/view/decks_view.dart';
import 'package:klara/features/decks/view/smart_deck_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

/// A valid 1x1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(
  String id, {
  String album = 'Camera',
  bool screenshot = false,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
    isScreenshot: screenshot,
  );
}

/// The hub scan computes on worker isolates; replies starve
/// under fake-async pumps alone — wait interleaved (bounded;
/// copied from decks_view_test.dart).
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

class _Media implements MediaService {
  final List<MediaAsset> library = <MediaAsset>[
    _asset('s1', album: 'Screenshots', screenshot: true),
    _asset('c1'),
    _asset('c2'),
  ];

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 3),
      MediaAlbum(id: 'cam', name: 'Camera', count: 2),
      MediaAlbum(id: 'shots', name: 'Screenshots', count: 1),
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
    final List<MediaAsset> filtered = switch (albumId) {
      'cam' =>
        library.where((MediaAsset a) => a.albumName == 'Camera').toList(),
      'shots' =>
        library.where((MediaAsset a) => a.albumName == 'Screenshots').toList(),
      _ => library,
    };
    final int start = page * pageSize;
    if (start >= filtered.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = start + pageSize > filtered.length
        ? filtered.length
        : start + pageSize;
    return Success<List<MediaAsset>>(filtered.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      Success<List<MediaAsset>>(
        library.where((MediaAsset a) => ids.contains(a.id)).toList(),
      );

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(_png);
}

class _Local implements LocalService {
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async =>
      const Success<int>(0);

  final Map<String, DeckSession> sessions = <String, DeckSession>{};

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      Success<DeckSession?>(sessions[filterKey]);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      const Success<List<DeckSession>>(<DeckSession>[]);

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      const Success<Map<String, DateTime>>(<String, DateTime>{});

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async =>
      const Success<double>(1024);

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
      const Success<void>(null);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      const Success<List<DateTime>>(<DateTime>[]);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  final Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    for (final PhotoAnalysis a in analyses) {
      _analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      Success<Map<String, PhotoAnalysis>>(
        Map<String, PhotoAnalysis>.of(_analyses),
      );

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);
}

void main() {
  tearDown(Get.reset);

  testWidgets('albums list renders names, counts and covers', (
    WidgetTester tester,
  ) async {
    Get.put<MediaService>(_Media());
    Get.put<LocalService>(_Local());
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        initialRoute: '/albums',
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: '/albums',
            page: AlbumsView.new,
            binding: AlbumsBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    // Trailing counts, as served by the media service.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // Covers render from the thumbnail service once resolved.
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('hub See all opens the All Albums screen', (
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
            name: '/albums',
            page: AlbumsView.new,
            binding: AlbumsBinding(),
          ),
        ],
      ),
    );
    final DecksController hub = Get.find<DecksController>();
    await _waitForScan(
      tester,
      () =>
          hub.status.value != DecksStatus.loading &&
          hub.status.value != DecksStatus.scanning,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('See all'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('See all'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumsView), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('tapping an album opens its swipe deck under its name', (
    WidgetTester tester,
  ) async {
    Get.put<MediaService>(_Media());
    Get.put<LocalService>(_Local());
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        initialRoute: '/albums',
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: '/albums',
            page: AlbumsView.new,
            binding: AlbumsBinding(),
          ),
          GetPage<dynamic>(
            name: '/smart-deck',
            page: SmartDeckView.new,
            binding: SmartDeckBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(find.byType(SmartDeckView), findsOneWidget);
    // The deck is titled with the album's name and holds
    // exactly the album's two photos.
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('0 of 2 decided'), findsOneWidget);
    expect(find.byType(SwipeCard), findsOneWidget);
  });
}
