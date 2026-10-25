// Default [ThumbnailService]: one byte LRU + in-flight dedup over
// [MediaService] (see thumbnail_service.dart for the contract).
//
// The dedup invariant: every fetch registers its [_Flight] in
// [_inFlight] synchronously, before the returned future is awaited
// by anyone, and a key stays registered until its fetch completes.
// There is no await between the cache/in-flight check and the
// registration, so two synchronous callers for the same key can
// never start two fetches. `getThumbnail` itself is NOT async for
// exactly this reason: its body runs atomically to the registration.

import 'dart:collection';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../media/media_service.dart';
import 'thumbnail_service.dart';

class _Flight {
  Future<Result<Uint8List>>? future;
  bool cancelled = false;
}

class ThumbnailServiceImpl implements ThumbnailService {
  ThumbnailServiceImpl({required this.media});

  final MediaService media;

  /// Byte LRU, in access order (recently used moves to the end).
  final LinkedHashMap<ThumbnailKey, Uint8List> _bytes =
      LinkedHashMap<ThumbnailKey, Uint8List>();
  int _bytesTotal = 0;

  /// Bounds (solutions 2.3): generous for deck-sized thumbnails,
  /// small enough that a huge library cannot grow memory unbounded.
  static const int _maxEntries = 512;
  static const int _maxBytes = 32 * 1024 * 1024;

  final Map<ThumbnailKey, _Flight> _inFlight = <ThumbnailKey, _Flight>{};

  final Map<(int, int), RxMap<String, Uint8List>> _thumbnails =
      <(int, int), RxMap<String, Uint8List>>{};
  final Map<(int, int), RxSet<String>> _failed = <(int, int), RxSet<String>>{};

  /// Last prefetch window per (size, quality), for failed re-entry.
  final Map<(int, int), Set<String>> _lastPrefetch =
      <(int, int), Set<String>>{};

  @override
  RxMap<String, Uint8List> thumbnailsFor(int size, {int quality = 85}) {
    return _thumbnails.putIfAbsent((
      size,
      quality,
    ), () => <String, Uint8List>{}.obs);
  }

  @override
  RxSet<String> failedFor(int size, {int quality = 85}) {
    return _failed.putIfAbsent((size, quality), () => <String>{}.obs);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) {
    final ThumbnailKey key = (id: assetId, size: size, quality: quality);
    final Uint8List? cached = _bytes[key];
    if (cached != null) {
      _touch(key);
      return Future<Result<Uint8List>>.value(Success<Uint8List>(cached));
    }
    final _Flight? existing = _inFlight[key];
    if (existing != null) {
      return existing.future!;
    }
    // Controller request retries a failed id: clear the mark and
    // fetch again (with the one automatic retry on failure).
    failedFor(size, quality: quality).remove(assetId);
    final _Flight flight = _Flight();
    final Future<Result<Uint8List>> future = _fetch(key, flight);
    flight.future = future;
    _inFlight[key] = flight;
    return future;
  }

  @override
  void requestThumbnail(String assetId, int size, {int quality = 85}) {
    final ThumbnailKey key = (id: assetId, size: size, quality: quality);
    if (_bytes.containsKey(key)) {
      _touch(key);
      return;
    }
    if (_inFlight.containsKey(key)) {
      return;
    }
    // Failed ids wait for an explicit retry or a window re-entry;
    // a widget rebuild must never refetch them in a loop.
    if (failedFor(size, quality: quality).contains(assetId)) {
      return;
    }
    final _Flight flight = _Flight();
    flight.future = _fetch(key, flight);
    _inFlight[key] = flight;
  }

  @override
  void prefetch(List<String> ids, int size, {int quality = 85}) {
    final Set<String> previous = _lastPrefetch[(size, quality)] ?? <String>{};
    final RxSet<String> failed = failedFor(size, quality: quality);
    for (final String id in ids) {
      final ThumbnailKey key = (id: id, size: size, quality: quality);
      if (_bytes.containsKey(key)) {
        _touch(key);
        continue;
      }
      if (_inFlight.containsKey(key)) {
        continue;
      }
      if (failed.contains(id)) {
        // Still in the window: do not refetch on every prefetch
        // call (retry storm). Left the window and re-entered:
        // retry once (the mark clears below).
        if (previous.contains(id)) {
          continue;
        }
        failed.remove(id);
      }
      final _Flight flight = _Flight();
      flight.future = _fetch(key, flight);
      _inFlight[key] = flight;
    }
    _lastPrefetch[(size, quality)] = ids.toSet();
  }

  @override
  void cancelOutside(Set<ThumbnailKey> wanted) {
    for (final MapEntry<ThumbnailKey, _Flight> entry in _inFlight.entries) {
      if (!wanted.contains(entry.key)) {
        entry.value.cancelled = true;
      }
    }
  }

  @override
  void retry(String assetId, int size, {int quality = 85}) {
    failedFor(size, quality: quality).remove(assetId);
  }

  @override
  void clear() {
    for (final _Flight flight in _inFlight.values) {
      flight.cancelled = true;
    }
    _bytes.clear();
    _bytesTotal = 0;
    for (final RxMap<String, Uint8List> map in _thumbnails.values) {
      map.clear();
    }
    for (final RxSet<String> set in _failed.values) {
      set.clear();
    }
    _lastPrefetch.clear();
  }

  /// One fetch with one automatic retry on failure. Cancellation is
  /// checked before the retry and before publishing: a cancelled
  /// completion is dropped entirely (waiter gets a failure, nothing
  /// is cached, nothing is marked failed).
  Future<Result<Uint8List>> _fetch(ThumbnailKey key, _Flight flight) async {
    Result<Uint8List> result = await media.getThumbnail(
      key.id,
      key.size,
      quality: key.quality,
    );
    if (result.isFailure && !flight.cancelled) {
      result = await media.getThumbnail(key.id, key.size, quality: key.quality);
    }
    _inFlight.remove(key);
    if (flight.cancelled) {
      return const Failure<Uint8List>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return result.fold(
      onSuccess: (Uint8List bytes) {
        _store(key, bytes);
        return Success<Uint8List>(bytes);
      },
      onFailure: (AppFailure failure) {
        failedFor(key.size, quality: key.quality).add(key.id);
        return Failure<Uint8List>(failure);
      },
    );
  }

  void _store(ThumbnailKey key, Uint8List bytes) {
    final Uint8List? old = _bytes.remove(key);
    if (old != null) {
      _bytesTotal -= old.length;
    }
    _bytes[key] = bytes;
    _bytesTotal += bytes.length;
    thumbnailsFor(key.size, quality: key.quality)[key.id] = bytes;
    failedFor(key.size, quality: key.quality).remove(key.id);
    while (_bytes.length > _maxEntries || _bytesTotal > _maxBytes) {
      final ThumbnailKey oldest = _bytes.keys.first;
      final Uint8List removed = _bytes.remove(oldest)!;
      _bytesTotal -= removed.length;
      thumbnailsFor(oldest.size, quality: oldest.quality).remove(oldest.id);
    }
  }

  void _touch(ThumbnailKey key) {
    final Uint8List? bytes = _bytes.remove(key);
    if (bytes != null) {
      _bytes[key] = bytes;
    }
  }
}
