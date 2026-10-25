import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/app_skeleton.dart';
import 'package:klara/features/review/widgets/review_loading_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets(
    'ReviewLoadingSkeleton renders AppSkeleton with header and grid tile bones',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReviewLoadingSkeleton()),
        ),
      );

      expect(find.byType(ReviewLoadingSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byWidgetPredicate((Widget w) => w is Bone), findsWidgets);
    },
  );
}
