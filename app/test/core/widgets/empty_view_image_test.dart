// EmptyView picture option (fix plan Stage 5, ADR-020
// decision 14): the picture is opt-in per caller — an empty
// state WITHOUT an imageAsset keeps the plain icon exactly as
// before (every other empty screen in the app is unchanged).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/widgets/empty_view.dart';

void main() {
  testWidgets('without imageAsset: icon, no picture', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: EmptyView(
            icon: AppIcons.photos,
            title: 'Nothing here',
            message: 'There is nothing to show.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byIcon(AppIcons.photos), findsOneWidget);
  });

  testWidgets('with imageAsset: the picture replaces the icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: EmptyView(
            icon: AppIcons.photos,
            title: 'Nothing here',
            message: 'There is nothing to show.',
            imageAsset: 'assets/images/img_empty_history.svg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(AppIcons.photos), findsNothing);
  });
}
