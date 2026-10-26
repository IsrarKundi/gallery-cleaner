// Shell + settled-review-gate widget tests (requirements §6,
// Phase 7.1): tab round-trips keep the deck and hub alive (no
// re-scan, no deck reload); Trash opens a fresh Review with the
// current delete set, growing on a second visit; a Trash tap
// during a card exit waits for the mark, then Review includes it;
// a tab switch during a card exit never drops the mark.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/review/binding/review_binding.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/review/widgets/review_loading_skeleton.dart';
import 'package:klara/features/shell/binding/shell_binding.dart';
import 'package:klara/features/shell/controller/shell_controller.dart';
import 'package:klara/features/shell/view/shell_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

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

Uint8List _png() {
  final img.Image image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

class _Media implements MediaService {
  int permissionCalls = 0;
  int getAssetsCalls = 0;

  final List<MediaAsset> assets = <MediaAsset>[_asset('a1'), _asset('a2')];

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    permissionCalls++;
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 2),
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
    getAssetsCalls++;
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
    // Session-path Review resolves its delete set through here;
    // returning empty would make every fresh Review look empty.
    return Success<List<MediaAsset>>(
      assets.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async =>
      const Success<int>(0);

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
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
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
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return Success<List<HistoryRecord>>(history);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

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

class _Trash implements TrashService {
  final List<TrashEntry> entries = <TrashEntry>[];

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    final DateTime now = DateTime.now();
    entries.addAll(<TrashEntry>[
      for (final String id in ids)
        TrashEntry(
          assetId: id,
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          trashedAt: now,
        ),
    ]);
    return Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    entries.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    return Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return Success<List<TrashEntry>>(entries);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    final List<String> removed = entries
        .map((TrashEntry e) => e.assetId)
        .toList();
    entries.clear();
    return Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: removed,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }
}

/// Nav destination inside the shell's NavigationBar (scoped so a
/// tab's own content text can never match instead).
Finder _navItem(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  _Media media,
  _Local local,
  _Trash trash,
) async {
  Get.put<MediaService>(media, permanent: true);
  Get.put<LocalService>(local, permanent: true);
  Get.put<TrashService>(trash, permanent: true);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      initialRoute: AppRoutes.deck,
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: AppRoutes.deck,
          page: ShellView.new,
          binding: ShellBinding(),
        ),
        GetPage<dynamic>(
          name: AppRoutes.review,
          page: ReviewView.new,
          binding: ReviewBinding(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/// Hub scan work runs on a worker isolate, whose replies starve
/// under fake-async pumps — wait for it in real async (bounded),
/// the pattern from decks_view_test.dart.
Future<void> _waitHubSettled() async {
  final DecksController hub = Get.find<DecksController>();
  int waits = 0;
  while ((hub.status.value == DecksStatus.loading ||
          hub.status.value == DecksStatus.scanning) &&
      waits < 500) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    waits++;
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets('tab round-trips keep the deck and hub alive', (
    WidgetTester tester,
  ) async {
    final _Media media = _Media();
    await _pumpShell(tester, media, _Local(), _Trash());
    final DeckController deck = Get.find<DeckController>();
    expect(deck.queue.length, 2);

    // First visit of every tab (hub scan completes here).
    await tester.tap(_navItem('Decks'));
    await tester.runAsync(_waitHubSettled);
    await tester.pumpAndSettle();
    final DecksController hub = Get.find<DecksController>();
    await tester.tap(_navItem('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(_navItem('Clean'));
    await tester.pumpAndSettle();

    final int assetsBaseline = media.getAssetsCalls;
    final int permissionBaseline = media.permissionCalls;

    // Five full round-trips: no reload, no re-scan, same instances.
    for (int i = 0; i < 5; i++) {
      await tester.tap(_navItem('Decks'));
      await tester.pumpAndSettle();
      await tester.tap(_navItem('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(_navItem('Clean'));
      await tester.pumpAndSettle();
      expect(identical(Get.find<DeckController>(), deck), isTrue);
      expect(identical(Get.find<DecksController>(), hub), isTrue);
      expect(deck.queue.length, 2);
      expect(deck.currentIndex.value, 0);
    }
    expect(media.getAssetsCalls, assetsBaseline);
    expect(media.permissionCalls, permissionBaseline);
  });

  testWidgets('Trash opens Review with the pending delete in its window', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, _Media(), _Local(), _Trash());

    // Mark a1, then Trash inside the 2s window: Review shows the
    // pending delete set (ADR-013), not the skeleton (ADR-012).
    // The exit needs two pumps to record the mark; the window
    // then runs from the mark, so the tap lands well inside it.
    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(_navItem('Trash'));
    // A few frames for the gate and the push to land; still far
    // inside the 2s window.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(ReviewLoadingSkeleton), findsNothing);
    expect(find.text('Delete 1 photos'), findsOneWidget);
  });

  testWidgets('committed deletes flush to trash on leaving Clean', (
    WidgetTester tester,
  ) async {
    final _Trash trash = _Trash();
    await _pumpShell(tester, _Media(), _Local(), trash);
    final DeckController deck = Get.find<DeckController>();

    // Mark a1 and let the window lapse: the delete commits to
    // the trash pipeline. The exit needs two pumps to record
    // the mark; the third advances the clock past the 2s timer
    // (pumpAndSettle alone stops once frames settle, so it
    // never runs the timer out).
    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(deck.awaitingTrash.map((MediaAsset a) => a.id).toList(), <String>[
      'a1',
    ]);

    // Leaving Clean fires one native batch for the commit.
    await tester.tap(_navItem('Decks'));
    await tester.runAsync(_waitHubSettled);
    await tester.pumpAndSettle();
    expect(trash.entries.map((TrashEntry e) => e.assetId).toList(), <String>[
      'a1',
    ]);
    expect(deck.awaitingTrash, isEmpty);
  });

  testWidgets('Trash opens Review with content on the first frame', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, _Media(), _Local(), _Trash());

    // Mark a1, then Trash: the delete set travels as route
    // arguments, so the first Review frame already shows the
    // count and buttons — never the loading skeleton (ADR-012).
    // The tap waits on the exit gate, so the mark is recorded
    // and the 2s window is still open when Review lands.
    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(_navItem('Trash'));
    // Step through the push transition frame by frame: the delete
    // set travels as route arguments, so no frame may show the
    // loading skeleton, and the count is there once Review lands.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(ReviewLoadingSkeleton), findsNothing);
    }
    expect(find.text('Delete 1 photos'), findsOneWidget);
  });

  testWidgets('Trash round-trip keeps the shell and its tabs alive', (
    WidgetTester tester,
  ) async {
    final _Media media = _Media();
    await _pumpShell(tester, media, _Local(), _Trash());
    final ShellController shell = Get.find<ShellController>();
    final DeckController deck = Get.find<DeckController>();

    // Visit Decks so the hub is mounted, then Trash and back.
    await tester.tap(_navItem('Decks'));
    await tester.runAsync(_waitHubSettled);
    await tester.pumpAndSettle();
    final DecksController hub = Get.find<DecksController>();
    final int assetsBaseline = media.getAssetsCalls;
    final int permissionBaseline = media.permissionCalls;

    await tester.tap(_navItem('Trash'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewView), findsOneWidget);

    // Return via Review's own bottom nav: same shell, same tab
    // controllers, no reload, no re-scan.
    await tester.tap(_navItem('Decks'));
    await tester.pumpAndSettle();
    expect(identical(Get.find<ShellController>(), shell), isTrue);
    expect(identical(Get.find<DeckController>(), deck), isTrue);
    expect(identical(Get.find<DecksController>(), hub), isTrue);
    expect(media.getAssetsCalls, assetsBaseline);
    expect(media.permissionCalls, permissionBaseline);

    // And again through Trash to Clean: still the same shell.
    await tester.tap(_navItem('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(_navItem('Clean'));
    await tester.pumpAndSettle();
    expect(identical(Get.find<ShellController>(), shell), isTrue);
    expect(identical(Get.find<DeckController>(), deck), isTrue);
    expect(deck.queue.length, 2);
  });

  testWidgets('Trash tap during a card exit waits for the mark', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, _Media(), _Local(), _Trash());
    final DeckController deck = Get.find<DeckController>();

    // Start a swipe and tap Trash mid-flight (150 ms of 300 ms):
    // Review must NOT open while the mark is unrecorded.
    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(deck.isCardExiting, isTrue);
    await tester.tap(_navItem('Trash'));
    await tester.pump();
    expect(find.byType(SwipeCard), findsOneWidget);
    expect(find.text('Delete 1 photos'), findsNothing);

    // The flight ends, the mark records, and only then does the
    // deferred Review open — with the in-flight mark included.
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 photos'), findsOneWidget);
  });

  testWidgets('tab switch during a card exit never drops the mark', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, _Media(), _Local(), _Trash());
    final DeckController deck = Get.find<DeckController>();

    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(deck.isCardExiting, isTrue);

    // Retained switch: the deck stays mounted off-stage, so its
    // flight completes and the mark records (the old off-all nav
    // destroyed the deck here and lost the mark).
    await tester.tap(_navItem('Decks'));
    await tester.runAsync(_waitHubSettled);
    await tester.pumpAndSettle();
    expect(identical(Get.find<DeckController>(), deck), isTrue);
    expect(deck.marks['a1'], DeckMark.delete);
    expect(deck.currentIndex.value, 1);

    await tester.tap(_navItem('Clean'));
    await tester.pumpAndSettle();
    expect(find.byType(SwipeCard), findsOneWidget);
    expect(deck.marks['a1'], DeckMark.delete);
  });
}
