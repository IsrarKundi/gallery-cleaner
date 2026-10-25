// Favourites protection, shared by the deck, smart deck,
// duplicates and review controllers (Phase 3A).
//
// An asset is protected when EITHER source says favourite:
// - a Klara favourite: the asset id is in any saved session's
//   favouriteIds (down-gesture favourites, requirements §3), or
// - a system favourite: [MediaAsset.isSystemFavourite], mapped
//   from photo_manager's `AssetEntity.isFavorite` (Android 11+
//   IS_FAVORITE; always false below Android 11).
//
// There is deliberately NO "edited" check here: photo_manager
// 3.12.0 exposes no on-device edited flag for Android (its
// `hasAdjustments` note is Darwin-only), and MediaStore offers no
// edited column this app can read — so edited-detection is
// documented as unavailable rather than faked (see the Settings
// protection copy). Protection is enforced at every delete-marking
// point, never only at review, so a protected photo cannot slip
// through by a different route.

import '../local/local_service.dart';
import '../media/media_asset.dart';

/// Klara-favourite ids across ALL saved sessions, unioned. A
/// favourite made in one deck protects the photo in every deck.
Future<Set<String>> loadAllKlaraFavouriteIds(LocalService local) async {
  final sessions = await local.listSessions();
  return sessions.fold(
    onSuccess: (List<DeckSession> list) {
      final Set<String> ids = <String>{};
      for (final DeckSession session in list) {
        ids.addAll(session.favouriteIds);
      }
      return ids;
    },
    onFailure: (_) => <String>{},
  );
}

/// True when [asset] is protected by either favourite source.
/// [klaraFavourites] is the union from [loadAllKlaraFavouriteIds]
/// (callers that already hold a session's set may pass that set
/// plus the union — the check is a plain membership test).
bool isProtected(MediaAsset asset, {required Set<String> klaraFavourites}) {
  return klaraFavourites.contains(asset.id) || asset.isSystemFavourite;
}
