# ADR-010 — Review selection mode; document guard and Review blur removed

Date: 2026-10-26. Owner direction: remove the document guard and
tap-to-reveal; photos must be revealed, and the user must be able
to select photos one by one, with a Select text button, Select all,
and Delete/Recover buttons that carry the selected count.

## Removed

- Document guard (Phase 4): the document-like scan, the banner,
  the delete-time confirmation dialog, and the keep-guarded path
  are all deleted — the service, its tests, the controller fields,
  and the strings. Deleting a document-like photo now behaves like
  any other photo: the native sheet confirms, Trash keeps it 30
  days. The favourites-protection exclusion (Phase 3A) is a
  different feature and stays.
- Review private blur and tap-to-reveal: Review tiles always show
  the photo. The Review blur state, the eye toggle, the reveal
  callbacks, and the blur sigma token are deleted. The Settings
  private-blur toggle and the Trash blur toggle are untouched —
  the owner asked about Review only, so those screens keep their
  existing behaviour.

## Added: selection mode

- Entry: long-press a tile (that tile starts selected) or the
  header's Select text button (nothing pre-selected).
- While active, tile taps toggle selection instead of unmarking;
  selected tiles show a filled check circle + primary border,
  unselected tiles an outlined circle (design.md §9: selection
  always carries checkmark + border, never colour alone).
- The header button label flips to Select all in mode; tapping it
  selects every photo in the set.
- The bottom bar acts on the selection when one exists: Keep X
  photos (unmarks only the selection, back to the deck as kept)
  and Delete X photos (deletes only the selection through the
  native sheet). Without a selection both act on the whole set
  exactly as before (Keep all / Delete N photos).
- The mode ends when the selection empties or the back control
  cancels it; a second back leaves the screen. Selection is
  transient UI state — it never persists and never survives
  leaving the screen.
- A partial delete (selection trashed, rest still marked) stays
  on the Review screen with a snackbar; only a whole-set delete
  navigates to the Trash screen, as before. The failed-tile retry
  button moves to the tile's bottom-left in selection mode so it
  never covers the top-left checkbox.

## What does not change

- The trust rules (requirements §4): swipes only mark, the native
  sheet is the only path to Trash, Trash keeps photos 30 days,
  nothing auto-deletes.
- The deck, the shell (ADR-009), and the Trash screen's own
  behaviour. The post-delete Trash navigation is unchanged for
  whole-set runs.
- Commented-out UI stays untouched.

## Verification

- New test file `review_selection_test.dart` (10 tests): state
  transitions, keep-selected, delete-selected-subset, tile
  checkbox rendering with no blur filter, and the full view flow
  (long-press, Select/Select all, delete-selected, back-cancel).
- `flutter analyze` clean; full `flutter test` green except the
  known pre-existing Review empty-state failure (baseline
  exception, intentionally-commented CTA, never restored).
- Device check still owed by the owner (this VM has no Android
  SDK): long-press, Select/Select all, Delete X / Keep X, and
  back-cancel on a phone.
