# ADR-027: All Albums Screen — See-All Destination and the Album Launch

## Context

On 31 Oct 2026 the owner, testing on a real device, pointed at
the "See all (N) ›" text beside the Smart decks header in the
Albums hub: it should take him to an All Albums screen, with the
app's design and theme consistency kept. In the code the text
was a plain `Text` — not tappable at all (decks_view.dart,
`_SmartDecksSection`). The work is Part B of
`~/workspace/cleanup-teardown/ENUMERATION_PARITY_PLAN.md`.

## Decision

1. **See-all is a real target.** The header text keeps its exact
   style and gains an InkWell with the 48dp hit area design.md
   §9 requires, navigating to the new named route `/albums`
   (DecksController.openAllAlbums, beside openDeck/openMonth).

2. **The screen lives in the decks feature**
   (binding/albums_binding.dart, controller/albums_controller
   .dart, view/albums_view.dart). The hub, the duplicates screen
   and the smart-deck screen — the three surfaces this one sits
   between — already live there with the same
   binding/controller/view shape; a top-level `features/albums/`
   would be the only feature whose sole caller and data live in
   another feature. Cross-feature data still travels by route
   arguments only.

3. **Data: the media service's own album list.**
   `MediaService.getAlbums()` — the same call the Clean deck's
   filter and the smart deck's album picker load — so this
   screen can never disagree with the rest of the app about
   what an album is. Covers are each album's latest asset:
   `getAssets(albumId:, page: 0, pageSize: 1)` (the service's
   order is newest first), rendered through the shared
   ThumbnailService at the hub's 320px cover size — the month
   covers' pattern, sharing their cache. Covers resolve after
   the list lands, so rows paint first and covers pop in.

4. **States mirror the hub's, verbatim.** Loading = skeleton
   rows in the real rows' shape (the app's standing loading
   choice); denied = the hub's denied EmptyView (same strings,
   Allow-access retry + Open-settings secondary); a failed list
   = ErrorView with retry; an empty library = the hub's empty
   EmptyView. The permission/init flow copies
   DecksController.init's shape (denial and failure never
   present as loaded).

5. **Album tap launches the existing swipe flow — no new
   viewer.** The launch is a `SmartDeckLaunch` on the
   `/smart-deck` route, the hub's own launch pattern (smart
   decks carry a prepared list; the timeline month launch
   already passes `deckId: null`). The album's assets are its
   full list through the media service's album query, paged at
   the Clean deck's page size until a short page — the
   established album path (the Clean deck's album filter pages
   the same query); resolving from the hub's in-memory scan was
   rejected because the albums screen must stand on its own
   route, independent of the hub controller's lifetime.
   Rejected alternatives: (a) extending the Clean deck with a
   preset album filter — the Clean deck is the shell's home
   tab with a permanent controller, not a pushable route, and
   its filter is an in-place user choice, not a launch;
   (b) a new album photo-grid screen — no such screen exists in
   the app and the owner asked for consistency, not a new
   surface (parked for the owner in the plan: if he meant a
   grid, this decision is the one to revisit).

6. **Session key `smart:album:<bucketId>`, title = the album
   name.** The launch model's existing `customSessionKey`
   carries the key: unique per album, so resume works per
   album, and inside the `smart:` family, so delete marks flow
   to Review and the shell Trash-tab union exactly like every
   smart deck's (review_union.dart's prefix rule, ADR-015) —
   unlike the Duplicates session, which sits outside the union
   by its own older design. The screen title comes from a new
   optional `SmartDeckLaunch.customTitle`, read by
   SmartDeckView only when there is no deckId; the month
   launch (customTitle null) keeps the generic title it has
   always shown. A failed launch preparation stays on the list
   with the reason in an ErrorBanner (the Settings pattern);
   it never navigates to a half-loaded deck.

7. **Presentation follows the album-row precedent.** Rows are
   the album picker sheet's rows (name, count, divider
   separation) with the hub-style cover in place of the
   picker's icon; tokens only, flat, Inter. The one deliberate
   deviation from design.md §6's general list-row line
   (dividers between groups only): album rows keep the
   picker's per-row dividers, because the picker is the app's
   album-row precedent and the plan's cited evidence.

## Limits

- Album contents are resolved at tap time from the media
  service; a library changed while the list is open refreshes
  on the next visit (the screen has no library-change
  subscription — the hub owns reconciliation, Phase 4.4).
- The 'all' pseudo-album (Recent) is listed and launchable
  like any album, matching getAlbums() consumers elsewhere
  (the deck filter treats it as the whole library too).
