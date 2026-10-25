// Phase 3.3 tests: bounded-concurrency review loads, per-tile
// observers (visible window only), aggregates, static placeholders,
// shared blur filter, and tile/controller retry. No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/review/widgets/review_grid_tile.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1×1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id, {int size = 1000, String? title}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: title ?? '$id.jpg',
    albumName: 'Camera',
  );
}

/// Media fake that counts concurrent getThumbnail calls and can
/// fail chosen ids until flipped to success.
class _CountingMedia implements MediaService {
  _CountingMedia({this.delay = const Duration(milliseconds: 5)});

  final Duration delay;
  int current = 0;
  int maxConcurrent = 0;
  final Set<String> failingIds = <String>{};

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    current++;
    if (current > maxConcurrent) {
      maxConcurrent = current;
    }
    try {
      await Future<void>.delayed(delay);
      if (failingIds.contains(assetId)) {
        return const Failure<Uint8List>(
          AppFailure(messageKey: AppStrings.errorLocal),
        );
      }
      return Success<Uint8List>(_png);
    } finally {
      current--;
    }
  }

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
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

/// Local fake: session map + settings. Everything else throws if
/// touched (these tests never touch it).
class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};

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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by review rendering tests: ${invocation.memberName}',
  );
}

/// Trash fake: never called by these tests.
class _Trash implements TrashService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by review rendering tests: ${invocation.memberName}',
  );
}

ReviewController _controller({
  required MediaService media,
  required _Local local,
  required List<MediaAsset> items,
  bool init = true,
}) {
  final ReviewController controller = ReviewController(
    media: media,
    trash: _Trash(),
    local: local,
    initialAssets: items,
    filterKeyOverride: 'all',
  );
  // Get.put calls onInit itself; only init manually when the
  // controller is used without registration.
  if (init) {
    controller.onInit();
  }
  return controller;
}

/// Waits until [condition] holds or fails after [timeout].
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('ReviewController bounded concurrency (Phase 3.3)', () {
    test('20 tiles load in batches of at most 8, not one-by-one', () async {
      final _CountingMedia media = _CountingMedia();
      final ReviewController controller = _controller(
        media: media,
        local: _Local(),
        items: <MediaAsset>[for (int i = 0; i < 20; i++) _asset('t$i')],
      );
      await _waitUntil(() => controller.thumbnails.length == 20);
      expect(controller.failedThumbnails, isEmpty);
      // Batched: more than 1 in flight (not sequential), never
      // more than the batch size of 8.
      expect(media.maxConcurrent, greaterThan(1));
      expect(media.maxConcurrent, lessThanOrEqualTo(8));
      controller.onClose();
    });

    test('documentLikeCount tracks the set and follows unmarks', () async {
      final ReviewController controller = _controller(
        media: _CountingMedia(delay: Duration.zero),
        local: _Local(),
        items: <MediaAsset>[
          _asset('r1', title: 'receipt.jpg'),
          _asset('p1', title: 'passport.png'),
          _asset('b1', title: 'beach.jpg'),
        ],
      );
      await _waitUntil(() => controller.thumbnails.length == 3);
      expect(controller.documentLikeCount.value, 2);
      await controller.unmark(_asset('r1', title: 'receipt.jpg'));
      expect(controller.items.length, 2);
      expect(controller.documentLikeCount.value, 1);
      controller.onClose();
    });

    test('unmark x20 shrinks the set and its totals', () async {
      final List<MediaAsset> items = <MediaAsset>[
        for (int i = 0; i < 30; i++) _asset('u$i', size: 1000),
      ];
      final ReviewController controller = _controller(
        media: _CountingMedia(delay: Duration.zero),
        local: _Local(),
        items: items,
      );
      await _waitUntil(() => controller.thumbnails.length == 30);
      expect(controller.totalBytes, 30000);
      for (int i = 0; i < 20; i++) {
        await controller.unmark(items[i]);
      }
      expect(controller.items.length, 10);
      expect(controller.totalBytes, 10000);
      controller.onClose();
    });

    test('failed tile retries through the controller', () async {
      final _CountingMedia media = _CountingMedia(delay: Duration.zero);
      media.failingIds.add('bad');
      final ReviewController controller = _controller(
        media: media,
        local: _Local(),
        items: <MediaAsset>[_asset('bad'), _asset('good')],
      );
      await _waitUntil(
        () =>
            controller.thumbnails.length == 1 &&
            controller.failedThumbnails.contains('bad'),
      );
      expect(controller.thumbnails.containsKey('bad'), isFalse);
      media.failingIds.remove('bad');
      await controller.retryThumbnail('bad');
      expect(controller.thumbnails.containsKey('bad'), isTrue);
      expect(controller.failedThumbnails.contains('bad'), isFalse);
      controller.onClose();
    });
  });

  group('ReviewGridTile (Phase 3.3)', () {
    testWidgets('pending tile has a static placeholder, no shimmer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: ReviewGridTile(
                asset: _asset('a'),
                thumbnail: null,
                thumbnailFailed: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Skeletonizer), findsNothing);
      expect(find.byType(ReviewGridTile), findsOneWidget);
    });

    testWidgets('blurred tiles share one blur filter instance', (
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
                    blurred: true,
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
                    blurred: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final List<ImageFiltered> filters = tester
          .widgetList<ImageFiltered>(find.byType(ImageFiltered))
          .toList();
      expect(filters.length, 2);
      expect(identical(filters[0].imageFilter, filters[1].imageFilter), isTrue);
    });

    testWidgets('retry button retries without unmarking', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      bool unmarked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: ReviewGridTile(
                asset: _asset('a'),
                thumbnail: null,
                thumbnailFailed: true,
                onTap: () => unmarked = true,
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(AppStrings.tr(AppStrings.errorRetry)));
      await tester.pump();
      expect(retried, isTrue);
      expect(unmarked, isFalse);
    });
  });

  group('ReviewView visible window (Phase 3.3, brief 3.6)', () {
    testWidgets('200 items build only the visible window', (
      WidgetTester tester,
    ) async {
      final ReviewController controller = _controller(
        media: _CountingMedia(delay: Duration.zero),
        local: _Local(),
        items: <MediaAsset>[for (int i = 0; i < 200; i++) _asset('v$i')],
        init: false,
      );
      Get.put<ReviewController>(controller);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.light, home: const ReviewView()),
      );
      await tester.pumpAndSettle();
      final int built = tester.widgetList(find.byType(ReviewGridTile)).length;
      // GridView.builder laziness: a small visible window plus
      // cache extent — far below the 200-item set.
      expect(built, greaterThan(0));
      expect(built, lessThan(100));
    });
  });
}
