import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/decks/model/thumbnail_cache.dart';

Uint8List _bytes(int size) => Uint8List(size);

void main() {
  group('BoundedThumbnailCache', () {
    test('evicts the oldest entry past 64 entries', () {
      final BoundedThumbnailCache cache = BoundedThumbnailCache();
      for (int i = 0; i < 65; i++) {
        cache.put('id-$i', _bytes(10));
      }
      expect(cache.length, BoundedThumbnailCache.maxEntries);
      expect(cache.thumbnails.containsKey('id-0'), isFalse);
      expect(cache.thumbnails.containsKey('id-64'), isTrue);
    });

    test('byte budget evicts oldest until under budget', () {
      final BoundedThumbnailCache cache = BoundedThumbnailCache();
      cache.put('a', _bytes(8 * 1024 * 1024));
      cache.put('b', _bytes(8 * 1024 * 1024));
      cache.put('c', _bytes(8 * 1024 * 1024));
      expect(
        cache.totalBytes,
        lessThanOrEqualTo(BoundedThumbnailCache.maxBytes),
      );
      expect(cache.thumbnails.containsKey('a'), isFalse);
      expect(cache.thumbnails.containsKey('c'), isTrue);
    });

    test('failed entries do not count toward either budget', () {
      final BoundedThumbnailCache cache = BoundedThumbnailCache();
      for (int i = 0; i < 70; i++) {
        cache.markFailed('failed-$i');
      }
      expect(cache.failedThumbnails.length, 70);
      expect(cache.length, 0);
      expect(cache.totalBytes, 0);
    });

    test('a later success clears the failed mark', () {
      final BoundedThumbnailCache cache = BoundedThumbnailCache();
      cache.markFailed('x');
      expect(cache.contains('x'), isTrue);
      cache.put('x', _bytes(10));
      expect(cache.failedThumbnails.contains('x'), isFalse);
      expect(cache.thumbnails.containsKey('x'), isTrue);
    });

    test('clear resets entries, failures and bytes', () {
      final BoundedThumbnailCache cache = BoundedThumbnailCache();
      cache.put('a', _bytes(100));
      cache.markFailed('b');
      cache.clear();
      expect(cache.length, 0);
      expect(cache.failedThumbnails, isEmpty);
      expect(cache.totalBytes, 0);
    });
  });
}
