import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/app_skeleton.dart';
import 'package:klara/features/trash/widgets/trash_loading_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets('TrashLoadingSkeleton renders AppSkeleton with row bones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TrashLoadingSkeleton()),
      ),
    );

    expect(find.byType(TrashLoadingSkeleton), findsOneWidget);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byWidgetPredicate((Widget w) => w is Bone), findsWidgets);
  });
}
