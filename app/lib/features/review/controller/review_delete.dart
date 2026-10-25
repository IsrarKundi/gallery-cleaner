import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/local/protection.dart';
import '../../../services/media/media_asset.dart';

/// Phase 3B extraction from [ReviewController] (which sits at its
/// ~400-line budget): the favourites-protection filter for a delete
/// run, as a pure service-call helper.
///
/// When protection is ON, favourited items (Klara favourites from
/// any session, plus the current session's favourites, plus system
/// favourites) are EXCLUDED from the trash run — they stay in the
/// grid and [ReviewDeletePlan.protectedCount] explains how many.
/// When protection is OFF (or settings fail to load, the safe
/// default), nothing is excluded and the plan is the whole set.
/// Nothing here deletes: the controller still owns the native
/// confirmation and the outcome handling.
class ReviewDeletePlan {
  const ReviewDeletePlan({
    required this.toDelete,
    required this.protectedCount,
  });

  /// Items cleared to go to the native confirmation.
  final List<MediaAsset> toDelete;

  /// Items held back by protection (still in the grid).
  final int protectedCount;
}

Future<ReviewDeletePlan> planReviewDelete({
  required List<MediaAsset> items,
  required LocalService local,
  required String filterKey,
}) async {
  final Result<AppSettings> settingsResult = await local.loadSettings();
  final bool protectionOn = settingsResult.fold(
    onSuccess: (AppSettings value) => value.protection,
    onFailure: (_) => false,
  );
  if (!protectionOn) {
    return ReviewDeletePlan(toDelete: items.toList(), protectedCount: 0);
  }
  final Set<String> klaraFavourites = await loadAllKlaraFavouriteIds(local);
  final Result<DeckSession?> sessionResult = await local.loadSession(filterKey);
  sessionResult.fold(
    onSuccess: (DeckSession? session) {
      if (session != null) {
        klaraFavourites.addAll(session.favouriteIds);
      }
    },
    onFailure: (_) {},
  );
  final List<MediaAsset> protected = items
      .where(
        (MediaAsset asset) =>
            isProtected(asset, klaraFavourites: klaraFavourites),
      )
      .toList();
  if (protected.isEmpty) {
    return ReviewDeletePlan(toDelete: items.toList(), protectedCount: 0);
  }
  final Set<String> protectedIds = protected
      .map((MediaAsset a) => a.id)
      .toSet();
  return ReviewDeletePlan(
    toDelete: items
        .where((MediaAsset asset) => !protectedIds.contains(asset.id))
        .toList(),
    protectedCount: protected.length,
  );
}
