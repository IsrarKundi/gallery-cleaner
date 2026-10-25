import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_colors.dart';

/// Asserts [color] equals the given 8-bit RGB triple, using the float
/// components so no raw colour literal appears outside app_colors.dart.
void expectRgb(Color color, int red, int green, int blue) {
  expect((color.r * 255.0).round().clamp(0, 255), red);
  expect((color.g * 255.0).round().clamp(0, 255), green);
  expect((color.b * 255.0).round().clamp(0, 255), blue);
}

void main() {
  group('AppPalette.light', () {
    const AppPalette palette = AppPalette.light;

    // Locked palette (owner pick, 25 Oct 2026, Option B "Google blue").
    test('pins the locked primary, Keep, Delete and Maybe values', () {
      expectRgb(palette.primary, 0x42, 0x85, 0xF4);
      expectRgb(palette.keep, 0x0F, 0x9D, 0x58);
      expectRgb(palette.delete, 0xDB, 0x44, 0x37);
      expectRgb(palette.maybe, 0xF4, 0xB4, 0x00);
    });

    test('pins onPrimary and background to white', () {
      expectRgb(palette.onPrimary, 0xFF, 0xFF, 0xFF);
      expectRgb(palette.background, 0xFF, 0xFF, 0xFF);
    });

    test('favourite uses the primary colour, not a second hue', () {
      expect(palette.favourite, palette.primary);
    });

    test('copyWith changes only the given role', () {
      final AppPalette copy = palette.copyWith(background: palette.surface);
      expect(copy.background, palette.surface);
      expect(copy.primary, palette.primary);
    });

    test('lerp at the ends returns the end palette values', () {
      expect(palette.lerp(palette, 0).primary, palette.primary);
      expect(palette.lerp(palette, 1).background, palette.background);
    });
  });
}
