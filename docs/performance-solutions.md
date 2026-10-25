# Klara — Performance Solutions: Phased Implementation Plan

**Fixes the issues in:** `docs/performance-issues.md` (finding numbers `F-…`
below refer to that file). **Source audit:** the owner's trusted report,
25 Oct 2026, audited revision `c55301d`. **Status:** plan only. No code
change is authorised by this file alone — each phase starts only on the
owner's word, one phase at a time, in order.

## How the implementing agent MUST work

1. **One phase at a time, in order, gates enforced.** Finish a phase, prove
   its gate, report the scoreboard, and stop. If a gate fails, stop and
   report — never start the next phase over a failed gate, never silently
   shrink a gate to make it pass.
2. **AGENTS.md compliance is part of every gate.** Authority order
   `requirements.md` → `design.md` → `AGENTS.md`; conflicts are reported,
   never silently resolved. `flutter analyze` clean, `dart format` applied,
   `flutter test` at or above the 292/293 baseline **plus** the phase's new
   tests. Every hand-written Dart file under ~400 lines. Tokens only (no raw
   colours, font sizes, or magic layout numbers in feature code). Every
   user-visible string via `app_strings.dart` keys. Views stay dumb (layout
   + Obx only); controllers use service interfaces; only service
   implementations import platform/storage SDKs. Errors reach the UI as
   `Result<T>` state, never raw exceptions. No `Get.put` in `build()`,
   no `Navigator.push` (named routes only), snackbars/dialogs only via the
   `AppSnackbar` / `AppDialog` helpers. Commit format:
   `<phase>-<task>: <summary> (requirements §n / design §n)`.
   If behaviour or visuals change, update `requirements.md` /
   `design.md` in the same change.
3. **Trust flow is invariant in every phase.** Mark-only swipes → Review →
   Android native confirmation → 30-day Trash → restore. No auto-delete.
   Never claim space "freed" or "permanent" while restore exists. No new
   permission, especially never `MANAGE_EXTERNAL_STORAGE`. No photo content
   logged, stored in analytics, or sent anywhere: on-device only. Partial
   access stays honest: work on exactly the granted photos and say so.
   Denied native confirmation returns photos to the deck with an
   explanation. No dead buttons or placeholder actions ship.
4. **Never restore commented-out code or UI removed on purpose.** The
   deck meter, decks scanning banner/header, labelled four-action bar,
   and Review empty-state CTA stay as they are (see issues file,
   "Explicitly excluded"). Do not re-raise them. Do not "fix" the one
   baseline test failure by restoring UI — baseline parity is 292/293.
5. **Human-only steps are checklists, never guesses.** Play account,
   "Klara" name verification, keystore/signing ownership, pressing Submit:
   stop at them and list them for the owner. Never commit a secret,
   keystore, or real `.env` value. Never hard-code prices (monetization
   is deferred; prices come from the store at runtime when it lands).
6. **Genuinely unspecified decisions:** pick the option that is (a) simpler,
   (b) cheaper to run, (c) more private — in that order — and record it
   as an ADR in `docs/architecture/`. Product decisions listed in §"Decisions
   needed" must be asked, not invented.
7. **No timing is claimed without a device measurement.** Phase 0 baselines
   are the only numbers any later phase may compare against. Debug-only
   timing instrumentation is temporary and is removed before any release
   candidate.

## Production-ready means (whole-program done criteria)

- Cold start, warm relaunch, tab switches, filter changes, hub first and
  return visits, review fill, duplicates, smart-deck entry, trash
  restore/empty, and compress all behave per their phase gates on a real
  mid-range device, at 500, 5k, and 20k–50k libraries, under full and
  partial access.
- No frame over 16 ms attributable to JSON encode/decode, file writes, or
  thumbnail decode on the UI isolate during swiping or scanning (profile
  timeline, target device).
- Thumbnail memory bounded by configured budgets in a 500-card smart deck
  and a 1,000-item review. No unbounded cache remains.
- Trust-flow regression (§Phase 8) passes in full. No confirmed mark is
  ever lost: not by rapid swiping, not by kill-and-relaunch, not by a
  truncated file.
- Release is one documented command producing an obfuscated AAB with
  explicit shrinking, archived symbols per version, a verified merged
  manifest, verified icon-font subsetting, and per-ABI sizes inside a CI
  budget. The weekly nudge fires, including after reboot.
- `flutter analyze` clean, `flutter test` at or above baseline plus new
  tests, every new/modified Dart file under ~400 lines.

## Phase → issue map

| Phase | Fixes | Effort (audit estimate) |
|-------|-------|-------------------------|
| 0 — Baselines | Evidence questions H-01…H-06, L-05, L-06; answers issues-file §"Open questions" 8–13 | Device work, no product code |
| 1 — Quick wins | F-21 (slider part), F-33, F-31, F-06 (dir cache part), F-16 (format/quality part), F-17 (bounds part), F-34/F-35 (config part) | S, low risk |
| 2 — Startup & media | F-01, F-02, F-03, F-04, F-05, F-13 (entity cache part), F-19 (correctness, pulled forward), F-27 | M, low–medium risk |
| 3 — Swipe feel & Review | F-15, F-16, F-17, F-18, F-24, F-25, F-28, F-37 | M, low–medium risk |
| 4 — Storage Stage 1 & scan ownership | F-06, F-07, F-08, F-09 (mitigated), F-10, F-36, F-22, F-23, F-30, F-39 | M, medium risk |
| 5 — CPU off UI isolate | F-20, F-21, F-12, F-11 | M–L, medium risk |
| 6 — Storage Stage 2 (SQLite) | F-07, F-09 (final), F-11, F-12 — conditional on Phase 0/4 evidence | M–L, medium risk |
| 7 — Navigation shell & release finish | F-26, F-37 (remainder), F-34, F-35, dependency diet | L (shell), S–M (rest) |
| 8 — Production gate | Whole-program verification, release checklist, sign-off | Gate, not a feature |

## Phase 0 — Baselines (before any product code changes)

**Objective:** convert hypotheses into numbers and answer the evidence
questions, so later phases are judged against reality, not estimates.
**Scope:** temporary debug-only timing instrumentation + one real release
AAB inspection. No product behaviour changes.

**Steps:**
0.1 Set up an SDK machine + a real mid-range Android device and a large
library (20k–50k photos, or a mocked library clearly labelled as such).
Build in **profile mode** (`flutter run --profile`) — never debug — for
all measurements; debug timings lie.
0.2 Record, 10× force-stop → launch, median: timestamps for `runApp`,
splash complete, `DeckStatus.ready`, first thumbnail painted, and
time-to-first-swipeable-card (TTFD). Per-step timestamps inside
`_loadFilterData` (albums, meter refresh, tutorial flag, session, page 0,
snooze restore, protection). DevTools timeline + memory; Vitals TTID/TTFD.
0.3 Record the same for: warm relaunch; tab round-trip ×5 (Clean → Decks
→ Clean); filter change; hub first visit vs return visit; review fill at
200 and 1,000 marks; duplicates entry; smart-deck entry; trash
restore/empty; compress entry.
0.4 Storage synthetic benchmarks (via the directory-resolver seam, host
fixtures at 10k/50k): bytes written for 1,000 saves, total bytes for a
1,000-page analyses sequence, Stopwatch decode/encode at 50k.
0.5 Counting fakes asserting platform-call counts: path-list calls per
(album, filter) change; `fromId` calls per thumbnail on cache hit;
duplicate `getThumbnail` calls per id; unique (id, size) pairs across a
hub build.
0.6 First release AAB + artefact inspection: merged manifest diff
(including whether `READ_MEDIA_VISUAL_USER_SELECTED` is present),
mapping/resources presence, shipped font sizes (Phosphor tree-shaking
check), per-ABI sizes, plugin list (confirm IntegrationTestPlugin
excluded). Record the canonical release command used.
0.7 One on-device comparison for the sideways deck photo: original
orientation vs EXIF handling in thumbnail rendering.
0.8 Record real thumbnail byte sizes and failure rates; record whether
the Glide layer caches repeat thumbnails for the same id/size (this
settles how much of F-13/F-14 a shared service must solve itself).
0.9 Write the results into `docs/architecture/` as a baseline ADR.
**Explicitly state which hypotheses are now answered and which remain.**

**Edge cases:** profile build behaves differently from release (note it);
mocked libraries must be labelled wherever quoted; a single device is
not an OEM survey — record device, Android version, grant type (full vs
partial), and library size with every number.
**Tests:** none new (benchmarks are scripts/fixtures, not shipped code).
**Acceptance / gate:** a baseline ADR exists with medians for every
scenario in 0.2–0.3, the AAB inspection in 0.6, and answers (or explicit
"still unknown") for evidence questions 8–13. If Phase 0 cannot run (no
device/SDK available), STOP and report: later phases may not start on
guessed numbers.

## Phase 1 — Quick independent wins (any order, all S, low risk)

**Objective:** bank safe improvements and one functional fix without
touching architecture. Each item is independently verifiable.
**Fixes:** F-21 (slider), F-33, F-31, F-06 (dir cache), F-16 (format),
F-17 (bounds), F-34/F-35 (config scaffolding only).

1.1 **Duplicates slider regroups on release, not on every tick.**
`onChanged` → `onChangeEnd`, or a 150–250 ms debounce. Acceptance: a
slider sweep produces exactly one regroup per release; groups identical
before/after (hash determinism guard test).
1.2 **Notification receivers.** Add the plugin-required scheduled
receivers + `RECEIVE_BOOT_COMPLETED` to the manifest, exactly as the
plugin README specifies. Acceptance: weekly nudge schedules, survives
reboot on device, and fires in a smoke test (Phase 8 re-verifies).
1.3 **Remove `cupertino_icons`.** Zero imports/usages; it is also the only
outdated direct dependency. Acceptance: `flutter analyze` clean,
`flutter pub outdated` no longer lists it, no size regression.
1.4 **Cache the documents directory.** Resolve once, reuse everywhere
(includes the retention-load and scanner paths). Acceptance: directory
resolutions per cold start = 1 (counting fake).
1.5 **Explicit thumbnail format/quality in the single `getThumbnail`
funnel.** Display quality q80–90 (not implicit q100); analysis size stays
separate and lower. Acceptance: byte sizes recorded before/after on
device; no visible quality regression at deck card size (owner's eyes
on device, per the standing rule that nothing is good until he confirms).
1.6 **Decode-size limits at all 8 `Image.memory` sites.**
`cacheWidth`/`cacheHeight` (or `ResizeImage`) at layout × DPR per surface
(see Phase 3 for the two standard sizes). Acceptance: decoded memory per
card/grid tile drops; no softness regression at 3× DPR (owner check).
1.7 **Startup hygiene.** `lazyPut(fenix: true)` for Video, Storage,
Share, Notification, AppInfo services; defer `PackageInfo` to the
Settings screen; apply the persisted theme before leaving the splash.
Acceptance: cold-start step timestamps show the pointless platform call
gone; no behaviour change on any screen.
1.8 **Bound SmartDeck and Duplicates thumbnail caches.** Same bound
policy as the deck cache (count + byte budget, LRU — see Phase 3 for the
shared policy; this step only caps the existing maps, it does not build
the shared service). Acceptance: cache sizes stay within budget in a
500-card smart deck and a full duplicates pass.
1.9 **Release config, explicit.** `isMinifyEnabled` / `isShrinkResources`
declared in the release build type; a reviewed `proguard-rules.pro`
validated against the native plugins; canonical release command
documented (AAB; `--obfuscate --split-debug-info=build/symbols/<version>/`;
symbols archived per version, out of git). Acceptance: release build
output identical in shrinking behaviour when built twice; command
documented in `docs/architecture/` (signing itself stays a human-only
checklist — see §Decisions needed).

**Edge cases (whole phase):** removing a dependency must not break a
transitive import (check `flutter pub deps`); manifest receivers must
not change the permission set; theme-before-splash must not flash the
wrong theme on first run (no persisted choice yet = system theme).
**Tests:** new tests for 1.1 (one regroup per release), 1.4 (single
resolution), 1.8 (cache bound enforced). Existing tests must stay green.
**Gate:** analyze clean, tests ≥ baseline + new tests, each item's
acceptance above demonstrated (device numbers where the item claims a
device effect, otherwise counting fakes / artefact checks).

## Phase 2 — Startup & media pipeline

**Objective:** first card fast, and Review correct. **Fixes:** F-01, F-02,
F-03, F-04, F-05, F-13 (entity cache part), F-19, F-27.

2.1 **Media-service query pattern.** Cache `AssetPathEntity` by
(album, type, filter); count once per path; parallelise `assetCountAsync`
with bounded `Future.wait`; defer `fileSize` — a page returns immediately
and size is resolved lazily for the current card / review, or in bounded
parallel (8–16) where a list genuinely needs it. Acceptance: path-list
calls = 1 per (album, filter) change (counting fake); page latency
improves on the Phase 0 baseline at 50k; fast-swiper test (swipe past the
10-card trigger repeatedly) never shows an end-of-queue spinner.
2.2 **Staged ready-gate + splash overlap + reduced-motion fix.** Critical
path to `ready` = permission + `loadSession` + page 0 + `restoreSession`
only. Albums load lazily when the filter sheet opens; tutorial flag
reads in parallel; protection loads in parallel and is awaited only by
the first delete-mark attempt. Deck warm-up starts during the splash
(splash animation itself is NOT shortened — design §13 rule unchanged);
navigation awaits the already-running init. Reduced-motion splash exits
on a short hold, not the 3.0 s timer. Acceptance: TTFD improves by at
least the splash duration vs the Phase 0 median on the same device and
library; reduced-motion cold start no longer pays 3.0 s; filter changes
reload session + page only (no albums/meter/tutorial re-reads).
2.3 **Shared thumbnail service (foundation).** One service owns:
entity cache populated by `getAssets` (skip `fromId` on hit); one byte
LRU keyed (id, size) shared by all screens; in-flight `Future` dedup
registered synchronously (check-then-await bug gone); cancellation when
the window slides; one retry for a failed thumbnail (then a placeholder
that retries on next appearance, never terminal for the session — F-39).
Hub previews become stateless consumers of this service (no per-widget
fetching in `initState`). Acceptance: counting fakes show `fromId` = 0
on cache hit, duplicate `getThumbnail` = 1 per id, unique (id, size)
across a hub build with no duplicates; swipe-burst test issues no
duplicate fetches.
2.4 **Review correctness fix (pulled forward — do not defer).**
`loadDeleteMarkedAssets` must resolve ALL delete-marked ids (id-targeted
via the Phase 2.3 service; paginate-until-found is an acceptable stopgap
only if id-targeted resolution is genuinely blocked, and that must be
reported). Acceptance: regression test with delete marks beyond the
newest 50 assets — all present when Review opens from the bottom nav
without arguments; route-argument path unchanged and still correct.
2.5 **First-card readiness (F-27).** The first card becomes interactive
only when its thumbnail is visible — never swipeable behind a spinner.
Implement via the staged gate + Phase 3's pre-decode; if the thumbnail
fails, the card shows the failure state and is not markable until a
visible photo (or explicit retry) exists. Acceptance: widget test —
spinner state accepts no mark gesture; trust-flow regression passes.

**Edge cases:** permission denied mid-flow (deck shows the denied state,
no crash, no partial queue); partial access granted then expanded
mid-session (visible set grows correctly, marks preserved); albums with
zero assets; filter sheet opened before albums load (shows loading, then
correct lists); `fileSize` lazily unresolved for a card that is swiped
away before resolution (no leak, no crash); session restore referencing
assets no longer in the library (skipped gracefully, session not
corrupted); thumbnail service cancellation racing a late completion
(stale bytes never paint into a recycled slot).
**Tests:** counting-fake tests for 2.1/2.3; widget tests for 2.2 (staged
gate order), 2.4 (beyond-50 regression), 2.5 (spinner not markable);
controller tests for session restore with missing assets.
**Gate:** analyze clean, tests ≥ baseline + new tests, Phase 0 startup
scenarios re-measured and improved (or neutral with a documented reason),
trust-flow regression green.

## Phase 3 — Swipe feel & Review

**Objective:** swiping never waits on fetch/decode, and Review scales.
**Fixes:** F-15, F-16, F-17, F-18, F-24, F-25, F-28, F-37.

3.1 **Card stack + pre-decode + per-surface sizes.** Render current +
next 1–2 pre-decoded underneath + previous warm for undo (gapless
playback on slot swaps). `precacheImage` next 1–2 during idle/animation.
Two standard decode sizes: grid ~256–320 px, deck card = card width ×
DPR capped ~1080 px (A/B sharpness on device at 3× DPR — see decisions).
Tune the framework image cache to the budget; keep the deck's 64-entry
policy only until the shared byte budget (2.3) replaces it. Acceptance:
20-swipe DevTools timeline shows no UI-isolate decode for the next card
at swipe time; no blank flash between cards; fast-swiper test (Phase 2)
still clean; memory within budget.
3.2 **SwipeCard mechanics.** Plain `Transform.translate` while dragging
(no implicit animation); on release, one `AnimationController`/tween on
the design §8 motion ladder, opacity faded over the same tween; avoid a
whole-card rebuild per pan (drag state local to the card, image/clip
stable). Directional feedback before the 80 px threshold per the
existing docstring (edge labels highlight with drag — labels themselves
are mandatory persistent UI, unchanged). Acceptance: drag follows the
finger 1:1 (profile timeline, no interpolation lag); exit is one visible
animation; no dead pause between cards.
3.3 **Review concurrency, observer split, aggregates, placeholders,
blur.** Bounded-concurrency (~6–8) or visibility-based thumbnails reusing
the deck cache (no whole-set sequential fetch, no below-fold eager
fetch). Split the giant `Obx`: per-tile observers; aggregates (totals,
document-like items) computed once per items-change in the controller;
regexes hoisted to static constants. Static placeholders (no per-tile
shimmer). Blur filter cached per tile; longer term, a pre-blurred small
variant (only if profiling shows it is needed — do not build it on
speculation). Acceptance: 1,000-item review reaches interaction with
rebuild counts an order below the Phase 0 profile; unmark ×20 shows no
flicker cascade; blurred scroll profiled clean.
3.4 **Small confirmed costs (F-37, non-cosmetic).** Cache the text-style
set (no new set per access); filter sheet → `ListView.builder`;
duplicate group card previews capped; `ValueKey(id)` on Review/Trash
items; `didUpdateWidget` on the fanned card; Trash arrival: one feedback
surface per frame (snackbar OR modal, not both queued); compress: one
snackbar (second must not hide the first). Acceptance: widget tests for
keys and fanned-card updates; no double-feedback repro in manual pass.

**Edge cases:** undo after a fast multi-swipe restores the exact previous
card and its marks; card stack with a single remaining photo; review
grid with 0, 1, and 1,000+ items; review opened from bottom nav vs route
arguments (both paths, same list); private blur toggled mid-scroll;
orientation/text-scale 0.85–1.30 (accessibility bounds) on the new stack.
**Tests:** widget tests for stack rendering, drag 1:1 (no
`AnimatedContainer` in the drag path), per-tile observer scope, keyed
items, fanned-card update; controller tests for bounded concurrency.
**Gate:** analyze clean, tests ≥ baseline + new tests, swipe + review
scenarios re-measured vs Phase 0, trust-flow regression green.

## Phase 4 — Storage Stage 1 & scan ownership

**Objective:** stop paying O(N) per swipe and stop rescanning the world.
**Fixes:** F-06, F-07, F-08, F-09 (mitigated), F-10, F-36, F-22, F-23,
F-30, F-39.

4.1 **JSON layer in place (Stage 1 — the final state is Phase 6, this
stage must still be correct).** Cache the decoded state in memory (load
once, serve from memory); serialise writes per file with a future chain
(no concurrent read-modify-write); coalesce session saves (flush at most
every ~1–2 s or ~20 marks, AND synchronously on go-to-review, on filter
change, on app-paused, and on dispose — the flush points are mandatory,
not optional); atomic writes (temp file + flush + rename); per-entry
salvage on corrupt files (a bad entry must not fail the whole file);
batch snooze expiry into one read-modify-write; protection reads from
the shared in-memory snapshot (no fresh full decode per delete run).
Acceptance: bytes written for 1,000 marks ≤ ~2× final sessions size
(synthetic benchmark); rapid-swipe test (500 marks) loses zero marks;
truncated-file fixture salvages every good entry and reports the bad
ones; kill-and-relaunch mid-session loses at most the documented
debounce window (see decisions — the window itself needs the owner's
call before this step ships).
4.2 **ScanRepository: shared, cancellable, incremental-ready.**
One memoised scan future shared by hub, Duplicates, and smart-deck
entry; cancellation wired per page/asset and to `onClose`; in-flight
guard (a second `init`/`retry` while a scan runs either joins or cancels
cleanly — never interleaves writes); lifecycle pause on backgrounding
(resume, don't restart, where safe). No per-page analyses rewrite:
checkpoint roughly every 20 pages plus a final write. Per-asset
determinate progress (running count). Acceptance: hub → Duplicates in
one session pays exactly one scan (counting fake); cancel within one
page writes nothing further; leave-and-return neither restarts nor
duplicates; retry-during-scan race test (L-07) passes.
4.3 **Hub reactivity at page frequency.** `onPage` passes only fresh
analyses (no cumulative-map copy); deck membership assigned once per
page; timeline totals/years/grouping precomputed incrementally (the
Phase 3B pattern, carried through) — nothing O(N) in `build()`; delete
the dead full-bytes fold. Duplicates slider already fixed in Phase 1;
grouping stays synchronous here and moves off-isolate in Phase 5.
Acceptance: hub rebuild cost per page is O(page), profiled; 50k scan
profile shows no per-page O(N) spike.
4.4 **Lifecycle & permission freshness.** One `WidgetsBindingObserver`:
on resume, re-check permission if denied/limited; use the photo_manager
change notification, or mark the queue dirty for a cheap page-0 refresh
that preserves marks and session; pause preload/scan on background (with
4.2). Never persist permission state — re-check on resume (Android 14
rule). Acceptance: deny → Settings → grant → return works with no
manual tap; add/delete a photo in another app → resume reflects it
without relaunch and without losing marks; revoke mid-session is honest
(visible set shrinks, explanation shown).

**Edge cases:** kill during a coalesced window (documented loss bound
only); kill mid-atomic-rename (old or new file intact, never truncated);
corrupt sessions file with a valid trash file (trash unaffected, sessions
salvaged per entry); scan cancelled exactly at a checkpoint boundary;
scan result arriving after the user left the hub (dropped, no stale
write); permission revoked while a scan runs (scan stops, error state,
no crash); snooze expiring while the app is backgrounded (applied once,
on next foreground, in one write).
**Tests:** persistence tests — concurrent-write serialisation, coalesce
+ flush points, atomicity (kill simulation via fixture), per-entry
salvage, snooze batching; scan tests — shared future, cancellation,
in-flight guard, leave/return; lifecycle tests — resume permission
re-check, dirty-queue refresh preserving marks.
**Gate:** analyze clean, tests ≥ baseline + new tests, storage synthetic
benchmarks + scan scenarios re-measured vs Phase 0, trust-flow
regression green (including the truncated-file and kill-relaunch cases).

## Phase 5 — CPU off the UI isolate

**Objective:** no analysis, grouping, or large encode/decode on the UI
thread. **Fixes:** F-20, F-21, F-12, F-11.

5.1 **Analysis isolate per page-batch.** Long-lived worker or
`Isolate.run` per page-batch (never per photo — spawn/copy overhead
would exceed the saving); `TransferableTypedData` for bytes. First,
eliminate `package:image` decode wherever the platform thumbnail already
suffices (MediaStore generates thumbnails natively); only genuinely
per-pixel work goes to the isolate, with a single resize for both grid
sizes. Bounded-parallel thumbnail fetch feeding the isolate. Isolate
errors degrade per asset (that asset is skipped/retried) — never fail a
scan or a swipe. Acceptance: scan timeline shows zero UI-isolate decode
or per-pixel work; first-scan time improves on the Phase 0 baseline at
the same library size; per-asset failure test passes.
5.2 **Grouping off-isolate / chunked.** Grouping and bursts sort run on
the worker (or chunked with progress) and never gate `ready` — the hub
shows decks progressively and grouping lands when done. Threshold-0
definition reconciled with `isExactDuplicateOf` (hash AND dimensions,
per the doc) and recorded in an ADR; the reconciliation must not change
which photos are offered for deletion without a trust-flow test proving
it. Acceptance: hub reaches `ready` without waiting for grouping;
slider release regroups off-isolate; group outputs identical to the
pre-change algorithm on a fixture library (determinism guard).
5.3 **Cache version + fingerprint + pruning.** Add a modified-date
field to `MediaAsset` (from the platform entity at mapping time);
analysis cache key becomes (asset id, size, dimensions, modified date,
algorithm version). On scan, stale-fingerprint entries are re-analysed;
entries for assets no longer in the library are pruned. Acceptance:
edited-photo test — edit a photo, rescan, new hash/blur/dark values;
prune test — deleted assets leave no orphan analyses; version-bump test
— old-version entries are re-analysed, never mixed.

**Edge cases:** isolate killed / spawn failure (fallback: degraded
per-asset analysis on the UI thread with a visible "scanning slower"
state, never a hang); huge single asset (memory cap on the batch);
worker returning results out of order (applied by page, never by
arrival); grouping result arriving after the user left Duplicates
(dropped cleanly).
**Tests:** isolate tests (batch correctness, per-asset degradation,
spawn-failure fallback); grouping determinism fixture (5k assets, both
threshold modes); fingerprint/prune/version tests.
**Gate:** analyze clean, tests ≥ baseline + new tests, scan + grouping
scenarios re-measured vs Phase 0, trust-flow regression green.

## Phase 6 — Storage Stage 2: SQLite (conditional — read the gate first)

**Objective:** replace JSON for analyses + sessions (then trash/history)
with a store whose cost is per-row, not per-file. **Fixes:** F-07, F-09
(final), F-11, F-12.
**Gate to enter this phase:** Phase 0/4 evidence confirms the 50k need
(the project's own requirement says expect yes). If the evidence does
not confirm it, record that decision in an ADR, keep Stage 1, and skip
this phase — do not build SQLite on speculation.

6.1 **Schema + repos behind existing interfaces.** Schema keyed by
asset id / filter key; single-row upserts in transactions; batch per
scanner page; indexes on status and create date; WAL mode. Repositories
sit behind the existing service interfaces, so controllers do not change
shape. Drift is the default wrapper; sqflite over an identical schema
is equivalent if the owner rejects codegen (see decisions — ask before
building, do not assume). Settings stays a tiny JSON file (or
preferences) — it is not migrated. Schema versioned from day one.
6.2 **JSON → DB migration with fixture tests for all 7 files.**
One-time import; JSON retained as backup until verified; verification
pass counts rows and spot-checks values; only then may JSON paths for
migrated stores be removed. Acceptance: fixture migration for all 7
files passes byte-for-value; a migrated 50k library opens with indexed
queries (no full-table scan on the hot paths); backup retention verified
before any JSON path is deleted.
6.3 **Remove JSON paths for migrated stores** only after 6.2's
verification. Acceptance: no migrated store reads JSON; analyze clean;
full trust-flow regression green.

**Edge cases:** migration interrupted mid-import (re-runnable, never
half-migrated); a row corrupt in JSON (salvaged per entry, reported,
migration continues); DB file missing on launch (recreated + re-imported
from the JSON backup, not a crash); downgrade after migration (schema
version guard, explicit error, no silent data loss); concurrent
read-while-write during a scanner batch (transactions, no torn reads).
**Tests:** migration fixture tests (all 7 files, corrupt-entry cases,
interrupted-migration rerun); repository tests (upsert, batch, indexed
query plans); backup-retention test.
**Gate:** analyze clean, tests ≥ baseline + new tests, storage benchmarks
re-run (per-row cost demonstrated, not asserted), trust-flow regression
green, migration ADR written.

## Phase 7 — Navigation shell & release finish

**Objective:** tab switches stop being relaunches, and the release
process is explicit. **Fixes:** F-26, F-37 (remainder), F-34, F-35,
dependency diet.

7.1 **Keep-alive shell.** `IndexedStack` (or equivalent) with lazily
built, retained tabs — deck and decks controllers stay alive across tab
switches, and the shared scan (Phase 4) is reused. Review/Trash
off-all-on-return semantics are PRESERVED (their anti-stale intent is
documented; retaining them would reintroduce stale review state).
Acceptance: tab round-trip ×5 performs no re-scan and no deck reload
(counting fakes); Review opened from the bottom nav still shows the
current delete set (F-19 regression test still green); memory stays
within budget with all tabs visited.
7.2 **Dependency-diet decisions (ask first, see decisions).** If video
compression is NOT in the first Play release, remove
`video_compress_advanced` + its route (biggest single diet). If it
ships, keep it + a release smoke test. Replace `package:image` decode
with native `instantiateImageCodec` at analysis size ONLY if Phase 5
did not already eliminate it — outputs must be bit-comparable, guarded
by tests. Optional: replace `package_info_plus` / `disk_space_plus`
with ~15-line Kotlin MethodChannels. Do NOT churn the 14 transitive
upgrades. Acceptance: `--analyze-size` before/after recorded; no
behaviour change; release smoke test green.
7.3 **Baseline Profile + CI budgets.** Baseline Profile for the
cold → deck, swipe ×10, and review-grid journeys. CI (or a documented
manual check, if CI is not available) budgets: per-ABI sizes, shipped
font sizes, merged-manifest diff, mapping/resources presence. Acceptance:
profile journeys show a cold-start improvement vs Phase 0 on the same
device; budgets recorded and enforced on the release candidate.
7.4 **Release finish.** Canonical release command from Phase 1.9 becomes
the ONLY documented way to build release; AAB only for submission,
`--split-per-abi` for QA builds; SDK/NDK pinned explicitly (no silent
inheritance drift); Gradle `-bin` wrapper, `-Xmx2–4G`, caching/parallel
enabled. Acceptance: two consecutive release builds produce the same
shrinking behaviour and artefact set; checklist complete (Phase 8).

**Edge cases:** shell retaining a tab whose permission was revoked
(re-check on resume per Phase 4.4, not stale data); shell memory on
low-end devices (lazy build + budget check — if retention breaches the
budget, retain deck + scan only and document it); route arguments to a
retained tab arriving stale (Review/Trash return semantics cover this —
test it).
**Tests:** shell tests (tab retention, no re-scan, Review freshness);
size tests (`--analyze-size` snapshots); release-checklist dry run.
**Gate:** analyze clean, tests ≥ baseline + new tests, tab scenarios
re-measured vs Phase 0, trust-flow regression green.

## Phase 8 — Production gate (not a feature — the release decision)

**Objective:** prove the whole program, then stop at the human-only
steps. Nothing ships on a phase's word alone; it ships on this gate.

8.1 **Full regression matrix — every scenario, every phase's gate
re-checked on the release candidate:** cold start (large library),
warm/resume, tab round-trip ×5, filter change, hub first/return,
review fill (200 and 1,000), duplicates, smart-deck entry, trash
restore/empty, compress, at 500 / 5k / 20k–50k libraries, full + partial
access, mid-range + (if available) low-end device.
8.2 **Trust-flow regression (non-negotiable, every phase and again
here):** golden path mark → review → native confirmation → Trash →
restore; denied confirmation returns photos with explanation;
three-state accounting correct at every step; restore single + all;
empty Trash with both confirmations; partial-access accounting on the
visible set only. **No performance change ships if any of this regresses.**
8.3 **Robustness cases:** kill-and-relaunch during a scan and mid-session
(no lost confirmed marks, no corrupt JSON/DB); truncated-file / corrupt-
row fixtures (salvage, never whole-file loss); rapid 500-mark swipe
(no lost marks, no end spinner, no blank flash); first scan at scale
(UI scrollable, determinate fine progress, cancel within one page writes
nothing further, leave/return no restart/duplicate, stale-fingerprint
re-analysis); slider sweep (one regroup per release, identical groups);
blurred scroll profiled; reboot smoke (weekly nudge scheduled + fires).
8.4 **Release checklist (human-only items listed, never guessed):**
signing/keystore ownership, split-debug-info archived per version,
merged manifest verified, icon-font subsetting verified, per-ABI sizes
inside budget, Baseline Profile in the AAB, Play account, "Klara" name
verification, pressing Submit. Each item is either done-with-evidence or
explicitly listed for the owner.
8.5 **Docs + sign-off.** `requirements.md` / `design.md` updated for any
behaviour/visual change made along the way (with section citations);
decisions recorded as ADRs; this plan's phase scoreboards attached to
the release record. The owner confirms on his own device before any
submission — per the standing rule, nothing is good until his eyes
confirm it.

## Decisions needed (ask the owner — never invent)

1. Video compression in the first Play release? (Phase 7.2 — biggest
   dependency decision.)
2. Scan staleness policy: a completed scan is reused until when?
   (Phase 4.2 — needed before the shared scan ships.)
3. Storage wrapper for Stage 2: Drift or sqflite? (Phase 6 — ask before
   building.)
4. Debounce durability: is a ~1–2 s / ~20-mark crash window acceptable,
   or must every mark flush to a serialised writer? (Phase 4.1 — the
   flush points in 4.1 are mandatory either way.)
5. Symbols / signing ownership: who holds the keystore and archives
   split-debug-info per version? (Phases 1.9, 7.4, 8.4.)
6. Splash overlap vs design §13: confirm overlapping warm-up (not
   shortening the animation) is accepted, and pick the reduced-motion
   hold. (Phase 2.2.)
7. Deck card thumbnail size at 3× DPR: what size restores sharpness?
   (Phases 2.3, 3.1 — on-device A/B.)
8. Deck screenshot's sideways photo: original orientation or EXIF
   handling? (Phase 0.7 — one comparison.)
9. Albums tab destination (separate open decision, load-bearing for
   performance): smart-deck hub or folders list? Routing Albums to the
   hub re-enters the most expensive screen until the shared scan lands
   — do not assume an answer.

## Explicitly out of scope

- Restoring any commented-out UI (deck meter, scanning banner/header,
  labelled four-action bar, Review empty-state CTA) or disposing of
  dead code on their behalf. Owner decision: they stay as they are.
- GetX replacement / framework rewrite; deferred components / dynamic
  features (a download-size tool for the wrong problem); ObjectBox,
  Hive/hive_ce, or Isar as the main store; removing the splash; any
  change weakening the trust flow; any new permission; any change that
  sends photo content anywhere.
- Churning the 14 transitive dependency upgrades (none are
  performance- or size-critical).
- Any phase started without the owner's word, any gate skipped, any
  timing claimed without a Phase 0 baseline to compare against.
