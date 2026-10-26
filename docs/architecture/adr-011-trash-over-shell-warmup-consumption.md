# ADR-011 — Trash screen over the shell; warm-up page consumed once

Date: 2026-10-26. Owner report, device-verified: (1) photos deleted
in Review reappear in the Clean deck as if never deleted; (2) any
switch involving the Trash tab still feels like a rebuild, while
Clean↔Decks↔Settings are smooth. ADR-009 fixed the Review leg of
(2); this record fixes what was left.

## Finding 1: a rebuilt deck reuses the stale warmed page

The deck warm-up (splash) fetches page 0 once and the service is
permanent. The deck controller's "single-use" guard was per
controller instance (`_warmUpUsed`), so every NEW deck controller
— e.g. after the shell was recreated — consumed the same page
warmed at splash, before any trash run. Trashed photos are hidden
from MediaStore, so a fresh fetch never returns them — but the
warmed page still contains them. Review's delete clears their
session marks, so on the rebuilt deck `firstUndecidedIndex` lands
on them and they reappear as undecided, sitting to be swiped
again. The denied-confirmation rewind (requirements §5) is the
same code path but correct there: denied photos are still in
MediaStore, so re-showing them is intended.

## Decision 1: warm-up page consumed app-wide

`DeckWarmUpImpl.firstPage` hands its page out on the first read
only; later reads return null and the deck falls back to a fresh
fetch. The "single-use by design" doc now means app-wide, not
per controller. No other reader exists (only the deck reads
`firstPage`), and a consumed-but-unused page is harmless because
the fallback is always a fresh fetch. The permission future is
unchanged (the deck re-checks permission on every resume).

## Finding 2: Trash-screen exits still destroyed the shell

ADR-009 kept the shell alive for Review trips, but the Trash
screen still reset the stack on every exit: its bottom nav and
its controller's `goToDeck` both used `offAllNamed(deck)`, and
Review's post-delete navigation also used `offAllNamed(trash)`.
So the exact flow the owner reported — Review → Delete → Trash
screen → back to Clean — destroyed the shell and rebuilt every
tab (deck re-warm, hub re-scan), which is the rebuild feel that
survived ADR-009. The pre-shell rationale ("never Get.back into
a stale deck controller") no longer applies: the shell's deck
controller is retained, not stale.

## Decision 2: Trash screen pushes over the shell, pops back

- Review's post-delete and denied view-trash navigations now
  push the Trash screen (`Get.toNamed`) instead of resetting.
  Review's AppBar trash button already pushed; all three paths
  are now consistent.
- Trash exits mirror Review's ADR-009 rule: `goToDeck` /
  `goToShellTab` select the tab and pop every route above the
  shell (Trash and any Review beneath it) when the shell is
  alive, and keep the old stack reset for standalone Trash. The
  pop is a bounded loop (max 5) that falls back to the reset if
  the shell route is never reached, so a stack without the shell
  can never be popped past its bottom.
- Trash's AppBar back now always means "back to deck" (its
  tooltip already said so): the old pop-one-route behaviour
  landed on an empty Review behind the Trash screen, which
  contradicted the button's promise.

## What does not change

- Review stays fresh on every open (ADR-009's stale-set guard).
  The Trash tab's content is still freshly built per visit; what
  is gone is the destruction of the tabs underneath it.
- The denied-confirmation rewind, the protection exclusion, and
  the trust rules (requirements §4) are untouched.
- The retained deck underneath Trash is stale by one refresh
  after a restore/empty until the next page-0 refresh (app
  resume or library-change event), the same staleness class the
  deck already tolerates for background library changes.
- Commented-out UI stays untouched.

## Verification

- New unit test: warmed page reads once, second read is null.
- New widget tests: Trash nav taps pop to the shell deck when a
  shell is registered, and fall back to the stack reset without
  one.
- `flutter analyze` clean; full `flutter test` green except the
  known pre-existing Review empty-state failure (baseline
  exception, intentionally-commented CTA, never restored).
- Device check still owed by the owner (this VM has no Android
  SDK): delete in Review → Trash screen → Clean tab must keep
  the deck's place with no trashed photo reappearing, and
  Decks↔Trash↔Clean switches must feel like the other tabs.
