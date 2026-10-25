// Phase 3.2 tests: SwipeCard mechanics + settled-review gate.
//
// Drag follows the finger 1:1 (no implicit animation in the drag
// path); exit is one transform + opacity animation; below-threshold
// drags spring back; edge labels highlight with drag distance;
// button marks bypass card animation entirely; review navigation
// requested mid-exit defers until the flight ends; and 10k marks
// leave the gesture state consistent.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/deferred_action.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/widgets/deck_action_bar.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/thumbnail/thumbnail_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1x1 PNG, so the image branch renders for real.
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

Future<void> _pumpCard(
  WidgetTester tester, {
  required ValueChanged<DeckMark> onSwiped,
  VoidCallback? onExitStart,
  VoidCallback? onExitEnd,
  bool disableAnimations = false,
}) async {
  final Widget card = SizedBox(
    width: 300,
    height: 400,
    child: SwipeCard(
      thumbnail: _png,
      thumbnailFailed: false,
      onSwiped: onSwiped,
      onExitStart: onExitStart,
      onExitEnd: onExitEnd,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: disableAnimations
              ? MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: card,
                )
              : card,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The card's own transform: the Transform ancestor of the photo.
/// (Label scales are Transforms too, but they are not ancestors of
/// the photo.)
Transform _cardTransform(WidgetTester tester) {
  return tester.widget<Transform>(
    find.ancestor(of: find.byType(Image), matching: find.byType(Transform)),
  );
}

/// The card's own opacity: the Opacity ancestor of the photo.
/// (Label opacities are siblings of the photo, not ancestors.)
double _cardOpacity(WidgetTester tester) {
  final List<Opacity> opacities = tester
      .widgetList<Opacity>(
        find.ancestor(of: find.byType(Image), matching: find.byType(Opacity)),
      )
      .toList();
  expect(opacities, hasLength(1));
  return opacities.first.opacity;
}

/// Opacities wrapping a label text: the card opacity (1.0 while not
/// exiting) plus the label's own opacity.
List<double> _labelOpacities(WidgetTester tester, String label) {
  return tester
      .widgetList<Opacity>(
        find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
      )
      .map((Opacity o) => o.opacity)
      .toList();
}

class _MechanicsMedia implements MediaService {
  _MechanicsMedia({required this.assets});

  final List<MediaAsset> assets;

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

class _MechanicsLocal implements LocalService {
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

class _MechanicsTrash implements TrashService {
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
  group('SwipeCard mechanics (Phase 3.2)', () {
    testWidgets('drag follows the finger 1:1, no implicit animation', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, onSwiped: (_) {});
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeCard)),
      );
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      // No AnimatedContainer anywhere in the drag path.
      expect(find.byType(AnimatedContainer), findsNothing);
      // Matrix4 storage: [12] = x translation, [13] = y.
      final List<double> storage = _cardTransform(tester).transform.storage;
      expect(storage[12], 50);
      expect(storage[13], 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('exit is one visible transform + opacity animation', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      bool exitStarted = false;
      bool exitEnded = false;
      await _pumpCard(
        tester,
        onSwiped: marks.add,
        onExitStart: () => exitStarted = true,
        onExitEnd: () => exitEnded = true,
      );
      await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
      await tester.pump();
      // Mid-flight (150 ms of the 300 ms exit): the photo is still
      // visible and fading — opacity strictly between 0 and 1 —
      // and the mark has NOT fired yet (no instant vanish, no
      // mark-before-animation).
      await tester.pump(const Duration(milliseconds: 150));
      expect(exitStarted, isTrue);
      expect(exitEnded, isFalse);
      final double midOpacity = _cardOpacity(tester);
      expect(midOpacity, greaterThan(0));
      expect(midOpacity, lessThan(1));
      expect(marks, isEmpty);
      await tester.pumpAndSettle();
      expect(exitEnded, isTrue);
      expect(marks, <DeckMark>[DeckMark.delete]);
    });

    testWidgets('below-threshold drag springs back, no mark', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await _pumpCard(tester, onSwiped: marks.add);
      await tester.drag(find.byType(SwipeCard), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(marks, isEmpty);
      final List<double> storage = _cardTransform(tester).transform.storage;
      expect(storage[12], 0);
      expect(storage[13], 0);
    });

    testWidgets('edge labels highlight toward the drag', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, onSwiped: (_) {});
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeCard)),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      // 40 of 80 px toward DELETE: its label opacity rises above
      // the resting 0.45; the opposite label stays resting. (The
      // card opacity 1.0 is the other ancestor in both lists.)
      final List<double> delete = _labelOpacities(tester, 'DELETE');
      expect(delete.any((double o) => o > 0.45 && o < 1), isTrue);
      final List<double> keep = _labelOpacities(tester, 'KEEP');
      expect(keep, contains(0.45));
      expect(keep.any((double o) => o > 0.45 && o < 1), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion marks immediately, no animation', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await _pumpCard(tester, onSwiped: marks.add, disableAnimations: true);
      await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
      // One frame, no settle: the mark is already recorded.
      await tester.pump();
      expect(marks, <DeckMark>[DeckMark.delete]);
    });

    testWidgets('button marks bypass card animation entirely', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DeckActionBar(
              onMark: marks.add,
              onUndo: () {},
              canUndo: false,
              onReview: () {},
              isCleanScreen: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Keep'));
      // One frame, no settle: the button mark is already recorded.
      await tester.pump();
      expect(marks, <DeckMark>[DeckMark.keep]);
    });
  });

  group('DeferredAction (Phase 3.2 gate)', () {
    test('idle run executes immediately', () {
      final DeferredAction gate = DeferredAction();
      bool ran = false;
      gate.run(() => ran = true);
      expect(ran, isTrue);
    });

    test('busy run defers until the flight ends', () {
      final DeferredAction gate = DeferredAction();
      bool ran = false;
      gate.setBusy(true);
      gate.run(() => ran = true);
      expect(ran, isFalse);
      gate.setBusy(false);
      expect(ran, isTrue);
    });

    test('a later request replaces an earlier pending one', () {
      final DeferredAction gate = DeferredAction();
      final List<String> ran = <String>[];
      gate.setBusy(true);
      gate.run(() => ran.add('first'));
      gate.run(() => ran.add('second'));
      gate.setBusy(false);
      expect(ran, <String>['second']);
    });
  });

  group('DeckController settled-review gate (Phase 3.2)', () {
    test('goToReview defers while a card exit is in flight', () async {
      final _MechanicsMedia media = _MechanicsMedia(
        assets: <MediaAsset>[_asset('a')],
      );
      final DeckController controller = DeckController(
        media: media,
        trash: _MechanicsTrash(),
        local: _MechanicsLocal(),
        thumbnailService: ThumbnailServiceImpl(media: media),
      );
      expect(controller.isCardExiting, isFalse);
      controller.setCardExiting(true);
      expect(controller.isCardExiting, isTrue);
      // Deferred: no navigation is attempted, so this returns
      // normally even with no routes registered (an immediate
      // navigation would throw here).
      expect(controller.goToReview, returnsNormally);
      // Settling runs the deferred navigation: with no routes
      // registered it throws — the throw itself proves the pending
      // action fired (had it not fired, nothing would throw).
      bool threw = false;
      try {
        controller.setCardExiting(false);
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(controller.isCardExiting, isFalse);
    });

    test('10k marks leave the gesture state consistent', () async {
      final List<MediaAsset> assets = List<MediaAsset>.generate(
        10010,
        (int i) => _asset('k$i'),
      );
      final _MechanicsMedia media = _MechanicsMedia(assets: assets);
      final DeckController controller = DeckController(
        media: media,
        trash: _MechanicsTrash(),
        local: _MechanicsLocal(),
        thumbnailService: ThumbnailServiceImpl(media: media),
      );
      await controller.init();
      // One microtask lets the first window's bytes land.
      await Future<void>.microtask(() {});
      int guard = 0;
      while (controller.currentIndex.value < 10000) {
        guard++;
        if (guard > 20000) {
          fail('marks stalled before 10k (page loads never landed)');
        }
        await controller.markCurrent(DeckMark.keep);
        // Microtasks let the next window's bytes and any page
        // load land; a mark on a not-yet-visible card is refused
        // (2.5), so the loop retries until the window is ready.
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
      }
      expect(controller.currentIndex.value, 10000);
      expect(controller.marks.length, 10000);
      expect(controller.undoStack.length, 10000);
      expect(controller.queue.length, greaterThanOrEqualTo(10001));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
