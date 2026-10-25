// Phase 2.5 widget tests: a card is interactive ONLY when its
// thumbnail is visible. Spinner and failure states accept no mark
// gesture; the failure state retries on tap when a handler exists.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/services/local/local_service.dart';

/// A valid 1x1 PNG, so the image branch renders for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required Uint8List? thumbnail,
  required bool thumbnailFailed,
  required ValueChanged<DeckMark> onSwiped,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: SwipeCard(
              thumbnail: thumbnail,
              thumbnailFailed: thumbnailFailed,
              onSwiped: onSwiped,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('SwipeCard readiness (Phase 2.5)', () {
    testWidgets('spinner state accepts no mark gesture', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await _pumpCard(
        tester,
        thumbnail: null,
        thumbnailFailed: false,
        onSwiped: marks.add,
      );
      await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
      // No pumpAndSettle: the spinner animates forever, so settling
      // would time out. One frame is enough to prove no mark lands.
      await tester.pump();
      expect(marks, isEmpty);
    });

    testWidgets('visible thumbnail swipes and reports the mark', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await _pumpCard(
        tester,
        thumbnail: _png,
        thumbnailFailed: false,
        onSwiped: marks.add,
      );
      await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(marks, <DeckMark>[DeckMark.delete]);
    });

    testWidgets('failure state accepts no mark gesture', (
      WidgetTester tester,
    ) async {
      final List<DeckMark> marks = <DeckMark>[];
      await _pumpCard(
        tester,
        thumbnail: null,
        thumbnailFailed: true,
        onSwiped: marks.add,
      );
      await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(marks, isEmpty);
    });

    testWidgets('failure state retries on tap', (WidgetTester tester) async {
      final List<DeckMark> marks = <DeckMark>[];
      int retries = 0;
      await _pumpCard(
        tester,
        thumbnail: null,
        thumbnailFailed: true,
        onSwiped: marks.add,
        onRetry: () => retries++,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(marks, isEmpty);
    });

    testWidgets('failure state without a handler is inert, not a crash', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        thumbnail: null,
        thumbnailFailed: true,
        onSwiped: (_) {},
      );
      await tester.tap(find.byType(SwipeCard));
      await tester.pumpAndSettle();
    });
  });
}
