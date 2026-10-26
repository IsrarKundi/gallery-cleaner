import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/app_bottom_nav.dart';
import 'package:klara/core/widgets/app_card.dart';
import 'package:klara/core/widgets/app_dialog.dart';
import 'package:klara/core/widgets/app_scaffold.dart';
import 'package:klara/core/widgets/app_snackbar.dart';
import 'package:klara/core/widgets/empty_view.dart';
import 'package:klara/core/widgets/error_view.dart';
import 'package:klara/core/widgets/loading_overlay.dart';
import 'package:klara/core/widgets/primary_button.dart';
import 'package:klara/core/widgets/secondary_button.dart';
import 'package:klara/core/widgets/section_header.dart';

/// Pumps [child] inside the app theme with a scaffold ancestor, which
/// snackbars and dialogs require.
Future<void> pumpKit(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('AppScaffold renders title and body', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const AppScaffold(title: 'Test title', body: Text('Test body')),
    );
    expect(find.text('Test title'), findsOneWidget);
    expect(find.text('Test body'), findsOneWidget);
  });

  testWidgets(
    'PrimaryButton shows label, loading spinner and disabled opacity',
    (WidgetTester tester) async {
      await pumpKit(tester, PrimaryButton(label: 'Go', onPressed: () {}));
      expect(find.text('Go'), findsOneWidget);

      await pumpKit(
        tester,
        PrimaryButton(label: 'Go', onPressed: () {}, isLoading: true),
      );
      expect(find.text('Go'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpKit(tester, const PrimaryButton(label: 'Go'));
      final Opacity opacity = tester.widget<Opacity>(
        find.byType(Opacity).first,
      );
      expect(opacity.opacity, 0.5);
    },
  );

  // Phase 3B: the button itself is 48dp tall. The old pattern
  // (a 40dp button centred in a 48dp box) was proven NOT to give
  // a 48dp tap target — taps at the box's top edge missed — so
  // the old "40 inside 48" assertion is replaced by this one.
  testWidgets('SecondaryButton is itself 48dp tall', (
    WidgetTester tester,
  ) async {
    await pumpKit(tester, SecondaryButton(label: 'Keep', onPressed: () {}));
    expect(find.text('Keep'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is SizedBox && widget.height == 48,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is SizedBox && widget.height == 40,
      ),
      findsNothing,
    );
  });

  testWidgets('LoadingOverlay shows the spinner only while loading', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const LoadingOverlay(
        isLoading: true,
        message: 'Working',
        child: Text('Content'),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);

    await pumpKit(
      tester,
      const LoadingOverlay(isLoading: false, child: Text('Content')),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('ErrorView shows message and fires retry', (
    WidgetTester tester,
  ) async {
    bool retried = false;
    await pumpKit(
      tester,
      ErrorView(message: 'It broke', onRetry: () => retried = true),
    );
    expect(find.text('It broke'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('EmptyView shows one CTA only when an action is given', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      EmptyView(
        icon: AppIcons.photos,
        title: 'Empty title',
        message: 'Empty message',
        ctaLabel: 'Do it',
        onCta: () {},
      ),
    );
    expect(find.text('Empty title'), findsOneWidget);
    expect(find.text('Do it'), findsOneWidget);

    await pumpKit(
      tester,
      const EmptyView(
        icon: AppIcons.photos,
        title: 'Empty title',
        message: 'Empty message',
      ),
    );
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('AppDialog returns true on confirm and false on cancel', (
    WidgetTester tester,
  ) async {
    bool? confirmed;
    await pumpKit(
      tester,
      Builder(
        builder: (BuildContext context) {
          return PrimaryButton(
            label: 'Ask',
            onPressed: () async {
              confirmed = await AppDialog.showConfirmation(
                context,
                title: 'Are you sure?',
                message: 'This is the question.',
                confirmLabel: 'Yes',
                cancelLabel: 'No',
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });

  testWidgets('AppSnackbar shows the message and fires its action', (
    WidgetTester tester,
  ) async {
    bool acted = false;
    await pumpKit(
      tester,
      Builder(
        builder: (BuildContext context) {
          return PrimaryButton(
            label: 'Notify',
            onPressed: () {
              AppSnackbar.show(
                context,
                message: 'Hello snack',
                actionLabel: 'Undo it',
                onAction: () => acted = true,
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Notify'));
    // Advance past the snackbar entrance animation in small steps (a
    // single large pump leaves this animation near its start position
    // in the test harness). Total 500ms stays well under the 4s
    // auto-dismiss, so the action is still on-screen and tappable.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Hello snack'), findsOneWidget);
    await tester.tap(find.text('Undo it'));
    await tester.pump();
    expect(acted, isTrue);
  });

  testWidgets('SectionHeader shows title, subtitle and action', (
    WidgetTester tester,
  ) async {
    bool acted = false;
    await pumpKit(
      tester,
      SectionHeader(
        title: 'Section',
        subtitle: 'Details',
        actionLabel: 'See all',
        onAction: () => acted = true,
      ),
    );
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.text('See all'));
    expect(acted, isTrue);
  });

  testWidgets('AppCard renders its child and fires onTap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await pumpKit(
      tester,
      AppCard(onTap: () => tapped = true, child: const Text('Card child')),
    );
    expect(find.text('Card child'), findsOneWidget);
    await tester.tap(find.text('Card child'));
    expect(tapped, isTrue);
  });

  testWidgets('AppBottomNav renders 4 destinations', (
    WidgetTester tester,
  ) async {
    await pumpKit(tester, const AppBottomNav(currentIndex: 0));
    expect(find.text('Clean'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
