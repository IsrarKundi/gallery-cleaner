# ADR-014: Permanent deletion from Review

## Context

Review's delete button (bottom bar "Delete N photos" / "Delete X") previously moved photos to the system Trash (recoverable for 30 days) via `TrashService.trashAssets` and `MediaStore.createTrashRequest`. Whole-set deletes navigated to the Trash screen (`AppRoutes.trash`).

On 26 Oct 2026, the owner requested that the Review delete button perform a permanent deletion instead of moving photos to Trash.

## Conflict, reported not resolved

This CONFLICTS with requirements §4.4 ("Trash: 30 days, recoverable"), §4.5 ("Permanent deletion happens ONLY when the user empties Trash or the 30 days expire"), and the standing rule "Three-state accounting: never claim space freed while it sits in Trash".
The owner's explicit 26 Oct 2026 order outranks those rules for Review deletes. The conflict is recorded in `requirements.md` §4 and here rather than being silently resolved.

## Decision

1. **Delete-by-IDs method:** Added `deletePermanently(List<String> ids)` to `TrashService` and `TrashServiceImpl`, reusing `TrashGateway.deleteIds` (`PhotoManager.editor.deleteWithIds` -> `MediaStore.createDeleteRequest` on API 30+). Never deletes silently.
2. **ReviewController:** `ReviewController.deleteSelected` calls `trash.deletePermanently` instead of `trash.trashAssets`. Outcome enum updated to `ReviewDeleteOutcome.deleted`.
3. **Space accounting & history:** Permanently deleted photos do not enter the Trash record (`TrashEntry`). Space is counted directly as freed: `mbFreed = bytes / 1048576, mbTrashed = 0`.
4. **Navigation:** A whole-set permanent delete returns to the deck (`controller.goToDeck()`). It does not push the Trash screen, because nothing entered Trash.
5. **Outcome & denial handling:**
   - Succeeded: Grid items removed, session marks cleared, space meter refreshed, and deck notified via `removeTrashedAssets`.
   - Denied: Photos stay in Review / return to the deck with existing denial explanation, but without a "View trash" action (nothing was trashed).
   - Failed: Unresolvable photos stay with error handling.
6. **Undo safety:** `DeckController.removeTrashedAssets` explicitly cleans `undoStack` (`undoStack.removeWhere((id) => ids.contains(id))`), ensuring permanently deleted photos can never reappear in Review or the deck through undo.

## Explicitly out of scope

- Trash screen code remains intact; it is simply no longer fed by Review.
- Clean deck 2-second undo window and batched trash on tab leave remain untouched.
- The owner's Review screen design (no header, Select/Select-all button) remains intact without restoring commented-out elements.
