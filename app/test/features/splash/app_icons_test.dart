import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_icons.dart';

void main() {
  group('AppIcons', () {
    test('every constant is a valid IconData', () {
      // Phase 3A adds settings + eye + eyeSlash (30 -> 33).
      expect(AppIcons.all.length, 34);
      for (final IconData icon in AppIcons.all) {
        expect(icon.codePoint, greaterThan(0));
        expect(icon.fontFamily, isNotNull);
      }
    });

    test('favouriteActive is the filled variant, not the regular heart', () {
      expect(AppIcons.favouriteActive, isNot(AppIcons.favourite));
      expect(AppIcons.favouriteActive.fontFamily, contains('Fill'));
      expect(AppIcons.favourite.fontFamily, contains('Regular'));
    });
  });
}
