// Review selection tests (owner decision 26 Oct 2026): photos are
// always revealed; long-press or the Select button enters selection
// mode; taps toggle; Select all selects everything; the bottom bar
// acts on the selection (Keep X / Delete X) instead of the whole
// set; back cancels the mode before leaving. No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/review/widgets/review_grid_tile.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1×1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class _Media implements MediaService {
  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(_png);

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
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      const Success<List<MediaAsset>>(<MediaAsset>[]);
}

class _Local implements LocalService {
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
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by review selection tests: ${invocation.memberName}',
  );
}

class _Trash implements TrashService {
  final List<String> trashedIds = <String>[];

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    trashedIds.addAll(ids);
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

ReviewController _controller(
  _Local local,
  _Trash trash, {
  // Get.put calls onInit itself; only init manually when the
  // controller is used without registration (controller tests).
  bool init = true,
}) {
  local.sessions['all'] = DeckSession(
    filterKey: 'all',
    currentIndex: 0,
    marks: <String, DeckMark>{'a': DeckMark.delete, 'b': DeckMark.delete},
    favouriteIds: <String>{},
  );
  final ReviewController controller = ReviewController(
    media: _Media(),
    trash: trash,
    local: local,
    initialAssets: <MediaAsset>[_asset('a'), _asset('b')],
    filterKeyOverride: 'all',
  );
  if (init) {
    controller.onInit();
  }
  return controller;
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

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('selection state', () {
    test('long-press enters mode, taps toggle, emptying exits mode', () async {
      final ReviewController controller = _controller(_Local(), _Trash());
      expect(controller.selectionMode, isFalse);

      controller.selection.longPress('a');
      expect(controller.selectionMode, isTrue);
      expect(controller.selection.isSelected('a'), isTrue);

      controller.selection.toggle('b');
      expect(controller.selectedItems.length, 2);

      controller.selection.toggle('a');
      controller.selection.toggle('b');
      expect(controller.selectionMode, isFalse);
      expect(controller.hasSelection, isFalse);
      controller.onClose();
    });

    test('Select entry then Select all selects every item', () async {
      final ReviewController controller = _controller(_Local(), _Trash());
      controller.selection.enter();
      expect(controller.selectionMode, isTrue);
      expect(controller.hasSelection, isFalse);

      controller.selection.selectAll(
        controller.items.map((MediaAsset a) => a.id),
      );
      expect(controller.selectedItems.length, 2);
      controller.onClose();
    });

    test(
      'cancel swallows the first back, then reports nothing to cancel',
      () async {
        final ReviewController controller = _controller(_Local(), _Trash());
        controller.selection.longPress('a');
        expect(controller.selection.cancel(), isTrue);
        expect(controller.selectionMode, isFalse);
        expect(controller.selection.cancel(), isFalse);
        controller.onClose();
      },
    );

    test('keepSelected keeps only the selection', () async {
      final _Local local = _Local();
      final ReviewController controller = _controller(local, _Trash());
      controller.selection.longPress('a');
      await controller.keepSelected();

      expect(controller.items.map((MediaAsset a) => a.id), <String>['b']);
      expect(local.sessions['all']!.marks['a'], DeckMark.keep);
      expect(local.sessions['all']!.marks['b'], DeckMark.delete);
      expect(controller.selectionMode, isFalse);
      controller.onClose();
    });

    test('deleteSelected with onlyIds deletes only the selection', () async {
      final _Local local = _Local();
      final _Trash trash = _Trash();
      final ReviewController controller = _controller(local, trash);
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected(
        onlyIds: <String>['a'],
      );

      expect(outcome, ReviewDeleteOutcome.trashed);
      expect(trash.trashedIds, <String>['a']);
      expect(controller.items.map((MediaAsset a) => a.id), <String>['b']);
      expect(controller.selectionMode, isFalse);
      controller.onClose();
    });
  });

  group('selection visuals', () {
    testWidgets('selected tile shows a check, unselected shows none', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SizedBox(
                  width: 200,
                  height: 200,
                  child: ReviewGridTile(
                    asset: _asset('a'),
                    thumbnail: null,
                    thumbnailFailed: true,
                    selected: true,
                    selectionMode: true,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: ReviewGridTile(
                    asset: _asset('b'),
                    thumbnail: null,
                    thumbnailFailed: true,
                    selected: false,
                    selectionMode: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Exactly one check icon: the selected tile's checkbox. (The
      // unselected tile renders an empty circle, no icon.)
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      // No blur anywhere: photos are always revealed.
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text(AppStrings.tr(AppStrings.blurShowPhotos)), findsNothing);
    });
  });

  group('selection flow in the view', () {
    testWidgets('long-press enters mode and bar counts the selection', (
      WidgetTester tester,
    ) async {
      final ReviewController controller = _controller(
        _Local(),
        _Trash(),
        init: false,
      );
      await _pump(tester, controller);
      expect(find.text('Select'), findsOneWidget);

      await tester.longPress(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Delete 1 photos'), findsOneWidget);
      expect(find.text('Keep 1 photos'), findsOneWidget);

      await tester.tap(find.byType(ReviewGridTile).last);
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 photos'), findsOneWidget);
      expect(find.text('Keep 2 photos'), findsOneWidget);
    });

    testWidgets('Select button enters mode, Select all selects all', (
      WidgetTester tester,
    ) async {
      final ReviewController controller = _controller(
        _Local(),
        _Trash(),
        init: false,
      );
      await _pump(tester, controller);

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Delete 2 photos'), findsOneWidget);

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(controller.selectedItems.length, 2);
    });

    testWidgets('delete-selected removes only the selection', (
      WidgetTester tester,
    ) async {
      final _Trash trash = _Trash();
      final ReviewController controller = _controller(
        _Local(),
        trash,
        init: false,
      );
      await _pump(tester, controller);

      await tester.longPress(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete 1 photos'));
      await tester.pumpAndSettle();

      expect(trash.trashedIds, <String>['a']);
      expect(find.byType(ReviewGridTile), findsOneWidget);
      expect(controller.items.map((MediaAsset a) => a.id), <String>['b']);
    });

    testWidgets('back cancels selection before leaving', (
      WidgetTester tester,
    ) async {
      final ReviewController controller = _controller(
        _Local(),
        _Trash(),
        init: false,
      );
      await _pump(tester, controller);

      await tester.longPress(find.byType(ReviewGridTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('Select'), findsOneWidget);
      expect(find.byType(ReviewView), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
    });
  });
}
