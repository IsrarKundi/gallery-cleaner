// Phase 3.1 tests: card stack + pre-decode + per-surface sizes.
//
// The stack renders the current card with the next 1–2 cards
// pre-decoded underneath, so advancing never shows a blank card;
// the previous card stays warm in the shared service cache for
// undo; and the 10-card pagination trigger fires exactly one page
// load even when marks land while a page is in flight.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/thumbnail_preloader.dart';
import 'package:klara/features/deck/widgets/deck_card_stack.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1x1 PNG, so image branches render for real.
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

Future<void> _pollUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _StackMedia implements MediaService {
  _StackMedia({this.assets = const <MediaAsset>[]});

  final List<MediaAsset> assets;

  /// Page-1 loads wait on this gate when set; page-0 never gates.
  Completer<List<MediaAsset>>? page1Gate;

  /// getAssets call counts per page.
  final Map<int, int> pageCalls = <int, int>{};

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
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
    pageCalls[page] = (pageCalls[page] ?? 0) + 1;
    if (page == 1 && page1Gate != null) {
      return Success<List<MediaAsset>>(await page1Gate!.future);
    }
    final int start = page * pageSize;
    if (start >= assets.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize) > assets.length
        ? assets.length
        : start + pageSize;
    return Success<List<MediaAsset>>(assets.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return Success<List<MediaAsset>>(
      assets.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
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
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected MediaService call: ${invocation.memberName}',
    );
  }
}

class _StackLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(
      DeckSession(
        filterKey: filterKey,
        currentIndex: 0,
        marks: <String, DeckMark>{},
        favouriteIds: <String>{},
      ),
    );
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(false);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected LocalService call: ${invocation.memberName}',
    );
  }
}

class _StackTrash implements TrashService {
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected TrashService call: ${invocation.memberName}',
    );
  }
}

void main() {
  group('DeckCardStack (Phase 3.1)', () {
    testWidgets('renders current plus next 2 underneath', (
      WidgetTester tester,
    ) async {
      final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{
        'a': _png,
        'b': _png,
        'c': _png,
      }.obs;
      final RxSet<String> failed = <String>{}.obs;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: DeckCardStack(
                  current: _asset('a'),
                  next: <MediaAsset>[_asset('b'), _asset('c')],
                  thumbnails: thumbnails,
                  failedThumbnails: failed,
                  onSwiped: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SwipeCard), findsOneWidget);
      // Three decoded photos: top + two underneath.
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('advancing shows the next photo with no blank flash', (
      WidgetTester tester,
    ) async {
      final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{
        'a': _png,
        'b': _png,
        'c': _png,
      }.obs;
      final RxSet<String> failed = <String>{}.obs;
      Widget stack(MediaAsset current, List<MediaAsset> next) {
        return MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: DeckCardStack(
                  current: current,
                  next: next,
                  thumbnails: thumbnails,
                  failedThumbnails: failed,
                  onSwiped: (_) {},
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        stack(_asset('a'), <MediaAsset>[_asset('b'), _asset('c')]),
      );
      await tester.pump();
      // Advance: b is now top, c underneath. b's bytes were already
      // in the map, so the new top card shows its photo in the same
      // frame — no spinner, no blank card.
      await tester.pumpWidget(stack(_asset('b'), <MediaAsset>[_asset('c')]));
      await tester.pump();
      expect(find.byType(SwipeCard), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('single remaining photo renders one card', (
      WidgetTester tester,
    ) async {
      final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{'a': _png}
          .obs;
      final RxSet<String> failed = <String>{}.obs;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: DeckCardStack(
                  current: _asset('a'),
                  next: const <MediaAsset>[],
                  thumbnails: thumbnails,
                  failedThumbnails: failed,
                  onSwiped: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SwipeCard), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    test('previous card stays warm in the service cache for undo', () async {
      final _StackMedia media = _StackMedia();
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      service.prefetch(<String>['a', 'b', 'c'], 1080);
      await _pollUntil(() => service.thumbnailsFor(1080).containsKey('a'));
      // Window slides forward; the previous card's bytes survive
      // (cancelOutside drops flights, never cached bytes).
      service.prefetch(<String>['b', 'c', 'd'], 1080);
      service.cancelOutside(<ThumbnailKey>{
        for (final String id in <String>['b', 'c', 'd'])
          (id: id, size: 1080, quality: 85),
      });
      await _pollUntil(() => service.thumbnailsFor(1080).containsKey('d'));
      expect(service.thumbnailsFor(1080).containsKey('a'), isTrue);
    });

    test('10-card trigger fires exactly one page load', () async {
      final List<MediaAsset> assets = List<MediaAsset>.generate(
        60,
        (int i) => _asset('p$i'),
      );
      final _StackMedia media = _StackMedia(assets: assets);
      final Completer<List<MediaAsset>> gate = Completer<List<MediaAsset>>();
      media.page1Gate = gate;
      final ThumbnailService service = ThumbnailServiceImpl(media: media);
      final DeckController controller = DeckController(
        media: media,
        trash: _StackTrash(),
        local: _StackLocal(),
        thumbnailService: service,
      );
      await controller.init();
      expect(controller.queue.length, 50);
      // Jump to the trigger boundary: 10 cards remain.
      controller.currentIndex.value = 40;
      await service.getThumbnail('p40', 1080);
      await controller.markCurrent(DeckMark.keep);
      expect(controller.currentIndex.value, 41);
      expect(media.pageCalls[1], 1);
      // A second mark while page 1 is still in flight must not
      // start a second page load.
      await service.getThumbnail('p41', 1080);
      await controller.markCurrent(DeckMark.keep);
      expect(media.pageCalls[1], 1);
      gate.complete(assets.sublist(50, 60));
      await _pollUntil(() => controller.queue.length == 60);
      expect(media.pageCalls[1], 1);
    });

    test('per-surface thumbnail sizes (solutions 3.1)', () {
      expect(ThumbnailPreloader.thumbnailSize, 1080);
      expect(SmartDeckController.thumbnailSize, 1080);
      expect(ReviewController.thumbnailSize, 320);
    });
  });
}
