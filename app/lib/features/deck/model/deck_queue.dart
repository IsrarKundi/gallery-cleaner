import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';

/// Index of the first asset in [queue] with no mark in [marks], or
/// [queue.length] when every loaded asset is decided. Pure helper
/// so the deck controller stays under its line budget; the deck
/// resumes at this index after a session load, an undo, and a
/// denied-confirmation rewind (requirements §5).
int firstUndecidedIndex(List<MediaAsset> queue, Map<String, DeckMark> marks) {
  for (int i = 0; i < queue.length; i++) {
    if (!marks.containsKey(queue[i].id)) {
      return i;
    }
  }
  return queue.length;
}

/// Phase 4.4 cheap page-0 refresh: merges a freshly fetched page 0
/// into the live queue WITHOUT a full reload, so a resume (or a
/// library-change event) reflects adds/deletes without losing
/// marks, session, or the user's position.
///
/// - Assets in [freshPageZero] but not in [queue] are prepended
///   in fresh order (newest first): brand-new photos appear.
/// - An old page-0 asset absent from [freshPageZero] is dropped
///   ONLY when it is provably gone, never merely displaced:
///   a full fresh page can push old members past the window
///   without deleting them. Proof rule (pages are newest-first):
///   if the fresh page is short ([freshPageZero] < [pageSize])
///   it enumerates the whole library, so every absent old
///   member is gone; if it is full, an absent old member is
///   gone only when its date is strictly newer than the fresh
///   window's oldest date — a present member newer than the
///   window end must sit inside the window, so absence proves
///   deletion, while an older-or-equal member may merely have
///   been displaced past the window and is kept.
/// - [index] is adjusted so the same card stays current:
///   +1 per prepended asset, −1 per dropped asset before it.
///   If the current card itself was deleted, the next card
///   becomes current. With no live current card (empty or
///   finished deck), new photos become current; otherwise the
///   finished sentinel is preserved.
/// - Marks are untouched by design: the caller owns marks, and a
///   dropped queue id's mark (if any) stays in the session until
///   review resolves it (gone ids are skipped there).
///
/// Honest bounds (this is the doc's CHEAP refresh, not a reload):
/// deeper queue order is not re-sorted, deletions beyond page 0
/// are not detected here, and pagination continues from its old
/// page numbering. A filter change, relaunch, or full scan
/// restores exact order. Never call this with a stale
/// [oldPageZero]: pass the assets of the last page-0 fetch.
({List<MediaAsset> queue, int index}) mergePageZero({
  required List<MediaAsset> queue,
  required List<MediaAsset> freshPageZero,
  required List<MediaAsset> oldPageZero,
  required int pageSize,
  required int index,
}) {
  final Set<String> queueIds = <String>{
    for (final MediaAsset asset in queue) asset.id,
  };
  final Set<String> freshIds = <String>{
    for (final MediaAsset asset in freshPageZero) asset.id,
  };
  // Provably gone, by the window rule in the doc comment above.
  // (Ids never in page 0 keep their unknown status.)
  final Set<String> removedIds;
  if (freshPageZero.length < pageSize) {
    // Short page enumerates the whole library.
    removedIds = <String>{
      for (final MediaAsset asset in oldPageZero)
        if (!freshIds.contains(asset.id)) asset.id,
    };
  } else {
    final DateTime windowEnd = freshPageZero.last.createDate;
    removedIds = <String>{
      for (final MediaAsset asset in oldPageZero)
        if (!freshIds.contains(asset.id) && asset.createDate.isAfter(windowEnd))
          asset.id,
    };
  }

  final List<MediaAsset> prepended = freshPageZero
      .where((MediaAsset asset) => !queueIds.contains(asset.id))
      .toList();
  final List<MediaAsset> merged = <MediaAsset>[
    ...prepended,
    for (final MediaAsset asset in queue)
      if (!removedIds.contains(asset.id)) asset,
  ];

  int removedBefore = 0;
  for (int i = 0; i < index && i < queue.length; i++) {
    if (removedIds.contains(queue[i].id)) {
      removedBefore++;
    }
  }
  int newIndex;
  if (queue.isEmpty || index >= queue.length) {
    // No live current card (empty or finished deck): new photos
    // become the current card (index 0); otherwise the finished
    // sentinel (index == length) is preserved, shifted only by
    // removals before it.
    if (merged.isEmpty) {
      newIndex = 0;
    } else if (prepended.isNotEmpty) {
      newIndex = 0;
    } else {
      newIndex = (index - removedBefore).clamp(0, merged.length);
    }
  } else {
    newIndex = index + prepended.length - removedBefore;
    if (merged.isEmpty) {
      newIndex = 0;
    } else {
      newIndex = newIndex.clamp(0, merged.length - 1);
    }
  }
  return (queue: merged, index: newIndex);
}
