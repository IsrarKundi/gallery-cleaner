# ADR-009 — Shell survives the Trash round-trip (no rebuild on Decks↔Trash)

Date: 2026-10-26. Owner report: the screen rebuilds when switching
between Decks and Trash on the bottom nav.

## Finding (verified in code, not just symptoms)

The Phase 7.1 shell retains Clean/Decks/Settings in an IndexedStack,
so switches among those three never rebuild. But Trash was deliberately
left outside the shell, and BOTH legs of a Decks↔Trash round-trip used
`Get.offAllNamed`, which destroys every route — including the shell:

1. Decks → Trash: `ShellController._openReview` called
   `Get.offAllNamed(review)`. The shell route was removed, so
   `ShellBinding`'s controllers (deck, hub, settings) were disposed.
2. Trash → Decks: Review's bottom nav called
   `Get.offAllNamed(deck, arguments: index)`. A brand-new shell was
   built via `ShellBinding`: new deck controller (deck re-warm),
   new hub controller (lists rebuilt, scan re-subscribed).

So every round-trip destroyed and recreated the whole shell. The
IndexedStack retention never got a chance to help, because the shell
itself was gone. The pre-7.1 reason for off-all ("never Get.back into
a stale deck controller") no longer applies: the shell's deck
controller is retained, not stale.

## Decision

- The shell's Trash action pushes a fresh Review route on top of the
  retained shell (`Get.toNamed`) instead of off-all. Review is still
  fresh on every open (a new binding runs each time), so it cannot
  show a stale delete set. A second Trash tap while Review is already
  on top is a no-op (double-tap guard on the current route), so
  Review can never stack twice. The settled-review gate is unchanged.
- Review's exits back to the shell pop instead of resetting:
  `ReviewController.goToDeck` selects the deck tab and pops, and the
  new `ReviewController.goToShellTab` selects the tapped tab and pops.
  Destinations match the old resets exactly — only the rebuild goes
  away. `ReviewController` imports `ShellController` under a
  documented composition exception (mirroring the shell's existing
  `DeckController` import): it only asks the shell to select a tab
  when the shell is alive underneath it, and owns no shell state.
- Standalone Review (no shell underneath: tests, deep links) keeps
  the old stack reset, so no entry point loses its way home.
- Deliberately UNCHANGED: the post-delete path Review → Trash screen
  (stack reset) and the Trash screen's own returns. After a delete
  the data changed, so fresh state there is correct — rebuilding
  after a delete is not the reported bug, and touching it could
  reintroduce stale-deck behaviour (see the warm-up re-join
  observation: a fresh deck controller re-joining warmed page 0).

## What does not change

- Nav destinations, labels, trust flow (mark → review → native
  confirmation → 30-day Trash), and the settled-review gate.
- `requirements.md` / `design.md`: neither states an off-all
  navigation rule, so no product rule changes and neither file is
  edited. The behaviour change (retention across Trash trips) is
  recorded here instead.
- Commented-out UI stays untouched.

## Verification

- New widget test `Trash round-trip keeps the shell and its tabs
  alive` (shell_test.dart): Decks → Trash → Decks → Trash → Clean
  keeps the identical `ShellController`, `DeckController` and
  `DecksController` instances, with no new media/permission calls.
- Existing shell tests updated only where a comment described the
  old behaviour ("a fresh shell restores the session"); their
  assertions still pass under retention.
- `flutter analyze` clean; full `flutter test` green except the
  known pre-existing Review empty-state failure (baseline
  exception, intentionally-commented CTA, never restored).
- Device check still owed by the owner (this VM has no Android
  SDK): on a phone, Decks → Trash → Decks must show the hub
  instantly with scroll position kept, and the deck tab must keep
  its queue and marks.
