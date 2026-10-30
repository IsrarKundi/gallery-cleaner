// Production [LibraryEnumerationService]: two gateway passes
// (images, videos — fanned out together, as Cleanup fans its
// per-type queries out on one scope), merged by MediaStore id
// descending, memoised with an in-flight guard (ADR-017).

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
      // The already-running guard, at pass level: a forced fresh
      // pass requested while one is running joins it (its rows
      // are at most one pass old) instead of doubling the query.
      return inFlight;
    }
    final Future<Result<LibraryEnumeration>> future = _runPass();
    _inFlight = future;
    return future;
  }

  Future<Result<LibraryEnumeration>> _runPass() async {
    final int generation = _generation;
    try {
      final List<List<EnumeratedAsset>> passes = await Future.wait(
        <Future<List<EnumeratedAsset>>>[
          gateway.enumerateImages(),
          gateway.enumerateVideos(),
        ],
      );
      final List<EnumeratedAsset> rows =
          <EnumeratedAsset>[...passes[0], ...passes[1]]..sort(
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
      // Never memoised: the next call retries the pass, and
      // callers fall back to the legacy plugin path meanwhile.
      return const Failure<LibraryEnumeration>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    } finally {
      _inFlight = null;
    }
  }

  @override
  void invalidate() {
    _memo = null;
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
