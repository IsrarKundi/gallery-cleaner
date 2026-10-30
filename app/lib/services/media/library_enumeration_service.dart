// The one-pass library enumeration, shared by the media service
// and the library scan (fix plan Stage 2, ADR-017).
//
// Kept OFF the MediaService interface on purpose — the same call
// Stage 1 and the change-source made: every test fake implements
// MediaService, and query capabilities that arrive later ride in
// narrow services injected where they are used. Consumers here:
// MediaServiceImpl (its pages and id lookups are served from the
// memoised pass) and the ScanRepository's scanner (each run
// takes one FRESH pass, as Cleanup's scan re-queries MediaStore
// in full every time).
//
// One pass = one gateway call per media type. Concurrent calls
// share the single in-flight pass (the already-running guard:
// starting twice never runs two passes). A completed pass is
// memoised until [invalidate] — permission change or a library
// change event — or until a forced fresh pass replaces it.
// A failed pass is never memoised.

import '../../core/utils/result.dart';
import 'enumerated_asset.dart';

/// One completed enumeration pass.
class LibraryEnumeration {
  const LibraryEnumeration({required this.rows, required this.bucketNames});

  /// Every row from both passes, merged newest first — MediaStore
  /// id descending, which is the order the plugin's default sort
  /// produced for the mixed-type library (see ADR-017). Rows
  /// include ones whose file is gone ([EnumeratedAsset.fileExists]
  /// is false): asset lists filter them out, bucket bookkeeping
  /// keeps them, mirroring the plugin's two views of the library.
  final List<EnumeratedAsset> rows;

  /// Bucket id → display name for every bucket any row names,
  /// including buckets whose files are all gone.
  final Map<String, String> bucketNames;
}

abstract class LibraryEnumerationService {
  /// The memoised pass, or a fresh one when there is none yet or
  /// [forceRefresh] is set. Concurrent callers join the single
  /// in-flight pass instead of starting another.
  Future<Result<LibraryEnumeration>> enumerate({bool forceRefresh = false});

  /// Drops the memoised pass; the next [enumerate] re-queries.
  /// A pass already in flight still delivers to its callers but
  /// no longer memoises its (possibly stale) result.
  void invalidate();
}
