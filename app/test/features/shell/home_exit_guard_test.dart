// Widget tests for the app-exit guard (ADR-016 addendum; owner
// decision 31 Oct 2026): the "Before you go…" confirmation lives
// ONLY at the shell — a system back press on Home with items
// still waiting in Trash asks first ("Stay" stays, "Exit"
// exits); an empty Trash exits silently; and leaving Review
// never prompts anymore (the Stage 1 leave-guard is gone).
// The harness and fakes follow shell_test.dart; exits are
// observed on the platform channel, where SystemNavigator.pop
// lands.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/review/binding/review_binding.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/shell/binding/shell_binding.dart';
import 'package:klara/features/shell/view/shell_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _asset(String id, {MediaAssetType type = MediaAssetType.image}) {
  return MediaAsset(
    id: id,
    type: type,
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
  /// What the deck pages through (two images).
  final List<MediaAsset> assets = <MediaAsset>[_asset('a1'), _asset('a2')];

  /// Everything id resolution can find — the deck's assets plus
  /// a video that only a persisted smart session points at.
  final List<MediaAsset> resolvable = <MediaAsset>[
    _asset('a1'),
    _asset('a2'),
    _asset('v1', type: MediaAssetType.video),
  ];

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

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
    return Success<List<MediaAsset>>(
      resolvable.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
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

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    return Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }
}

/// Nav destination inside the visible NavigationBar (scoped so a
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

/// Records the platform-channel calls so a test can see the exit
/// (SystemNavigator.pop) the guard performs.
List<MethodCall> _watchPlatform(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      calls.add(call);
      return null;
    },
  );
  return calls;
}

bool _exitRequested(List<MethodCall> calls) =>
    calls.any((MethodCall call) => call.method == 'SystemNavigator.pop');

/// Simulates the Android system back button.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Marks the deck's current card for delete and lets the swipe
/// (and its undo window) fully settle, as in shell_test.dart.
Future<void> _swipeDelete(WidgetTester tester) async {
  await tester.drag(find.byType(SwipeCard), const Offset(-200, 0));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  tearDown(Get.reset);

  group('Home exit-guard', () {
    testWidgets('leaving Review with items waiting shows no popup', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _Media(), _Local(), _Trash());
      await _swipeDelete(tester);
      final DeckController deck = Get.find<DeckController>();
      expect(deck.marks['a1'], DeckMark.delete);

      // Open Review from the Trash tab: one photo waiting.
      await tester.tap(_navItem('Trash'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewView), findsOneWidget);
      expect(Get.find<ReviewController>().items, hasLength(1));

      // System back leaves Review directly — no popup anymore.
      await _pressBack(tester);
      expect(find.byType(ReviewView), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // Reopen, then leave via Review's bottom nav: still no popup.
      await tester.tap(_navItem('Trash'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewView), findsOneWidget);
      await tester.tap(_navItem('Clean'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewView), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SwipeCard), findsOneWidget);
    });

    testWidgets('shell back with items waiting asks; Stay stays, Exit exits', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local();
      // A video waiting via a persisted smart-deck session: it
      // counts toward the total even though the owner's copy says
      // "photos" (his exact words, kept deliberately).
      local.sessions['smart:videos'] = DeckSession(
        filterKey: 'smart:videos',
        currentIndex: 1,
        marks: <String, DeckMark>{'v1': DeckMark.delete},
        favouriteIds: const <String>{},
      );
      await _pumpShell(tester, _Media(), local, _Trash());
      final List<MethodCall> platform = _watchPlatform(tester);

      // One Clean-deck delete on top of the waiting video: 2 waiting.
      await _swipeDelete(tester);

      await _pressBack(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(AppStrings.tr(AppStrings.homeExitTitle)),
        findsOneWidget,
      );
      expect(find.text('Before you go…'), findsOneWidget);
      expect(
        find.text(
          AppStrings.tr(AppStrings.homeExitMessage, <String, String>{
            'count': '2',
          }),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "You still have 2 photos waiting in Trash. "
          "Everything you've decided is saved.",
        ),
        findsOneWidget,
      );
      expect(_exitRequested(platform), isFalse);

      // "Stay" dismisses the popup; the app does not exit.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.tr(AppStrings.homeExitStay)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SwipeCard), findsOneWidget);
      expect(_exitRequested(platform), isFalse);

      // Back again asks again; "Exit" performs the exit.
      await _pressBack(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.tr(AppStrings.homeExitExit)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_exitRequested(platform), isTrue);
    });

    testWidgets('shell back with an empty Trash exits silently', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _Media(), _Local(), _Trash());
      final List<MethodCall> platform = _watchPlatform(tester);

      await _pressBack(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_exitRequested(platform), isTrue);
    });
  });
}
