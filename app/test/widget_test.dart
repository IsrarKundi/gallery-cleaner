import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/main.dart';

void main() {
  testWidgets('app renders a bare scaffold with no actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KlaraApp());

    expect(find.byType(GetMaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    // No buttons, no fake features in the temporary placeholder home.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('app uses the light theme', (WidgetTester tester) async {
    await tester.pumpWidget(const KlaraApp());

    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
