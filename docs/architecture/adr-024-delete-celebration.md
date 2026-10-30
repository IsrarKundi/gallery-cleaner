# ADR-024: The Delete-Moment Celebration (Stage 5 addendum)

## Context

Stage 5 (ADR-020) deliberately left one moment unbuilt: the
~2-second animation Cleanup plays at the exact second a
deletion completes (teardown `notes/delight-assets.md` §3).
Its artwork was the owner's open choice. On 30 Oct 2026 the
owner chose and approved the artwork after watching a rendered
preview: wipe.'s own Lottie of the finish screen's party
popper firing — the popper springs in, palette confetti and
ribbons burst, rain down and fade, and the final frame is the
same resting popper the finish screen shows, so the moment
hands over to that screen. This ADR records how it is wired.

## Decisions

1. **The asset ships byte-identical to the approved file.**
   `delete_celebration_v3.json` from the design workspace
   (30 fps, 60 frames = exactly 2 s, 500×500, transparent,
   vector shapes only, 47.9 KB, verified in the Dart renderer
   — `lottie` 3.6.1 — with zero warnings) ships as
   `app/assets/animations/delete_celebration_lottie.json`,
   SHA-256
   `14d0ddca6a393df27ce4a864337685f167ae12e78046dc85fa95399f1aadf7ce`.
   No new dependency: `lottie: ^3.6.1` was already in the app
   for the splash logo — the same version the asset was
   verified against.

2. **Placement: a short-lived `/celebration` route inserted
   at exactly Stage 5's two hook points.** Both delete
   completions — ReviewView's pure whole-set `deleted` branch
   and the deck view's finish watcher — now navigate to
   `/celebration` with the same FinishSummary argument instead
   of directly to `/finish`. The celebration forwards the
   argument untouched: it pushes `/finish`, and when the
   finish screen pops it removes itself, so the caller's
   navigation future resolves exactly where the direct
   navigation resolved before (in particular the deck watcher
   still presents the session-end swipe ask only after the
   finish visit ends — presentations never overlap the finish
   screen). Counting, marks and the summary itself are
   untouched; the review ask still presents from the finish
   screen as Stage 5 built it.

   Alternatives considered: an overlay inside the finish
   screen (rejected — it would have to gate the delete-place
   ask's post-frame presentation and complicates the finish
   view for a 2 s decoration), and replacing the celebration
   route with `/finish` via `offNamed` (rejected — the
   caller's future would resolve after ~2 s instead of when
   the finish screen is done, breaking the deck watcher's
   ordering above).

3. **The hop can never block or strand the user.** It plays
   once, non-looping. Reduced motion — `MediaQuery
   .disableAnimations`, which main.dart derives from the
   app's reduced-motion setting or the system setting (the
   splash contract) — skips straight to the finish screen.
   A tap or the system back button skips. If the asset fails
   to load or play, the hop forwards immediately. As a final
   guarantee, the controller runs a fallback timer
   (`AppSizes.celebrationFallback`, 3 s — the splash
   hold-timer pattern): if playback neither completes nor
   errors by then, the finish screen opens anyway.

4. **Sizing follows the existing tokens.** The player renders
   at `AppSizes.celebrationAnim` (360): the composition is a
   square canvas with the confetti fan around the popper, so
   the stage is wider than the finish screen's tight-cropped
   `celebrationArt` popper; exact size continuity with the
   static popper was not chased — the burst needs the room.

## Consequences

- Every finish-screen landing now opens with the 2 s moment,
  including the Clean flush path if its trigger is ever
  restored (the watcher hook was already live; ADR-020
  decision 1).
- Requirements §4's Stage 5 amendment and design §6's finish
  bullet note the preceding moment; the finish screen itself
  is unchanged.
