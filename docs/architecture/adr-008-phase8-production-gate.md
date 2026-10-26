# ADR-008 — Phase 8 production gate (host verdict + owner-side record)

Date: 2026-10-26. Program: Klara performance plan, Phases 0–7 implemented
by Muse under the owner's back-to-back order (2026-10-26 ~00:39).
Phase 8 is not a feature — it is the release decision. Nothing in this
record claims a device or release-build result: this VM has no Android
SDK and no device, so everything device- or release-shaped below is
listed for the owner, never asserted.

## Host verdict: PASS (with owner-side items outstanding)

- `flutter analyze`: clean on the final tree.
- Full `flutter test`: **513 pass + 1 failure**. The single failure is
  the known pre-existing Review empty-state test (expects the
  intentionally-commented "Back to deck" CTA). It is a baseline
  exception, not a fix item, and was never restored.
- Trust-flow regression green: the golden-path test
  (mark → review → native confirmation → Trash → restore) passes.
- Tree clean, local == remote == `dc80a3d` before this record
  (plus the two Phase 8 commits below).
- No secrets found by a basic scan of `app/lib`.
- Manifest source permissions: exactly 4 — `READ_MEDIA_IMAGES`,
  `READ_MEDIA_VIDEO`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`.
  The fourth was added by Phase 1.2 for the reboot-surviving weekly
  nudge and is authorized; `MANAGE_EXTERNAL_STORAGE` is absent.
  (The merged manifest itself can only be verified on an SDK machine.)
- Plan docs untouched (`performance-issues.md`,
  `performance-solutions.md`); `requirements.md` / `design.md`
  untouched across Phases 2–7. Phase 8.5 check: no implemented
  behaviour/visual change contradicts them — edge labels now match
  requirements §3, the threshold-0 rule matches the documented exact
  rule, the storage swap is invisible, the shell preserves
  destinations, and design.md states no filter-sheet height rule, so
  the fixed 70% sheet does not contradict it.
- Commented-out UI untouched throughout (deck meter, scanning
  banner/header, labelled four-action bar, Review empty CTA).
- No new permission, no trust-flow weakening, no photo content
  sent or logged anywhere.
- ADRs 001–007 complete; this record is ADR-008.

## Phase 8 gate hygiene fix (caught by this gate, not hidden)

The gate's format check found `compress_controller_test.dart`
unformatted (last touched by Phase 2's 2.4 commit). It was not one of
the 18 pre-existing unformatted test files recorded in Phase 1, so it
was formatted here (whitespace-only line wrapping, 6 tests re-run
green) and pushed as `phase8-format`. No behaviour changed.

## Per-phase scoreboard (final heads, all pushed)

- Phase 0 (9cf9810): baselines, ADR-001. Device median 4,732 ms to
  first thumbnail at ~6k photos (RMX3085, Android 13).
- Phase 1 (fb7bd28): quick wins 1.1–1.9. Tests 307 + 1 known.
- Phase 2 (f2b9c47): staged ready-gate, shared thumbnail service,
  Review beyond-50 fix, first-card readiness. Tests 348 + 1 known.
- Phase 3 (114121f): card stack, swipe mechanics + edge labels,
  Review concurrency, lazy filter sheet. Tests 386 + 1 known.
- Phase 4 (932c5d8): atomic JSON layer, shared scan repository,
  incremental hub timeline, lifecycle handling. Tests 449 + 1 known.
- Phase 5 (5ecbceb): analysis/grouping off-isolate, cache
  fingerprinting + full-scan-only prune. Tests 484 + 1 known.
- Phase 6 (5b8d13a): SQLite/Drift gate (50k decode median 318 ms)
  + schema + migration + serving. Tests 508 + 1 known.
- Phase 7 (dc80a3d): keep-alive shell (closes the Phase 3
  bottom-nav mid-swipe residual), dependency diet (video
  compression kept), Baseline Profile procedure (ADR-007),
  release pins. Tests 513 + 1 known.

## The plan's 9 decisions — final status (nothing invented)

1. Video compression in first Play release? KEPT (Phase 7.2).
   Owner may still overturn; removal needs his explicit word.
2. Scan staleness policy? Memoised scan within session + dirty on
   resume change (ADR-004). Owner may overturn.
3. Storage wrapper? Drift (Phase 6 gate + build).
4. Debounce durability? Phase 4's ~1.5 s window, then GONE for
   migrated stores under SQLite (Phase 6 commits immediately).
5. Symbols / signing ownership? Human-only, owner's.
6. Splash overlap vs design §13? Overlap proceeds (Phase 2.2);
   reduced-motion hold 800 ms.
7. Deck thumbnail size at 3× DPR? 1080 cap implemented (Phase 3.1);
   on-device A/B still owed (owner's eyes).
8. Sideways photo orientation? Still open (Phase 0.7, one
   comparison on device).
9. Albums tab destination? Still open; shell preserves current
   routing and never assumes it.

## Carried residuals and observations (not hidden, not fixed here)

- Phase 2 cancellation token: cancelled thumbnail fetches still run
  natively to completion.
- Smart-deck "window 10/20": meaning undefined in the plan doc;
  needs the owner's confirmation before implementation.
- Warm-up re-join observation (Phase 7, pre-existing, read from
  code, not device-verified): permanent `DeckWarmUp` + a fresh
  `DeckController` re-joining launch-time warmed page 0 can re-show
  since-trashed photos on the Review-return path. Needs the owner's
  word before any fix is attempted.

## Owner-side checklists (the only remaining work)

### On his phone (device checks, Phases 1–7 accumulated)

- Phase 1: weekly nudge schedules, survives reboot, fires; APK size
  vs 33.7 MB profile baseline; no quality regression at deck size;
  no softness at 3× DPR; no theme flash; cache bounds on a 500-card
  smart deck + full duplicates pass.
- Phase 2: fast swipe past the 10-card trigger, no end-of-queue
  spinner; permission dialog exactly once over the splash; same
  photo not visibly re-fetching across deck/review/hub; 60+ delete
  marks all visible in Review from the bottom nav; first card never
  swipes on a spinner, failed card retries on tap.
- Phase 3: next photo with no blank flash, sharp at 3×; card tracks
  the finger, one visible exit flight, edge labels highlight;
  200+ Review fast with no whole-screen flicker; filter sheet at
  70% height and scrollable; duplicate groups over 20 expand fully.
- Phase 4: marks survive background/kill/relaunch; trash records
  intact across kills; Hub→Duplicates→Hub with no re-scan;
  deny→grant→return reloads with no tap; add/delete elsewhere
  reflected with marks intact; revoke mid-session shows denied
  state; background mid-hub-scan continues; snooze expiry fires
  exactly once.
- Phase 5: no jank while swiping during a first large scan;
  "slower than usual" banner (if ever seen) clears at scan end and
  never repeats; hub ready at scan end, Duplicates/Bursts land
  progressively; slider 5→10→5 lands on 5's groups; edited photo
  re-analyses on rescan; deleted photos leave no stale suggestions;
  first rescan after the update takes longer (one-time).
- Phase 6: first launch after update shows all existing data in
  full, JSON backups still on disk; kill/relaunch during migration
  converges with no duplicates; marks survive even inside the old
  1.5 s window.
- Phase 7: tab round-trip ×5 (no reload, no re-scan, marks intact);
  bottom-nav Review shows the current delete set; swipe then
  immediately tap Trash (mark must appear); swipe then immediately
  switch tabs (mark must survive); compress route opens, previews,
  saves.
- Phase 8 matrix (device side): cold start at large library,
  warm/resume, filter change, hub first/return, review fill 200 and
  1,000, duplicates, smart-deck entry, trash restore/empty,
  compress, at 500 / 5k / 20k–50k libraries, full + partial access,
  mid-range + (if available) low-end device; rapid 500-mark swipe;
  kill/relaunch during scan and mid-session; reboot smoke (nudge
  scheduled + fires); trust-flow regression in full (golden path,
  denied confirmation returns photos with explanation, three-state
  accounting, restore single + all, empty Trash with both
  confirmations, partial-access accounting on the visible set only).

### On an SDK machine (release checks, none claimable from this VM)

- Build the pinned config (compile 36, min 24, target 36,
  NDK 28.2.13676358, Gradle wrapper 9.3.1-bin) and confirm it
  builds clean; two consecutive canonical release builds give
  identical shrinking behaviour and artefact set.
- `--analyze-size` breakdown + per-ABI sizes inside budget;
  merged-manifest diff showing only the manifest permissions above
  and never `MANAGE_EXTERNAL_STORAGE`; `build/symbols/<version>/`
  archived; icon-font subsetting verified.
- Confirm the sqlite native library ships in the AAB via
  `--analyze-size`.
- Confirm the KGP-applying-plugins warning stays warning-only.
- Generate the Baseline Profile for the 3 ADR-007 journeys
  (cold→deck, swipe ×10, review-grid), verify it lands in the AAB,
  and show cold-start improvement vs the Phase 0 median (4,732 ms,
  RMX3085) on the same device.
- Signing/keystore ownership, Play account, "Klara" name
  verification, and pressing Submit: human-only, owner's.

## Sign-off

Per the standing rule, nothing is good until the owner's own eyes
confirm it. The code program is complete through Phase 7 and the
host gate passes; submission waits on the owner-side checklists
above and his word.
