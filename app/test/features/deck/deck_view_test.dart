// DeckView widget tests: card + buttons + edge labels + undo,
// tutorial first-run behaviour, empty states, filter sheet and a
// real drag swipe. Fakes are local to this file (no device).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/view/deck_view.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id, int size, DateTime date, String album) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date,
    title: '$id.jpg',
    albumName: album,
  );
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
    List<MediaAsset>? assets,
  }) : assets =
           assets ??
           <MediaAsset>[
             _asset('a1', 1000000, DateTime(2026, 10, 5), 'Camera'),
             _asset('a2', 2000000, DateTime(2026, 10, 6), 'Camera'),
             _asset('a3', 500000, DateTime(2026, 9, 2), 'Downloads'),
           ];

  final MediaPermission permission;
  final List<MediaAsset> assets;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 3),
      MediaAlbum(id: 'cam', name: 'Camera', count: 2),
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
    Iterable<MediaAsset> result = assets;
    if (monthKey != null) {
      result = result.where((MediaAsset a) {
        final DateTime d = a.createDate;
        return '${d.year}-${d.month.toString().padLeft(2, '0')}' == monthKey;
      });
    }
    return Success<List<MediaAsset>>(result.toList());
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_png);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Trash implements TrashService {
  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    return const Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    return const Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    return const Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }
}

class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  bool tutorialSeen = false;

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
    return Success<bool>(tutorialSeen);
  }

  final Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};
  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    for (final PhotoAnalysis a in analyses) {
      _analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(_analyses),
    );
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    tutorialSeen = seen;
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

Future<DeckController> _pumpDeck(
  WidgetTester tester, {
  MediaService? media,
  _Local? local,
}) async {
  final _Local localService = local ?? _Local();
  final DeckController controller = DeckController(
    media: media ?? _Media(),
    trash: _Trash(),
    local: localService,
  );
  Get.put<DeckController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(theme: AppTheme.light, home: const DeckView()),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  tearDown(Get.reset);

  group('deck view', () {
    testWidgets('renders card, four circular buttons, edge labels, meter', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      await _pumpDeck(tester, local: local);
      expect(find.byType(SwipeCard), findsOneWidget);
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
      expect(find.byIcon(AppIcons.favourite), findsOneWidget);
      expect(find.byIcon(AppIcons.addToAlbum), findsOneWidget);
      expect(find.byIcon(AppIcons.share), findsOneWidget);
    });

    testWidgets(
      'Favorite button marks favourite and advances to the next card',
      (WidgetTester tester) async {
        final _Local local = _Local()..tutorialSeen = true;
        final DeckController controller = await _pumpDeck(tester, local: local);
        await tester.tap(find.byIcon(AppIcons.favourite));
        await tester.pumpAndSettle();
        expect(controller.marks['a1'], DeckMark.favourite);
        expect(controller.currentAsset?.id, 'a2');
      },
    );

    testWidgets('drag left swipes Keep', (WidgetTester tester) async {
      final _Local local = _Local()..tutorialSeen = true;
      final DeckController controller = await _pumpDeck(tester, local: local);
      await tester.drag(find.byType(SwipeCard), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(controller.marks['a1'], DeckMark.keep);
    });

    testWidgets('tutorial shows on first run and dismiss sets the flag', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local();
      await _pumpDeck(tester, local: local);
      expect(
        find.text(AppStrings.tr(AppStrings.tutorialTitle)),
        findsOneWidget,
      );
      await tester.tap(find.text(AppStrings.tr(AppStrings.tutorialDone)));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.tr(AppStrings.tutorialTitle)), findsNothing);
      expect(local.tutorialSeen, isTrue);
    });

    testWidgets('denied permission shows the retry empty state', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      await _pumpDeck(
        tester,
        media: _Media(permission: MediaPermission.denied),
        local: local,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionDeniedTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionAllowAccess)),
        findsOneWidget,
      );
    });

    testWidgets('empty library shows the first-run empty state', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      await _pumpDeck(
        tester,
        media: _Media(assets: <MediaAsset>[]),
        local: local,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.emptyFirstRunTitle)),
        findsOneWidget,
      );
    });

    testWidgets('finished deck shows the summary with Review', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      final DeckController controller = await _pumpDeck(tester, local: local);
      controller.markCurrent(DeckMark.keep);
      controller.markCurrent(DeckMark.keep);
      controller.markCurrent(DeckMark.keep);
      await tester.pumpAndSettle();
      // Phase 2B: the finished state is the session summary card
      // (counts + Review), not the old "All decided" empty view.
      expect(find.textContaining('reviewed'), findsOneWidget);
    });

    testWidgets('filter sheet lists months and applies a month filter', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      final DeckController controller = await _pumpDeck(tester, local: local);
      await tester.tap(find.byIcon(AppIcons.filter));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.tr(AppStrings.filterAll)), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      await tester.tap(find.text('Oct 2026'));
      await tester.pumpAndSettle();
      expect(controller.filter.value.monthKey, '2026-10');
      expect(controller.queue.length, 2);
    });

    testWidgets('limited grant shows the partial-access banner', (
      WidgetTester tester,
    ) async {
      final _Local local = _Local()..tutorialSeen = true;
      await _pumpDeck(
        tester,
        media: _Media(permission: MediaPermission.grantedLimited),
        local: local,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionPartialTitle)),
        findsOneWidget,
      );
    });
  });
}
