# ADR-003 — Deck warm-up during the splash (Phase 2.2)

## Decision

The splash animation is NOT shortened (design §13 unchanged). Instead,
a `DeckWarmUp` service, started by the splash binding while the splash
plays, overlaps the deck's critical path — permission, then page 0 for
the All filter — so the deck joins already-running work on first init
instead of starting it after navigation.

## Why this shape

- The deck controller cannot be created early: controllers live only
  in their feature binding, and GetX would dispose a splash-created
  deck controller on the `offAllNamed` navigation to the deck. A
  permanent service in the initial binding survives the navigation.
- The session load and restore stay in the deck. They are local reads
  plus pure mapping (ADR-001: ~2 ms), so warming them would buy
  nothing and would force the service to know the deck's filter key
  (a feature model inside a service). The warm-up therefore covers
  only the two expensive steps: permission and page 0.
- The warmed page is exactly `media.getAssets()` with defaults (page 0,
  the media default page size). `DeckController.pageSize` must stay
  equal to that default (both 50 today); if either side changes, the
  warmed page's "has more" bookkeeping diverges from a fresh page.

## Single-use rule

The deck consumes warmed work on its FIRST init only. A later retry
(e.g. after a denied grant is fixed in Settings) re-requests permission
and re-fetches page 0 fresh, so a stale grant can never survive a
retry. Both warm-up futures always complete (failure reads as null),
so the deck always falls back to its normal path — a warmed page
failure retries as a fresh page 0, a warmed denial reaches the denied
state without re-prompting.

## First-launch consequence (owner-verifiable, not VM-verifiable)

On first launch the permission dialog appears OVER the splash, because
the warm-up requests permission while the splash plays. That is the
intended overlap, not a bug: the user answers once, and the deck never
re-prompts. The device checklist for 2.2 covers confirming the dialog
appears exactly once.

## Staged ready-gate (same change)

Critical path to ready is now ONLY session + page 0 + restore:

- Albums load lazily via `DeckController.ensureAlbums`, called before
  the filter sheet and the album picker open (the picker is the same
  lazy pattern — without it, the add-to-album action would show an
  empty list after this change). Albums refresh on the next deck visit,
  not on filter change.
- The tutorial flag reads in parallel on initial load only (it is a
  global flag, not per filter); the view shows the overlay reactively
  when the flag lands.
- Protection loads in parallel on every load and is awaited ONLY by a
  delete-mark attempt. Other marks never wait. A protection-load
  failure reads as protection OFF, the same default as a settings-load
  failure inside `DeckProtection.load`, so a broken settings read
  never blocks the deck.
- The meter refreshes after ready, without gating it. The meter view
  is reactive, so it picks the values up when they land.

## Reduced-motion splash

No Lottie runs under reduced motion, so the 3.0 s fallback was the
whole wait. The view now notifies the controller once
(`onReducedMotionShown`), which cancels the fallback and completes
after a short 800 ms hold (`AppSizes.splashReducedMotionHold`) — long
enough for the brand mark to register, far below the fallback. Tap
still skips, cancelling the hold.

## What this does NOT change

- The splash animation length, the gesture mapping, the trust flow,
  and every commented-out UI element (meter line, scanning banner,
  labelled action bar, Review empty-state CTA) are untouched.
- No new permission, no auto-delete, no "freed"/"permanent" wording.
