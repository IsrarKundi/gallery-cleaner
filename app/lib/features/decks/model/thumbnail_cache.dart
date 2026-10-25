import 'dart:typed_data';

import 'package:get/get.dart';

// Bounded thumbnail cache (Phase 1.8, requirements §7).
//
// Caps the SmartDeck and Duplicates thumbnail maps, which were
// unbounded: a full duplicates pass could hold every member tile in
// memory. The count cap mirrors the deck preloader's 64-entry cache;
// the byte budget stops large JPEGs from blowing the count cap
// alone (a 512px JPEG is ~100KB, so 64 entries are ~6MB typical,
// but the budget is the hard ceiling).
//
// Eviction is oldest-inserted-first (FIFO), NOT LRU: views read the
// RxMap directly, so true LRU would need read tracking that only
// the Phase 2 shared thumbnail service can own. FIFO matches the
// deck preloader's policy, so all three caches now behave alike.
// Failed ids are remembered (no refetch loops) but never count
// toward either budget — they hold no bytes. A single entry larger
// than the whole budget is kept rather than evicting itself into a
// refetch loop; the budget still binds every multi-entry state.
class BoundedThumbnailCache {
  static const int maxEntries = 64;
  static const int maxBytes = 16 * 1024 * 1024;

  final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
  final RxSet<String> failedThumbnails = <String>{}.obs;

  int _totalBytes = 0;

  int get totalBytes => _totalBytes;
  int get length => thumbnails.length;

  bool contains(String id) =>
      thumbnails.containsKey(id) || failedThumbnails.contains(id);

  void put(String id, Uint8List bytes) {
    final Uint8List? previous = thumbnails[id];
    if (previous != null) {
      _totalBytes -= previous.length;
    }
    thumbnails[id] = bytes;
    _totalBytes += bytes.length;
    failedThumbnails.remove(id);
    _evict();
  }

  void markFailed(String id) {
    if (!thumbnails.containsKey(id)) {
      failedThumbnails.add(id);
    }
  }

  void clear() {
    thumbnails.clear();
    failedThumbnails.clear();
    _totalBytes = 0;
  }

  void _evict() {
    while (thumbnails.length > 1 &&
        (thumbnails.length > maxEntries || _totalBytes > maxBytes)) {
      final String oldest = thumbnails.keys.first;
      final Uint8List? removed = thumbnails.remove(oldest);
      if (removed != null) {
        _totalBytes -= removed.length;
      }
    }
  }
}
