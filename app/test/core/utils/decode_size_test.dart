import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/decode_size.dart';

void main() {
  group('decodeSide', () {
    test('decodes at display size when smaller than the source', () {
      expect(
        decodeSide(
          width: 100,
          height: 100,
          devicePixelRatio: 2,
          sourceSize: 512,
        ),
        200,
      );
    });

    test('longest edge governs a non-square container', () {
      expect(
        decodeSide(
          width: 100,
          height: 300,
          devicePixelRatio: 2,
          sourceSize: 1024,
        ),
        600,
      );
    });

    test('never upscales past the source size', () {
      expect(
        decodeSide(
          width: 400,
          height: 400,
          devicePixelRatio: 3,
          sourceSize: 512,
        ),
        512,
      );
    });

    test('unbounded or degenerate containers fall back to source', () {
      expect(
        decodeSide(
          width: double.infinity,
          height: 100,
          devicePixelRatio: 3,
          sourceSize: 256,
        ),
        256,
      );
      expect(
        decodeSide(width: 0, height: 0, devicePixelRatio: 3, sourceSize: 256),
        256,
      );
    });
  });
}
