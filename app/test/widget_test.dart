import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/main.dart';

void main() {
  testWidgets('bootstrap app renders a bare scaffold with no actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KlaraApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    // No buttons, no fake features in the bootstrap placeholder.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
