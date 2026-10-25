// Phase 3.4: the text-style set is cached per palette instance,
// not rebuilt per access. No device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klara/core/constants/app_text.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/theme/theme_ext.dart';

void main() {
  testWidgets('textStyles returns the identical set per palette', (
    WidgetTester tester,
  ) async {
    AppTextStyles? captured;
    Widget app(ThemeData theme) {
      return MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) {
            captured = context.textStyles;
            return const SizedBox();
          },
        ),
      );
    }

    await tester.pumpWidget(app(AppTheme.light));
    final AppTextStyles? lightFirst = captured;
    // Rebuild under the same theme (AppTheme.light builds a fresh
    // ThemeData each access, but the palette inside is the const
    // singleton — so the cache must still hit).
    await tester.pumpWidget(app(AppTheme.light));
    final AppTextStyles? lightSecond = captured;
    expect(identical(lightFirst, lightSecond), isTrue);

    // A theme switch yields a different palette, so the set
    // rebuilds instead of serving the stale light set. The
    // switch animates (AnimatedTheme), so settle first — a
    // single pump would still read the old theme mid-tween.
    await tester.pumpWidget(app(AppTheme.dark));
    await tester.pumpAndSettle();
    final AppTextStyles? dark = captured;
    expect(identical(lightFirst, dark), isFalse);
  });
}
