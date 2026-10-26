// Default [DeckWarmUp]: permission, then page 0, via [MediaService].
//
// The warmed page is exactly `media.getAssets()` with defaults
// (page 0, the media default page size). [DeckController.pageSize]
// must stay equal to that default (both 50 today); if either side
// changes, the warmed page's "has more" bookkeeping diverges from a
// freshly fetched page. The deck applies the warmed page with the
// same `_hasMore` / `_nextPage` rules as a fresh page 0.

import '../../core/utils/result.dart';
import '../media/media_asset.dart';
import '../media/media_service.dart';
import 'deck_warm_up.dart';

class DeckWarmUpImpl implements DeckWarmUp {
  DeckWarmUpImpl({required this.media});

  final MediaService media;

  bool _started = false;
  Future<MediaPermission?>? _permissionFuture;
  Future<List<MediaAsset>?>? _firstPageFuture;

  /// The warmed page is handed out once, ever (see [DeckWarmUp]).
  /// A later deck — e.g. after a shell rebuild — fetches fresh
  /// instead of reusing a page warmed before a trash run.
  bool _pageConsumed = false;

  @override
  bool get started => _started;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _permissionFuture = _requestPermission();
    _firstPageFuture = _permissionFuture!.then(_loadFirstPage);
  }

  @override
  Future<MediaPermission?> get permission {
    return _permissionFuture ?? Future<MediaPermission?>.value(null);
  }

  @override
  Future<List<MediaAsset>?> get firstPage {
    if (_pageConsumed) {
      return Future<List<MediaAsset>?>.value(null);
    }
    _pageConsumed = true;
    return _firstPageFuture ?? Future<List<MediaAsset>?>.value(null);
  }

  Future<MediaPermission?> _requestPermission() async {
    Result<MediaPermission>? result;
    try {
      result = await media.requestPermission();
    } catch (_) {
      return null;
    }
    return result.fold(
      onSuccess: (MediaPermission value) => value,
      onFailure: (_) => null,
    );
  }

  Future<List<MediaAsset>?> _loadFirstPage(MediaPermission? permission) async {
    if (permission == null || permission == MediaPermission.denied) {
      return null;
    }
    Result<List<MediaAsset>>? result;
    try {
      result = await media.getAssets();
    } catch (_) {
      return null;
    }
    return result.fold(
      onSuccess: (List<MediaAsset> assets) => assets,
      onFailure: (_) => null,
    );
  }
}
