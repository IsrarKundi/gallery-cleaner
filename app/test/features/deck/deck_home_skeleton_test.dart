import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/app_skeleton.dart';
import 'package:klara/features/deck/widgets/deck_home_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets(
    'DeckHomeSkeleton renders AppSkeleton with card, caption, and button bones',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DeckHomeSkeleton()),
        ),
      );

      expect(find.byType(DeckHomeSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byWidgetPredicate((Widget w) => w is Bone), findsWidgets);
    },
  );
}
