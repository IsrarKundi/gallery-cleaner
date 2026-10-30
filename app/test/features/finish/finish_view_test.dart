// Finish screen tests (fix plan Stage 5, ADR-020 decisions
// 1–2): the numbers are the batch's own outcome, and the space
// row states the flow's truth — freed for a Review permanent
// delete, in-Trash with its date for a Clean-deck trash batch,
// never "freed" for what is only trashed. Plus the delete-place
// review ask presenting on the finish screen.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/finish/binding/finish_binding.dart';
import 'package:klara/features/finish/model/finish_summary.dart';
import 'package:klara/features/finish/view/finish_view.dart';
import 'package:klara/services/review_ask/review_ask.dart';
import 'package:klara/services/review_ask/review_ask_service.dart';

class _AskService extends Fake implements ReviewAskService {
  bool due = false;
  final List<ReviewAskPlace> shown = <ReviewAskPlace>[];
  final List<ReviewAskPlace> dismissed = <ReviewAskPlace>[];
  int reviewAnswers = 0;

  @override
  Future<bool> isDue(ReviewAskPlace place) async => due;

  @override
  Future<void> markShown(ReviewAskPlace place) async {
    shown.add(place);
  }

  @override
  Future<void> markDismissed(ReviewAskPlace place) async {
    dismissed.add(place);
  }

  @override
  Future<void> answerWithReview() async {
    reviewAnswers++;
  }

  @override
  Future<int> fallbackAmountBytes() async => 0;
}

Future<void> _pump(WidgetTester tester, FinishSummary summary) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      initialRoute: '/',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: '/',
          page: () => const Scaffold(body: Text('deck-dummy')),
        ),
        GetPage<dynamic>(
          name: AppRoutes.finish,
          page: FinishView.new,
          binding: FinishBinding(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<dynamic>(AppRoutes.finish, arguments: summary);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  group('FinishView', () {
    testWidgets('Review batch: count row and FREED space wording', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FinishSummary(
          deletedCount: 128,
          sizeBytes: 1258291, // 1.2 MB
          spaceState: FinishSpaceState.freed,
        ),
      );
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('You cleaned up your gallery'), findsOneWidget);
      expect(find.text('128 photos'), findsOneWidget);
      expect(find.text('You have deleted'), findsOneWidget);
      expect(find.text('1.2 MB'), findsOneWidget);
      expect(find.text('Freed from your storage'), findsOneWidget);
      expect(find.textContaining('In Trash'), findsNothing);
      // The decided artwork is on top.
      final SvgPicture popper = tester.widget<SvgPicture>(
        find.byType(SvgPicture).first,
      );
      final dynamic loader = popper.bytesLoader;
      expect(loader.assetName, 'assets/images/img_party_popper.svg');
    });

    testWidgets('Trash batch: count row and IN-TRASH wording with '
        'the freed-on date', (WidgetTester tester) async {
      await _pump(
        tester,
        FinishSummary(
          deletedCount: 12,
          sizeBytes: 1258291,
          spaceState: FinishSpaceState.inTrash,
          recoverableUntil: DateTime(2026, 11, 29),
        ),
      );
      expect(find.text('12 photos'), findsOneWidget);
      expect(find.text('1.2 MB'), findsOneWidget);
      expect(find.text('In Trash — freed on 29 Nov 2026'), findsOneWidget);
      expect(find.text('Freed from your storage'), findsNothing);
    });

    testWidgets('Trash batch with no known date never claims freed', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FinishSummary(
          deletedCount: 3,
          sizeBytes: 1024,
          spaceState: FinishSpaceState.inTrash,
        ),
      );
      expect(
        find.text('In Trash — freed when Trash is emptied'),
        findsOneWidget,
      );
      expect(find.text('Freed from your storage'), findsNothing);
    });

    testWidgets('Done returns to the deck', (WidgetTester tester) async {
      await _pump(
        tester,
        const FinishSummary(
          deletedCount: 1,
          sizeBytes: 10,
          spaceState: FinishSpaceState.freed,
        ),
      );
      await tester.tap(find.text(AppStrings.tr(AppStrings.finishDone)));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
    });

    testWidgets('the delete ask presents here when due, with the '
        'finish screen amount', (WidgetTester tester) async {
      final _AskService ask = _AskService()..due = true;
      Get.put<ReviewAskService>(ask);
      await _pump(
        tester,
        const FinishSummary(
          deletedCount: 128,
          sizeBytes: 1258291,
          spaceState: FinishSpaceState.freed,
        ),
      );
      expect(ask.shown, <ReviewAskPlace>[ReviewAskPlace.delete]);
      expect(find.text('You just freed up 1.2 MB'), findsOneWidget);
      expect(
        find.text(
          'Enjoying your extra space? Show wipe. some love with a '
          'quick rating!',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text("Let's Go!"));
      await tester.pumpAndSettle();
      expect(ask.reviewAnswers, 1);
      expect(ask.dismissed, isEmpty);
    });

    testWidgets('no ask presents when the delete place is not due', (
      WidgetTester tester,
    ) async {
      final _AskService ask = _AskService();
      Get.put<ReviewAskService>(ask);
      await _pump(
        tester,
        const FinishSummary(
          deletedCount: 2,
          sizeBytes: 10,
          spaceState: FinishSpaceState.freed,
        ),
      );
      expect(ask.shown, isEmpty);
      expect(find.text("Let's Go!"), findsNothing);
    });
  });
}
