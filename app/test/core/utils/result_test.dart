import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success folds to onSuccess and maps its value', () {
      const Result<int> result = Success<int>(3);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.fold(onSuccess: (int v) => v * 2, onFailure: (_) => -1), 6);
      final Result<String> mapped = result.map((int v) => 'n$v');
      expect(
        mapped.fold(onSuccess: (String v) => v, onFailure: (_) => ''),
        'n3',
      );
    });

    test('Failure folds to onFailure and maps without transforming', () {
      const Result<int> result = Failure<int>(
        AppFailure(messageKey: AppStrings.errorGeneric),
      );
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => '',
          onFailure: (AppFailure f) => f.messageKey,
        ),
        AppStrings.errorGeneric,
      );
      final Result<String> mapped = result.map((int v) => 'n$v');
      expect(mapped.isFailure, isTrue);
    });

    test('AppFailure resolves its key and unknown uses the generic key', () {
      const AppFailure failure = AppFailure(
        messageKey: AppStrings.errorGeneric,
      );
      expect(failure.userMessage, 'Something went wrong');
      expect(AppFailure.unknown().messageKey, AppStrings.errorGeneric);
    });
  });
}
