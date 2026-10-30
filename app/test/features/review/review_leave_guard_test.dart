// Widget tests for the Review leave-guard (fix plan Stage 1,
// requirements §4): leaving Review via the bottom nav while
// photos still wait in the grid asks first ("Open Review"
// stays, "Save and Exit" leaves), and an empty grid never
// prompts. The harness and fakes follow review_view_test.dart
// (checker gap, stage-1-check.md §5).

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
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async =>
      const Success<List<MediaAlbum>>(<MediaAlbum>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async => const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(_png);

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      const Success<List<MediaAsset>>(<MediaAsset>[]);
}

class _Local implements LocalService {
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

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async =>
      const Success<int>(0);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);
}

class _Trash implements TrashService {
  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async =>
      Success<DeleteOutcome>(
        DeleteOutcome(
          deletedIds: ids,
          deniedIds: const <String>[],
          failedIds: const <String>[],
        ),
      );

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async =>
      Success<TrashOutcome>(
        TrashOutcome(
          trashedIds: ids,
          deniedIds: const <String>[],
          failedIds: const <String>[],
        ),
      );

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async =>
      const Success<RestoreOutcome>(
        RestoreOutcome(
          restoredIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async =>
      const Success<EmptyTrashOutcome>(
        EmptyTrashOutcome(
          removedIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );
}

Future<void> _pump(WidgetTester tester, ReviewController controller) async {
  Get.put<ReviewController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
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

ReviewController _controller(List<MediaAsset> assets) {
  return ReviewController(
    media: _Media(),
    trash: _Trash(),
    local: _Local(),
    initialAssets: assets,
    filterKeyOverride: 'all',
  );
}

void main() {
  tearDown(Get.reset);

  group('Review leave-guard', () {
    testWidgets('leaving with photos waiting asks first', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _controller(<MediaAsset>[_asset('a', 1000000), _asset('b', 2000000)]),
      );
      expect(find.byType(ReviewGridTile), findsNWidgets(2));

      // Bottom-nav exit with 2 photos waiting: the guard asks.
      await tester.tap(find.text(AppStrings.tr(AppStrings.navClean)));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.reviewLeaveTitle)),
        findsOneWidget,
      );
      expect(
        find.text(
          AppStrings.tr(AppStrings.reviewLeaveMessage, <String, String>{
            'count': '2',
          }),
        ),
        findsOneWidget,
      );

      // "Open Review" stays: dialog gone, grid untouched.
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.reviewLeaveOpenReview)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.reviewLeaveTitle)),
        findsNothing,
      );
      expect(find.byType(ReviewGridTile), findsNWidgets(2));

      // Leaving again asks again; "Save and Exit" leaves.
      await tester.tap(find.text(AppStrings.tr(AppStrings.navClean)));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.reviewLeaveTitle)),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.reviewLeaveSaveExit)),
      );
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
    });

    testWidgets('an empty grid never prompts', (WidgetTester tester) async {
      await _pump(tester, _controller(<MediaAsset>[]));
      expect(
        find.text(AppStrings.tr(AppStrings.reviewEmptyTitle)),
        findsOneWidget,
      );

      await tester.tap(find.text(AppStrings.tr(AppStrings.navClean)));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.tr(AppStrings.reviewLeaveTitle)),
        findsNothing,
      );
      expect(find.text('deck-dummy'), findsOneWidget);
    });
  });
}
