# ADR-015: Shell Trash Tab Displays Union of Clean and Smart Deck Deletes

## Context

When users swiped to delete photos in a Smart Deck (e.g. Screenshots, Bursts, or a folder deck) and navigated to the Shell Trash tab, the Review screen showed 0 photos. Swipes on the Clean deck showed in the Trash tab correctly, but Smart Deck deletes were absent.

### Root Cause
1. `ShellController._pushReview` previously queried only `DeckController.deleteMarkedAssets` and passed `filterKey = deck.filter.value.filterKey` ('all').
2. Smart decks manage their own marks in `SmartDeckController` and store persisted sessions under keys prefixed with `'smart:'` (e.g. `'smart:screenshots'`).
3. Smart deck marks are marks-only (no 2-second undo or awaiting/pending pipeline). When a user navigates away from a folder deck, `SmartDeckController` is disposed (registered via `lazyPut`), meaning marks survive solely in `LocalService` persisted sessions.
4. `ReviewController` previously assumed a single origin `_filterKey` and only synced back to `DeckController`.

## Decision

1. **Union Set Construction (`buildReviewUnion`):**
   - The Trash tab gathers Clean deck deletes (pending + awaiting from `DeckController`) plus all delete-marked photos across smart decks.
   - Smart deck deletes are read from live `SmartDeckController` if active and from all persisted sessions starting with `'smart:'` in `LocalService`.
   - Photos are resolved to `MediaAsset`s via `MediaService.getAssetsByIds`.

2. **Deterministic, Visit-Stable Ordering:**
   - Within each deck's set, newest swipe is last (iterating chronological marks map). Clean deck maintains its awaiting-then-queued order.
   - Cross-deck ordering: Clean deck first, followed by smart decks sorted alphabetically by session key.
   - Numbers and order are stable across visits unless new swipes or review actions occur.

3. **Per-Origin Sync Back (`syncReviewUnmark`, `syncReviewKept`, `syncReviewDeleted`, `syncReviewDenied`):**
   - Each photo tracks its origin session key in `originSessionKeys` (passed via `ReviewLaunch`).
   - Review never writes the union set into a single session key, preventing cross-deck session corruption.
   - Actions sync to each origin session in `LocalService` independently.
   - If an origin controller is alive (e.g., `DeckController` or active `SmartDeckController`), its corresponding sync-back method is invoked (`unmarkAsset`, `markAssetsKept`, `removeTrashedAssets`, `handleDeniedTrash`).
   - If `SmartDeckController` is disposed, updating the persisted session in `LocalService` ensures changes reflect immediately upon re-entering the folder.

4. **Preserved Behaviors:**
   - Smart deck's internal "Go to Review" from inside a folder continues to work scoped to its own set and filterKey.
   - Clean deck 2-second undo and pending/awaiting pipeline remain unchanged.
   - Smart decks remain marks-only without an undo window.
   - Permanent deletion (ADR-014) applies equally to smart-deck photos in Review through the system confirmation dialog.
   - Review UI design from 26 Oct (no header, Select/Select-all button) preserved intact.
