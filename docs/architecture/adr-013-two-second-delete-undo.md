# ADR-013: Two-second undo window for Clean-deck delete swipes

## Context

The delete flow had three forced stops: swipe (mark) → Review →
Trash screen, plus a native sheet. The owner reported the Review and
Trash steps as friction (26 Oct 2026) and specified a new model:
swipe right to delete, Undo live for 2 seconds, tap Undo in the
window and the photo comes back, after 2 seconds (or on the next
swipe) the photo is deleted, Undo greys out. "Deleted" was confirmed
to mean moved to Trash (recoverable), never erased on the spot.

## Conflict, reported not resolved

This CONFLICTS with requirements §3 ("nothing is deleted by the
swipe itself"), §4.1 ("no swipe ever deletes anything") and §4.7
("every deletion is user-confirmed via review + native sheet"), and
with the AGENTS.md "never skip review" rule. The owner's explicit
26 Oct 2026 order outranks those rules, so the change is built and
requirements §3/§4 carry a dated amendment recording it, rather
than the conflict being silently resolved. What does NOT change:
the native sheet remains the only path to Trash (§4.3), nothing is
claimed deleted before it, Trash stays 30 days recoverable, and
permanent deletion still happens only via emptying or expiry.

## Decision

Clean deck only (DeckController; smart decks use
SmartDeckController and are untouched):

- A delete mark starts a 2-second window. Undo in the window pops
  the mark and returns the card (existing undo, unchanged).
- On timeout, or on the next recorded mark of any kind, the photo
  commits: it leaves the deck queue and its undo entry and waits
  in an in-memory awaiting list. Its delete mark is KEPT (in
  memory and in the session) until the native batch lands.
- The native sheet fires ONCE, batched, when the user leaves the
  Clean deck (shell tab switch away from Clean). Per-photo sheets
  would interrupt swiping, which is the friction being removed.
- Before trashing, the batch verifies intent against the session:
  a photo Review kept or unmarked after its swipe rewinds to the
  deck undecided; a photo Review already trashed is dropped, never
  re-trashed or rewound. A failed session read fails safe (nothing
  trashed, batch waits for the next trigger).
- Denied photos rewind to the deck with a banner (new
  `trashBatchDenied` string); unreachable photos are dropped.
  After success the meter refreshes from the trash service.
- If the app dies with photos awaiting, they reappear undecided
  on the next launch (MediaStore still has them): safe, and the
  only known gap — there is no background flush in v1.

## Explicitly out of scope here

- Review's post-delete Trash-screen landing lives in
  `review_view.dart`, a file the owner edited himself on
  26 Oct 2026 ("trash screen design fixes") and forbade touching.
  It is deliberately unchanged: whole-set Review deletes still
  land on the Trash screen. Changing that landing needs his word
  for that exact spot, or his own edit.
- The owner's two review files (`review_view.dart`,
  `review_grid_tile.dart`) were not modified, and nothing he
  commented out there was restored.
- The Trash screen (TrashView) itself is not redesigned.
- No new permission, no new string outside `app_strings.dart`,
  no `Get.snackbar` (denial reaches the UI as controller state +
  banner, per repo rules).

## Consequences

- The main delete path no longer needs Review at all; Review
  stays for anything still delete-marked (e.g. marks made before
  this change, or a photo whose commit was skipped).
- DeckController grows past its ~400-line budget further (it was
  already over); the new code is kept in one cohesive block
  rather than split across a new file, because it needs the
  controller's queue, marks, persist, preloader and services.
- Tests must cover: undo inside the window, commit on timeout,
  commit on next swipe, batch on leaving Clean, denied rewind +
  banner, kept/unmarked rewind, already-trashed drop, and the
  session-read failure path.
