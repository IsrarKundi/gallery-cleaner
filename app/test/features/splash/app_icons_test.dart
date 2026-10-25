import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/constants/app_icons.dart';

void main() {
  group('AppIcons', () {
    test('every constant is a valid IconData', () {
      expect(AppIcons.all.length, 30);
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
