// Phase 3B contrast regression tests (design.md §9): every text
// role in both themes must pass 4.5:1 against its background, and
// the two Phase 3B fixes (text-button ink, snackbar-action inverse)
// must stay fixed. Ratios are computed here from the palette
// values, so a future palette change that breaks a role fails the
// suite instead of shipping silently. UI-component colours (fills,
// icons, borders) are held to 3:1, per design.md §2.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_colors.dart';

double _luminance(Color color) {
  double channel(int value) {
    final double c = value / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final int argb = color.toARGB32();
  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('light text roles pass 4.5:1 on white', () {
    const AppPalette p = AppPalette.light;
    expect(_ratio(p.textPrimary, p.background), greaterThanOrEqualTo(4.5));
    expect(_ratio(p.textSecondary, p.background), greaterThanOrEqualTo(4.5));
    expect(_ratio(p.textTertiary, p.background), greaterThanOrEqualTo(4.5));
  });

  test('dark text roles pass 4.5:1 on #121212 and on dark surfaces', () {
    const AppPalette p = AppPalette.dark;
    // Primary + secondary pass on every dark surface (including
    // elevated surfaceVariant). Tertiary passes on the base
    // background only — see the next test for the constraint.
    for (final Color surface in <Color>[
      p.background,
      p.surface,
      p.surfaceVariant,
    ]) {
      expect(_ratio(p.textPrimary, surface), greaterThanOrEqualTo(4.5));
      expect(_ratio(p.textSecondary, surface), greaterThanOrEqualTo(4.5));
    }
    expect(_ratio(p.textTertiary, p.background), greaterThanOrEqualTo(4.5));
  });

  test('dark tertiary is background-only: it fails on surfaceVariant', () {
    // Phase 3B audit finding, documented as a constraint rather
    // than silently "fixed": dark textTertiary #80868B is 3.79:1
    // on surfaceVariant #2C2C2C (below 4.5:1). No widget renders
    // tertiary text today (grep proves it), so nothing on screen
    // violates — but tertiary must never be used on an elevated
    // dark surface until the token itself changes.
    const AppPalette p = AppPalette.dark;
    expect(_ratio(p.textTertiary, p.surfaceVariant), lessThan(4.5));
  });

  test('dark brand fills pass 4.5:1 on #121212 with dark labels', () {
    const AppPalette p = AppPalette.dark;
    for (final Color fill in <Color>[
      p.primary,
      p.success,
      p.warning,
      p.error,
    ]) {
      expect(_ratio(fill, p.background), greaterThanOrEqualTo(4.5));
      expect(_ratio(p.onPrimary, fill), greaterThanOrEqualTo(4.5));
    }
  });

  test('Phase 3B: text-button ink passes where primary failed', () {
    const AppPalette light = AppPalette.light;
    // The old foreground (primary on white) was 3.56:1 — below
    // the text bar. The new foreground (text ink) must pass.
    expect(_ratio(light.primary, light.background), lessThan(4.5));
    expect(
      _ratio(light.textPrimary, light.background),
      greaterThanOrEqualTo(4.5),
    );
    const AppPalette dark = AppPalette.dark;
    expect(_ratio(dark.textPrimary, dark.surface), greaterThanOrEqualTo(4.5));
  });

  test('Phase 3B: snackbar action inverse passes on both bars', () {
    const AppPalette light = AppPalette.light;
    const AppPalette dark = AppPalette.dark;
    // Bars are ink in light, light ink in dark (see AppTheme).
    expect(
      _ratio(light.onPrimary, light.textPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(_ratio(dark.onPrimary, dark.textPrimary), greaterThanOrEqualTo(4.5));
    // And the old primary action failed in dark (1.75:1).
    expect(_ratio(dark.primary, dark.textPrimary), lessThan(4.5));
  });

  test('Phase 3B: light error as text failed, so it is never text', () {
    const AppPalette light = AppPalette.light;
    expect(_ratio(light.error, light.background), lessThan(4.5));
    // As a UI component (icon, badge fill) it still clears 3:1.
    expect(_ratio(light.error, light.background), greaterThanOrEqualTo(3.0));
  });

  test('locked palette hex values are unchanged', () {
    expect(AppPalette.light.primary, const Color(0xFF4285F4));
    expect(AppPalette.light.success, const Color(0xFF0F9D58));
    expect(AppPalette.light.error, const Color(0xFFDB4437));
    expect(AppPalette.light.warning, const Color(0xFFF4B400));
    expect(AppPalette.light.background, const Color(0xFFFFFFFF));
    expect(AppPalette.dark.background, const Color(0xFF121212));
    expect(AppPalette.dark.surface, const Color(0xFF1E1E1E));
    expect(AppPalette.dark.surfaceVariant, const Color(0xFF2C2C2C));
    expect(AppPalette.dark.primary, const Color(0xFF8AB4F8));
    expect(AppPalette.dark.success, const Color(0xFF81C995));
    expect(AppPalette.dark.error, const Color(0xFFF28B82));
    expect(AppPalette.dark.warning, const Color(0xFFFDD663));
  });
}
