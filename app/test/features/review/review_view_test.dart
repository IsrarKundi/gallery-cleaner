// ReviewView widget tests: grid + header, unmark tap, delete
// success navigation, denied dialog, and the failed error state.
// Fakes are local to this file (no device).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/review/widgets/review_grid_tile.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1x1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
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

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
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
    return Success<Uint8List>(_png);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<HistoryRecord> history = <HistoryRecord>[];

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

class _Trash implements TrashService {
  _Trash({
    this.deniedIds = const <String>{},
    this.failedIds = const <String>{},
  });

  final Set<String> deniedIds;
  final Set<String> failedIds;

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    final List<String> trashed = <String>[];
    final List<String> denied = <String>[];
    final List<String> failed = <String>[];
    for (final String id in ids) {
      if (failedIds.contains(id)) {
        failed.add(id);
      } else if (deniedIds.contains(id)) {
        denied.add(id);
      } else {
        trashed.add(id);
      }
    }
    return Success<TrashOutcome>(
      TrashOutcome(trashedIds: trashed, deniedIds: denied, failedIds: failed),
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

Future<void> _pump(WidgetTester tester, ReviewController controller) async {
  Get.put<ReviewController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      // Named routes like the real app: a `home:` route would itself
      // be named '/', colliding with the deck navigation under test.
      initialRoute: '/review',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(name: '/review', page: () => const ReviewView()),
        GetPage<dynamic>(
          name: '/',
          page: () => const Scaffold(body: Text('deck-dummy')),
        ),
        GetPage<dynamic>(
          name: '/trash',
          page: () => const Scaffold(body: Text('trash-dummy')),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ReviewController _controller(_Local local, _Trash trash) {
  local.sessions['all'] = DeckSession(
    filterKey: 'all',
    currentIndex: 0,
    marks: <String, DeckMark>{'a': DeckMark.delete, 'b': DeckMark.delete},
    favouriteIds: <String>{},
  );
  return ReviewController(
    media: _Media(),
    trash: trash,
    local: local,
    initialAssets: <MediaAsset>[_asset('a', 1000000), _asset('b', 2000000)],
    filterKeyOverride: 'all',
  );
}

void main() {
  tearDown(Get.reset);

  group('ReviewView', () {
    // Owner design change 26 Oct 2026 (c8ec4e3): the header
    // (count + total size + unmark hint) is removed from the
    // layout, so the screen shows the grid and the delete
    // action only. Nothing here restores the header.
    testWidgets('shows grid and delete action without the header', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _controller(_Local(), _Trash()));
      expect(find.byType(ReviewGridTile), findsNWidgets(2));
      expect(find.text('2 · 2.9 MB'), findsNothing);
      expect(
        find.text(AppStrings.tr(AppStrings.reviewUnmarkHint)),
        findsNothing,
      );
      expect(find.text('Delete 2 photos'), findsOneWidget);
    });

    testWidgets('tapping a tile unmarks it', (WidgetTester tester) async {
      await _pump(tester, _controller(_Local(), _Trash()));
      await tester.tap(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewGridTile), findsOneWidget);
      expect(find.text('Delete 1 photos'), findsOneWidget);
    });

    testWidgets('delete success navigates to trash', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _controller(_Local(), _Trash()));
      await tester.tap(find.text('Delete 2 photos'));
      await tester.pumpAndSettle();
      expect(find.text('trash-dummy'), findsOneWidget);
    });

    testWidgets('denied shows the explanation then goes to deck', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _controller(_Local(), _Trash(deniedIds: <String>{'a', 'b'})),
      );
      await tester.tap(find.text('Delete 2 photos'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.deniedConfirmTitle)),
        findsOneWidget,
      );
      await tester.tap(find.text(AppStrings.tr(AppStrings.actionOk)));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
    });

    testWidgets('failed shows the error state with retry', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _controller(_Local(), _Trash(failedIds: <String>{'a', 'b'})),
      );
      await tester.tap(find.text('Delete 2 photos'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.tr(AppStrings.errorTrash)), findsOneWidget);
      expect(find.text(AppStrings.tr(AppStrings.errorRetry)), findsOneWidget);
    });

    testWidgets('empty set shows the empty state', (WidgetTester tester) async {
      final _Local local = _Local();
      await _pump(tester, _controller(local, _Trash()));
      await tester.tap(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.reviewEmptyTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.actionBackToDeck)),
        findsOneWidget,
      );
    });
  });
}
