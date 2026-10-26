# ADR-012: Trash tab passes the delete set as Review route arguments

## Context

The bottom-nav Trash tab opened Review with a plain push and no route
arguments, so Review always took its session path: `isLoading = true`,
loading skeleton, then a MediaStore re-resolve of the delete set, then
the grid popping in. A user screen recording (26 Oct 2026) showed the
effect on a real phone: tap Trash, skeleton flash, photos pop in —
while Clean/Decks/Settings switches, which keep their content mounted,
feel instant. The push/pop transitions themselves are near-instant
cuts; the unsmooth part was the loading state, not the animation.

The deck's own go-to-review already passed the delete set as arguments
(`DeckController._goToReviewNow`), and `ReviewBinding` already accepts
a `List<MediaAsset>` argument list — the shell just never used it.

## Decision

`ShellController._pushReview` passes the deck's current
`deleteMarkedAssets` as route arguments plus the deck's current filter
key as the `filterKey` parameter, exactly mirroring `_goToReviewNow`.
Review then renders its count, buttons and tiles on the first frame;
thumbnails still arrive asynchronously into placeholder tiles, as on
the deck path.

## Consequences

- The skeleton on the Trash path is gone for every non-empty delete
  set. The empty case is unchanged: an empty argument list still
  falls through to the session path and its empty view, as before.
- Arguments are read inside `_pushReview`, which runs after the
  settled-review gate releases, so a mark recorded during a gated
  wait is included in the pushed set (the gate guarantee is intact).
- When the deck is unresolvable, the plain push stands and Review
  falls back to the session path, skeleton included — a tap is never
  stranded by this change.
- The Decks hub's own late content (banner, totals, smart-deck
  counts updating as the background scan lands) is live scan
  progress, not a switch defect, and is deliberately untouched here.
