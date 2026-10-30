// ReviewAskSheet tests (fix plan Stage 5, ADR-020 decisions
// 8–11): the decided sheet — kitten, stars, the owner's copy —
// presents only when due; Let's Go routes to the store answer;
// Maybe Later and barrier dismissal count as dismissals; the
// unhappy path swaps the same sheet to the feedback form and
// submitting hands the text to the service (share hand-off).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/review_ask_sheet.dart';
import 'package:klara/services/review_ask/review_ask.dart';
import 'package:klara/services/review_ask/review_ask_service.dart';

class _AskService extends Fake implements ReviewAskService {
  bool due = true;
  final List<ReviewAskPlace> shown = <ReviewAskPlace>[];
  final List<ReviewAskPlace> dismissed = <ReviewAskPlace>[];
  int reviewAnswers = 0;
  final List<String> feedback = <String>[];

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
  Future<void> answerWithFeedback(String text) async {
    feedback.add(text);
  }

  @override
  Future<int> fallbackAmountBytes() async => 0;
}

void main() {
  tearDown(Get.reset);

  Future<bool?> pumpAndOpen(WidgetTester tester, _AskService service) async {
    bool? presented;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  presented = await ReviewAskSheet.maybeShow(
                    context,
                    service: service,
                    place: ReviewAskPlace.swipe,
                    amountBytes: 1572864, // 1.5 MB
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return presented;
  }

  testWidgets('not due: nothing presents, nothing is recorded', (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService()..due = false;
    final bool? presented = await pumpAndOpen(tester, service);
    expect(presented, isFalse);
    expect(service.shown, isEmpty);
    expect(find.text("Let's Go!"), findsNothing);
  });

  testWidgets('due: the decided sheet shows with the real amount', (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    expect(service.shown, <ReviewAskPlace>[ReviewAskPlace.swipe]);
    expect(find.text('You just freed up 1.5 MB'), findsOneWidget);
    expect(
      find.text(
        'Enjoying your extra space? Show wipe. some love with a '
        'quick rating!',
      ),
      findsOneWidget,
    );
    expect(find.text("Let's Go!"), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);
    expect(find.text("Not happy? Tell us what's wrong"), findsOneWidget);
    // The kitten and the stars are the sheet's artwork.
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets("Let's Go routes to the store answer", (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    await tester.tap(find.text("Let's Go!"));
    await tester.pumpAndSettle();
    expect(service.reviewAnswers, 1);
    expect(service.dismissed, isEmpty);
    expect(service.feedback, isEmpty);
  });

  testWidgets('Maybe Later is a dismissal (re-arms at double)', (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    await tester.tap(find.text('Maybe Later'));
    await tester.pumpAndSettle();
    expect(service.dismissed, <ReviewAskPlace>[ReviewAskPlace.swipe]);
    expect(service.reviewAnswers, 0);
  });

  testWidgets('barrier dismissal is a dismissal too', (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(service.dismissed, <ReviewAskPlace>[ReviewAskPlace.swipe]);
  });

  testWidgets('the unhappy path swaps to the feedback form in the '
      'same sheet; submit hands the text over', (WidgetTester tester) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    await tester.tap(find.text("Not happy? Tell us what's wrong"));
    await tester.pumpAndSettle();
    expect(find.text("Tell us what's not working"), findsOneWidget);
    // The ask content is gone — same sheet, swapped content.
    expect(find.text("Let's Go!"), findsNothing);
    await tester.enterText(find.byType(TextField), 'Swiping feels laggy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(service.feedback, <String>['Swiping feels laggy']);
    expect(service.dismissed, isEmpty);
    expect(find.text(AppStrings.tr(AppStrings.feedbackThanks)), findsOneWidget);
  });

  testWidgets('cancelling the feedback form is a dismissal', (
    WidgetTester tester,
  ) async {
    final _AskService service = _AskService();
    await pumpAndOpen(tester, service);
    await tester.tap(find.text("Not happy? Tell us what's wrong"));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.tr(AppStrings.actionCancel)));
    await tester.pumpAndSettle();
    expect(service.feedback, isEmpty);
    expect(service.dismissed, <ReviewAskPlace>[ReviewAskPlace.swipe]);
  });
}
