import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';

void main() {
  group('AppStrings', () {
    test('every key resolves to non-empty English text', () {
      for (final String key in AppStrings.en.keys) {
        final String value = AppStrings.tr(key);
        expect(value, isNotEmpty, reason: 'key $key must resolve');
        expect(
          value,
          isNot(equals(key)),
          reason: 'key $key must be translated',
        );
      }
    });

    test('fills placeholders from params', () {
      expect(
        AppStrings.tr(AppStrings.meterInTrash, <String, String>{
          'date': '24 Nov 2026',
        }),
        'In trash until 24 Nov 2026',
      );
      expect(
        AppStrings.tr(AppStrings.reviewDeleteCount, <String, String>{
          'count': '7',
        }),
        'Delete 7 photos',
      );
    });

    test('covers the locked edge labels and trust strings', () {
      expect(AppStrings.tr(AppStrings.edgeKeep), 'KEEP');
      expect(AppStrings.tr(AppStrings.edgeDelete), 'DELETE');
      expect(AppStrings.tr(AppStrings.edgeMaybe), 'MAYBE');
      expect(AppStrings.tr(AppStrings.edgeFavourite), 'FAVOURITE');
      expect(AppStrings.tr(AppStrings.appTitle), 'Klara');
      expect(AppStrings.tr(AppStrings.deniedConfirmMessage), contains('deck'));
    });

    test('unknown keys resolve to the key itself', () {
      expect(AppStrings.tr('noSuchKey'), 'noSuchKey');
    });
  });
}
