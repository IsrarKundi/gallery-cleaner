import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import 'maybe_pile_item.dart';

/// Maybe pile items, pure (extracted from [DecksController] in
/// Phase 3B to hold that file's line budget). The controller does
/// the reactive reads (sessions, snoozes, scanned) and delegates
/// here, so this costs O(user Maybe marks), not O(library), per
/// rebuild — the by-id map is built per scan page by the caller.
List<MaybePileItem> maybeItemsFor(
  List<DeckSession> sessions,
  Map<String, DateTime> snoozes,
  Map<String, MediaAsset> assetsById,
) {
  final List<MaybePileItem> items = <MaybePileItem>[];
  for (final DeckSession session in sessions) {
    for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
      if (mark.value != DeckMark.maybe) {
        continue;
      }
      final MediaAsset? asset = assetsById[mark.key];
      if (asset == null) {
        continue;
      }
      items.add(
        MaybePileItem(
          asset: asset,
          sessionKey: session.filterKey,
          snoozeUntil: snoozes[mark.key],
        ),
      );
    }
  }
  return items;
}
