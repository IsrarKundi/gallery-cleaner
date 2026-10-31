// Production [LibraryEnumerationService]: two gateway passes
// (images, videos — fanned out together, as Cleanup fans its
// per-type queries out on one scope), merged by MediaStore id
// descending, memoised with an in-flight guard (ADR-017).
//
// The merged read and the per-type reads (ADR-026) run on the
// same machinery: each media type has its own memo slot and its
// own in-flight slot, and [enumerate] is just the join of the
// two per-type reads plus the merge. A scanner asking for the
// types separately and a media service asking for the merged
// pass therefore share ONE gateway call per type, and a type
// that fails fails only its own readers — the other type's
// result still lands and still memoises.

import 'dart:async';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'enumerated_asset.dart';
import 'library_enumeration_service.dart';
import 'media_enumeration_gateway.dart';

class LibraryEnumerationServiceImpl implements LibraryEnumerationService {
  LibraryEnumerationServiceImpl({
    required this.gateway,
    Stream<void>? libraryChanged,
  }) {
    // The app's library-change flag (photo_manager delivery via
    // AppLifecycle): the same event the deck and hub reconcile
    // on. A change drops the memo so the next read re-queries —
    // the enumeration never serves a library the device no
    // longer has.
    _changeSubscription = libraryChanged?.listen((_) => invalidate());
  }

  final MediaEnumerationGateway gateway;

  StreamSubscription<void>? _changeSubscription;

  LibraryEnumeration? _memo;
  Future<Result<LibraryEnumeration>>? _inFlight;

  /// Per-type memo slots (ADR-026): a completed type pass is
  /// held here and in the merged [_memo] together; [invalidate]
  /// drops both.
  List<EnumeratedAsset>? _imagesMemo;
  List<EnumeratedAsset>? _videosMemo;

  /// Per-type in-flight slots: the already-running guard lives
  /// here now, so every read shape joins the same gateway call.
  Future<Result<List<EnumeratedAsset>>>? _imagesInFlight;
  Future<Result<List<EnumeratedAsset>>>? _videosInFlight;

  /// Bumped by [invalidate]: a pass that started before the
  /// bump still answers its callers but must not memoise —
  /// its rows may predate the change that invalidated it.
  int _generation = 0;

  @override
  Future<Result<LibraryEnumeration>> enumerate({bool forceRefresh = false}) {
    final LibraryEnumeration? memo = _memo;
    if (!forceRefresh && memo != null) {
      return Future<Result<LibraryEnumeration>>.value(
        Success<LibraryEnumeration>(memo),
      );
    }
    final Future<Result<LibraryEnumeration>>? inFlight = _inFlight;
    if (inFlight != null) {
      // The already-running guard: a forced fresh pass requested
      // while one is running joins it (its rows are at most one
      // pass old) instead of doubling the query.
      return inFlight;
    }
    final Future<Result<LibraryEnumeration>> future = _runPass(
      forceRefresh: forceRefresh,
    );
    _inFlight = future;
    return future;
  }

  Future<Result<LibraryEnumeration>> _runPass({
    required bool forceRefresh,
  }) async {
    final int generation = _generation;
    try {
      final List<Result<List<EnumeratedAsset>>> passes = await Future.wait(
        <Future<Result<List<EnumeratedAsset>>>>[
          _typePass(images: true, forceRefresh: forceRefresh),
          _typePass(images: false, forceRefresh: forceRefresh),
        ],
      );
      final Result<List<EnumeratedAsset>> images = passes[0];
      final Result<List<EnumeratedAsset>> videos = passes[1];
      if (images is Failure<List<EnumeratedAsset>> ||
          videos is Failure<List<EnumeratedAsset>>) {
        // Never memoised: the next call retries the failed type
        // (the type that succeeded keeps its own memo — its
        // rows are not made stale by the other type's failure).
        return const Failure<LibraryEnumeration>(
          AppFailure(messageKey: AppStrings.errorMediaLoad),
        );
      }
      final List<EnumeratedAsset> rows =
          <EnumeratedAsset>[
            ...(images as Success<List<EnumeratedAsset>>).value,
            ...(videos as Success<List<EnumeratedAsset>>).value,
          ]..sort(
            (EnumeratedAsset a, EnumeratedAsset b) =>
                _idValue(b).compareTo(_idValue(a)),
          );
      final Map<String, String> bucketNames = <String, String>{};
      for (final EnumeratedAsset row in rows) {
        bucketNames.putIfAbsent(row.bucketId, () => row.bucketName);
      }
      final LibraryEnumeration enumeration = LibraryEnumeration(
        rows: rows,
        bucketNames: bucketNames,
      );
      if (generation == _generation) {
        _memo = enumeration;
      }
      return Success<LibraryEnumeration>(enumeration);
    } catch (_) {
      // The per-type reads report their own failures as results;
      // this guards the merge itself, keeping enumerate()'s
      // contract that a pass answers with a Result, never a throw.
      return const Failure<LibraryEnumeration>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    } finally {
      _inFlight = null;
    }
  }

  @override
  Future<Result<List<EnumeratedAsset>>> enumerateImages({
    bool forceRefresh = false,
  }) {
    return _typePass(images: true, forceRefresh: forceRefresh);
  }

  @override
  Future<Result<List<EnumeratedAsset>>> enumerateVideos({
    bool forceRefresh = false,
  }) {
    return _typePass(images: false, forceRefresh: forceRefresh);
  }

  /// One type's read: memo first (unless forced), then the
  /// in-flight join, then a fresh gateway call. Rows are sorted
  /// by MediaStore id descending — the pass's own order, the
  /// one the native query produces — so a per-type consumer
  /// sees exactly its slice of the merged ordering.
  Future<Result<List<EnumeratedAsset>>> _typePass({
    required bool images,
    required bool forceRefresh,
  }) {
    final List<EnumeratedAsset>? memo = images ? _imagesMemo : _videosMemo;
    if (!forceRefresh && memo != null) {
      return Future<Result<List<EnumeratedAsset>>>.value(
        Success<List<EnumeratedAsset>>(memo),
      );
    }
    final Future<Result<List<EnumeratedAsset>>>? inFlight = images
        ? _imagesInFlight
        : _videosInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<Result<List<EnumeratedAsset>>> future = _runTypePass(
      images: images,
    );
    if (images) {
      _imagesInFlight = future;
    } else {
      _videosInFlight = future;
    }
    return future;
  }

  Future<Result<List<EnumeratedAsset>>> _runTypePass({
    required bool images,
  }) async {
    final int generation = _generation;
    try {
      final List<EnumeratedAsset> rows = images
          ? await gateway.enumerateImages()
          : await gateway.enumerateVideos();
      final List<EnumeratedAsset> sorted = List<EnumeratedAsset>.of(rows)
        ..sort(
          (EnumeratedAsset a, EnumeratedAsset b) =>
              _idValue(b).compareTo(_idValue(a)),
        );
      if (generation == _generation) {
        if (images) {
          _imagesMemo = sorted;
        } else {
          _videosMemo = sorted;
        }
        // Fresh rows for one type make any merged memo stale:
        // drop it, so a later merged read rebuilds from the
        // per-type memos instead of serving the old merge. (A
        // merged read running right now re-sets it when it
        // joins — its awaits complete after this pass lands.)
        _memo = null;
      }
      return Success<List<EnumeratedAsset>>(sorted);
    } catch (_) {
      // Never memoised: the next call retries the type, and
      // merged callers fall back to the legacy plugin path
      // meanwhile.
      return const Failure<List<EnumeratedAsset>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    } finally {
      if (images) {
        _imagesInFlight = null;
      } else {
        _videosInFlight = null;
      }
    }
  }

  @override
  void invalidate() {
    _memo = null;
    _imagesMemo = null;
    _videosMemo = null;
    _generation++;
  }

  /// Stops the library-change subscription (tests and binding
  /// teardown; the production instance is permanent).
  void dispose() {
    _changeSubscription?.cancel();
    _changeSubscription = null;
  }

  /// MediaStore ids are numeric strings; a non-numeric id (never
  /// expected from MediaStore) sorts as 0 rather than crashing
  /// the merge.
  static int _idValue(EnumeratedAsset row) => int.tryParse(row.id) ?? 0;
}
