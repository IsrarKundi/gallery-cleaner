# Klara — Performance Issues

**Source:** the owner's trusted full-scope performance audit report (25 Oct 2026),
supplied as `klara-performance-audit-report.md`. Finding numbers (`F-01` …)
match that report exactly, so every issue here traces back to it.
**Audited revision:** `c55301d` (remote `IsrarKundi/gallery-cleaner`, local
checkout `~/workspace/swipe-clean`), Flutter 3.47.7, `mobile.klara.app`.

**Companion file:** `docs/performance-solutions.md` — the phased plan fixing the
issues listed here, one phase at a time. This file states problems only.

## How to read this file

- **Status.** `Confirmed` = structural fact visible in code at `c55301d`.
  `Likely` = structure confirmed, magnitude unmeasured. `Hypothesis` = needs
  device evidence (§7), never stated as fact.
- **No timings here are measured.** The audit VM has no Android SDK, Java, or
  device, and no release artefact has ever been produced. Durations are coded
  constants (e.g. the 1.67 s splash) or arithmetic from code constants (e.g.
  page counts at 50,000 photos). Do not quote them as measured results.
- **Scale.** Requirements §7 sets "large-library performance (50,000+ photos)"
  as a Phase 3 target, so 50k arithmetic is the project's own bar.
- **Trust model is not negotiable.** Nothing below permits weakening:
  mark-only swipes → editable Review → Android native confirmation → 30-day
  Trash → restore; three-state accounting (Marked / In Trash until [date] /
  Freed); no auto-delete; no `MANAGE_EXTERNAL_STORAGE`; on-device only;
  Android 14 partial access handled honestly; locked gestures (left = Keep,
  right = Delete, up = Maybe, down = Favourite).

## Explicitly excluded (owner instruction)

These audit items are **not** issues here: the owner states the UI was
disabled on purpose. Do not "fix" them by restoring UI, and do not re-raise
them. (AGENTS.md also forbids restoring commented-out code/UI removed on
purpose.)

- Deck space-meter widget commented out (audit F-02's meter clause, F-29a).
  The meter's *data refresh cost* is still a real issue and stays below as
  wasted work in the load chain — only restoring the meter UI is out.
- Decks scanning banner and hub header commented out (F-29b).
- Labelled four-action bar branch not rendered (F-29c).
- Review empty-state CTA commented out (F-29d). Likely cause of the one
  pre-existing test failure in the baseline below; that failure is a
  baseline exception, not a fix item.
- Dead-code disposition for uncalled widgets (F-29, last part), timeline
  gradient / hero shadow cosmetics (F-37 cosmetic sub-item), theme flash /
  native launch branding polish (F-32, pure visual polish).

## Baselines (host-measured by the audit)

- `flutter analyze`: clean. `flutter test`: 292 pass, 1 pre-existing failure
  (Review empty-state test expects "Back to deck", which the intentionally
  commented CTA does not render). Baseline parity for all future work is
  therefore **292/293**, not 293/293, unless the owner separately decides.
- Dependencies: 15 direct, 104 in the lockfile; all direct deps at latest
  resolvable except `cupertino_icons` (1.0.9 vs 2.0.0, blocked by `^1.0.8`).
  14 transitive upgrades available, none performance- or size-critical.
- App assets total 248 KB (Inter fonts already subsetted, 518 glyphs).
  No release APK/AAB exists in the repo.

## Root causes

Eight root causes account for nearly every issue. Fix the root cause, not
each symptom separately.

| ID | Root cause | In one line |
|----|-----------|-------------|
| RC-A | Serial, uncached platform & file work | Work that could overlap runs in sequence, and repeats every visit. |
| RC-B | Whole-file JSON persistence | Every read/write is O(N); cumulative cost is O(N²). |
| RC-C | No background-execution layer | All CPU work runs on the UI isolate; zero isolates. |
| RC-D | Fragmented thumbnail pipeline | No shared cache, no in-flight dedup, no decode-size limiting, max-quality encoding. |
| RC-E | Reactive updates at data frequency | Coarse observers plus O(N) work inside `build()`. |
| RC-F | Navigation destroys all state | Every tab switch is a cold start. |
| RC-G | No scan ownership | Scans are unshared, uncancellable, non-incremental. |
| RC-H | Release build implicit and unverified | No explicit shrinking, signing, or artefact inspection. |

## Issues

### RC-A — Serial, uncached platform and file work

**F-01 — Splash masks zero work; pure added latency on every cold start.
[Confirmed]** `SplashController` starts only a hold timer and has no service
dependencies. `DeckController` is created only after the splash completes,
so permission, file I/O, and page 0 all begin after the splash ends.
Time-to-first-card is splash + whole deck chain instead of max(splash,
deck chain). Lottie is 1.667 s (3.0 s fallback): ~1.67 s dead time per cold
start before any loading begins. Largest contributor to slow reopening.

**F-02 — Deck ready-gate waits on work the first card does not need.
[Confirmed]** `deck_controller.dart:199-233` (`_loadFilterData`) awaits,
strictly serial: `getAlbums()` (only needed when the filter sheet opens) →
space-meter refresh (trash + history reads) → `isTutorialSeen()` →
`loadSession()` → `_loadPage(0)` → `restoreSession()` →
`protection.load()` (gates only a delete mark, not rendering). The same
full chain re-runs on every `setFilter()`. (Meter UI excluded above; the
issue kept here is the refresh and other filter-independent reads gating
the first card.)

**F-03 — Reduced-motion / Lottie-failure users get the longest splash
(3.0 s). [Confirmed]** `splash_view.dart:86-105`: the reduced-motion branch
never calls the Lottie-finish handler, so the only exits are tap or the
3000 ms timer. Accessibility users are penalised ~1.33 s. A latency issue,
not a styling preference.

**F-04 — Every page re-enumerates all asset paths, then awaits file size
serially per asset. [Confirmed]** `media_service_impl.dart:97-128`:
`getAssets()` calls `getAssetPathList` inside every page call, then
`getAssetListPaged`, then `await entity.fileSize` in a serial loop.
Plugin source verified: one file size = one ContentResolver query per id.
One page = 1 album-list call + 1 paged query + 50 sequential round-trips.
At 50k: 1,000 redundant path-list calls + 50,000 serial size queries.
Page loading triggers at 10 cards remaining, so a fast swiper can outrun
serial page load.

**F-05 — `getAlbums()` is fully sequential, before the first card.
[Confirmed]** One native `assetCountAsync` per album, serial. Also in
`library_scanner.dart:81`, where it is only used for an estimated total.
Cost scales with folder count.

**F-06 — Same JSON files re-read repeatedly before ready; documents
directory re-resolved on every local operation. [Confirmed]** Cold start
reads `klara_settings.json` 3×, `klara_sessions.json` 2×, plus
trash/history/snoozes — ≥ 6 sequential full-file decodes before the first
card. Every local operation calls `_dir()` →
`getApplicationDocumentsDirectory()` via a platform channel, never cached.
The decks hub's retention load is 6 sequential calls, with the scanner's
analysis load as a 7th. Snooze expiry is a serial whole-file
read-modify-write per expired snooze.

**F-36 — Protection checks decode the world. [Confirmed]** Loading all
Klara favourite ids calls `listSessions()` (full decode of all
sessions/marks) to union favourite ids, per delete run. One Trash restore
is ~3 whole-file passes; one blur toggle is 3 settings reads.

**F-31 — Eager permanent services: real but small, plus one pointless
platform call per cold start. [Confirmed]** Service constructors are cheap
and not a major cost. Exception: `SettingsController.init()` awaits
`PackageInfo.fromPlatform()` on every cold start for a version string no
launch screen displays.

**F-18 — Review / compress thumbnails load strictly sequentially for the
whole set, including below-fold items. [Confirmed]**
`review_controller.dart:207-220`: `for (asset) await getThumbnail`. Same
serial pattern in compress (up to 200 videos, after the list loads).

### RC-B — Whole-file JSON persistence

**F-07 — Whole-file read-modify-write for all 20 methods / 7 files,
encode/decode on the UI isolate, no debounce, serialisation, or locking.
[Confirmed]** Every read decodes the entire file; every write re-encodes
and rewrites the entire file. No debounce, per-file write queue, or mutex.

**F-08 — Full sessions rewrite on every mark, unawaited and
unserialised: a correctness risk, not just a cost. [Confirmed]**
`deck_controller.dart:385-395` (`_persist`), called from mark, undo,
clear-delete-marks, filter change, and session restore. Two rapid swipes
produce two concurrent read-modify-write cycles, and the older snapshot
can overwrite the newer one (lost mark). Every Review unmark pays the
same full cycle; N unmarks = N cycles.

**F-09 — Calculated write amplification (arithmetic from confirmed
serialised shapes). [Confirmed arithmetic, not measured]** One mark ≈
21 B; one photo analysis ≈ 131 B (asset id stored twice); one trash entry
≈ 121 B. Sessions at 50k marks ≈ 1.1 MB; analyses at 50k ≈ 6.3 MB.
Cumulative quadratic writes when swiping a whole library: 1k marks ≈
11 MB; 10k ≈ 1.1 GB; 50k ≈ 27.5 GB (plus equal reads, 50k write syscalls).
A first 50k scan rewrites analyses per 50-asset page: 1,000 saves ≈ 3.3 GB
cumulative writes to build a 6.3 MB file, with late-scan saves
synchronously encoding ~50k entries on the UI isolate. Flash wear,
battery, and thermal cost — not just latency.

**F-10 — Writes are non-atomic; one bad entry fails an entire file —
worst for Trash. [Confirmed]** Writes go direct, no temp-file + rename,
no flush. A kill or power loss mid-write can truncate a file and lose the
whole file. `klara_trash.json` is the ONLY record of trashed assets
(Android hides trashed assets from MediaStore queries), so losing it
strands photos in system Trash with no in-app restore list.

**F-11 — Nothing is ever pruned. [Confirmed]** Analyses for deleted/edited
assets remain forever; session marks are kept; history and completions
are unbounded.

**F-12 — Analysis cache has no version, no fingerprint, no eviction.
[Confirmed]** Cache key is asset id only. No algorithm version, no
size/mtime fingerprint (`MediaAsset` carries no modified date). An edited
photo keeps its old hash/blur/dark values forever and lands in the wrong
decks, and future algorithm changes silently mix versions.

### RC-C — No background-execution layer

**F-20 — All thumbnail analysis is synchronous on the UI isolate,
strictly serial; zero isolates. [Confirmed]**
`library_scanner.dart:112-133`: per page, serial await +
`analyzeThumbnail`. `thumbnail_analysis.dart:34-58`: `package:image`
decode + two resize passes + per-pixel loops; photo analysis allocates a
3,842-element list per asset. The UI blocks between fetches (jank / ANR
risk on first scan). First-scan time is the sum of ~50k serial operations.
Greps establish the absence: zero `compute()` / `Isolate.run` /
`dart:isolate` in `app/lib`.

**F-21 — Grouping is capped but synchronous, one blocking pass at scan
completion, re-runs on every slider tick. [Confirmed]**
`grouping.dart:96-168`: threshold > 0 greedy grouping, max 512
comparisons → worst case O(n·512) ≈ 25.6M Hamming comparisons at 50k,
synchronous. Runs at hub completion (with bursts sort and flattening) and
in `DuplicatesController._regroup()` on every slider `onChanged` (not
`onChangeEnd`), no debounce. Only benchmark covers 5k/10k on host; 50k
on-device is unverified. Separately, threshold-0 grouping buckets by hash
alone, ignoring the dimension condition in `isExactDuplicateOf` — the two
definitions disagree and must be reconciled, not silently picked.

### RC-D — Fragmented thumbnail pipeline

**F-13 — Every thumbnail pays a redundant `AssetEntity.fromId`; no
shared thumbnail cache. [Confirmed]** `media_service_impl.dart:172-181`.
The entity was already held in `getAssets` and discarded when mapping to
the `MediaAsset` DTO. The same asset at 512 px is re-fetched
independently by Deck, Review, and SmartDeck into three separate maps,
and at other sizes elsewhere. Nothing persists to disk, so a cold start
re-fetches everything. Hub previews (deck row, smart-deck grid card,
On-This-Day hero card, timeline section) each fetch in `initState`
locally — the same asset up to 3× at 2 sizes — and a scroll-recreated
widget re-fetches.

**F-14 — No in-flight dedup: the cache guard is check-then-await.
[Confirmed]** `thumbnail_preloader.dart:59-64`, copied in the smart-deck
and duplicates controllers. `preloadAround` is called from load, every
mark, undo, and so on. Overlapping calls pass the guard and issue
duplicate fetches during swipe bursts.

**F-15 — Preload warms bytes, not decode; next card never rendered;
window fixed and backward-blind. [Confirmed]** Preload fetches 512 px,
3 ahead, fire-and-forget, stored only. The deck renders a single card —
no stack, no card underneath, zero `precacheImage` / `ResizeImage`. The
next card's decode and texture upload happen only after the swipe, so the
next card shows blank first. The fixed +3 window ignores swipe velocity,
direction, and undo. Dominant perceived deck defect.

**F-16 — No decode-size limiting at any of the 8 `Image.memory` sites;
format implicit JPEG q100, always square. [Confirmed]** Sites: swipe
card, review grid tile, duplicate group card, compress view, deck row,
smart-deck grid card, On-This-Day hero card, timeline section. No
`cacheWidth` / `cacheHeight` anywhere; the framework image cache is never
tuned (default 1000 images / 100 MiB). A 512² RGBA bitmap is 1 MiB decoded
versus ~0.25 MiB at 256². Review fetches 512 px for a third-screen tile;
hub fetches 128/256 px for 140 dp cards (soft at 3× DPR); deck 512 px is
upscaled on high-DPR phones. `thumbnailDataWithSize` is square and the
plugin defaults to JPEG q100 (verified), so the largest byte counts cross
the platform channel — including 128 px analysis thumbnails immediately
downscaled to 64/8.

**F-17 — Cache bounds inconsistent: deck caps 64 FIFO (not LRU); every
other thumbnail cache unbounded. [Confirmed]** Review thumbnails grow to
the whole delete set; SmartDeck has no cap; Duplicates holds every member
of every group; Compress holds up to 200 videos.

**F-38 — Videos indistinguishable in the deck, pay photo costs.
[Confirmed]** `MediaAsset` carries no duration (`AssetEntity.duration`
is available free at mapping time). No video badge or duration is shown,
and videos take the same square q100 thumbnail path as photos.

**F-39 — Failed thumbnails terminal for the session; library changes
invisible mid-session. [Confirmed]** One transient error becomes a
permanent placeholder until a filter change; no retry. (Library-change
visibility is also F-30 below.)

### RC-E — Reactive updates at data frequency

**F-23 — Hub reactive updates O(N) per page, O(N²) per scan; views redo
O(N) folds in `build()`. [Confirmed]** `decks_controller.dart:334`:
`analyses.assignAll` copies the cumulative map per page (≈ 25M copies at
50k). Deck membership is written per asset per deck, not per page. A
single hub `Obx` rebuilds the whole list, and each rebuild recomputes a
full-bytes fold and timeline years/month grouping in `build()`.
`decksForAsset` allocates a set plus lowercase/substring scans per asset.
(Phase 3B fixed part of this pattern in the same file; not carried
through.)

**F-24 — Review is one giant `Obx`, O(N) per build, with a rebuild per
thumbnail. [Confirmed]** `review_view.dart:181` wraps scaffold + header +
banners + bottom bar + grid. Per build, document-like items are computed
twice, each compiling a fresh regex per title; total bytes folds the whole
list; each sequential thumbnail arrival can retrigger a whole rebuild. A
1,000-item set means ~1,000 rebuilds × O(1,000) ≈ 10⁶ item-visits before
interaction. The deck is similar: the ready-body observer reads the
current thumbnail, so every preload insertion (4 per swipe) rebuilds the
whole body. Compress has one observer reading progress, so every tick
rebuilds header + preview + the whole list.

**F-37 — Work in `build()` and smaller confirmed costs (non-cosmetic
items only). [Confirmed]** `context.textStyles` constructs a new
text-style set per access, with a new `TextStyle` per getter (81
`copyWith` sites). The filter sheet builds all months and albums eagerly
in a scrolling column. Duplicate group cards build all members eagerly in
a wrap. Review/Trash items have no `ValueKey(id)`, so removal shifts
widget state (flicker). One fanned card lacks `didUpdateWidget` and shows
stale thumbnails. Trash arrival queues a snackbar and a modal in the same
frame. Compress fires two snackbars and the second hides the first.

### RC-F — Navigation destroys all state

**F-26 — Every bottom-nav tap destroys and re-creates the destination.
[Confirmed]** `app_bottom_nav.dart:22-35`: all tabs use `Get.offAllNamed`.
No shell / `IndexedStack`. Clean → Decks → Clean re-runs the entire deck
load chain plus a full scan. Tab switching feels like a relaunch because
mechanically it is. (The off-all-on-return behaviour in Review/Trash is a
documented anti-stale choice; its cost is real and the solutions file
preserves its intent rather than deleting it.)

### RC-G — No scan ownership

**F-22 — No scan cancellation, lifecycle pause, or concurrency guard;
every hub / Duplicates visit is a fresh full scan. [Confirmed]** The
scanner has no cancellation token; controllers hold no scan handle in
`onClose`; `DecksController.init()` has no in-flight guard; `retry()`
clears lists while a prior page callback can still write. The hub does
not pass results to Duplicates (no route arguments), so one session pays
2 full pagings plus 2 full 6.3 MB analyses decodes. No incremental path,
no change observer, no watermark. Progress is only per page (after up to
50 serial operations). This directly explains "decks by folder/month feel
slow": month entry from the hub depends on the full scan, while the main
deck's month filter uses a MediaStore-side date condition inconsistently.

**F-30 — No lifecycle handling; no library change notification.
[Confirmed]** Zero `WidgetsBindingObserver`, zero photo_manager change
callbacks. Returning from Settings after granting permission is not
auto-detected; library changes made in other apps stay stale until a
filter change or relaunch; preloads and scans are never paused on
backgrounding.

### RC-H — Release build implicit and unverified

**F-34 — Release build type declares nothing except debug signing;
shrinking is only an implicit plugin default, unverified. [Confirmed]**
`build.gradle.kts:37-43`: release sets only a debug signing config. The
Flutter plugin defaults enable minification, but that is invisible: a
`-Pshrink=false` flag, a plugin upgrade, or an Android Studio build can
silently change the binary. No app ProGuard rules are validated against
the 9 native plugins. R8 does nothing for Dart AOT code, fonts, assets,
or `.so` files.

**F-35 — Debug signing on release; no canonical build command, no
obfuscation / split-debug-info, no ABI strategy, no CI. [Confirmed]**
Zero hits for build / appbundle / split / obfuscate in the repo. The
default `flutter build apk` is a fat APK with 3 ABIs. Positive notes:
compile/target SDK 36, min SDK 24, NDK 28.2 (all inherited via `flutter.*`
— an upgrade silently changes them). Gradle uses an `-all.zip` wrapper
and `-Xmx8G`, with no caching/parallel settings.

**F-33 — Weekly notification likely never fires: required receivers
missing from the manifest. [Confirmed structure; on-device behaviour
unverified — functional, release-blocking]** The notification service
schedules an inexact periodic notification, but the app manifest declares
no receiver/service, while the plugin README requires the
scheduled-notification receivers plus boot permission. Scheduling reports
success, so the Phase 3 weekly nudge is probably silently dead. A
functional defect, not a performance cost, included because the app is
being made production-ready.

### Correctness-adjacent issues (performance-shaped, must not be lost)

**F-19 — Review-from-session fallback can only see the first 50 assets.
[Confirmed — pull forward, do not defer]** `review_session.dart:39`: the
fallback `getAssets()` defaults to page 0 / size 50. Delete-marked photos
beyond the newest 50 are silently absent when Review is opened from the
bottom nav without arguments. The route-argument path is unaffected. This
touches the trust flow — Review must show ALL delete-marked photos — so
it is fixed early in the solutions file, not left to a later phase.

**F-27 — Ready does not mean the first photo is visible: the first card
is swipeable while showing a spinner. [Confirmed — trust-adjacent]**
`status = ready` is set before any thumbnail exists, and the card's
spinner branch is already gesture-active, so a user can mark a photo
they have not seen.

### Perceived speed (kept: genuine rendering / interaction cost)

**F-25 — SwipeCard drag goes through `AnimatedContainer`; the exit
animation is invisible. [Confirmed]** `swipe_card.dart:52-58,94-110`:
every pan `setState` feeds an `AnimatedContainer` (200/300 ms exiting)
that re-interpolates instead of following the finger 1:1. Opacity is not
animated: the photo vanishes instantly, an invisible card animates for
300 ms, and only `onEnd` calls `onSwiped` — disappear, dead pause, next
card pops in. Each pan rebuilds the whole card including image, clip, and
transform. The docstring promises edge labels that highlight with drag;
the stack contains none, so there is no directional feedback before the
80 px threshold.

**F-28 — Per-tile shimmer multiplication; private blur is the priciest
raster. [Confirmed]** Every pending review tile creates its own shimmer
effect (1500 ms) — dozens simultaneously, against design §8's "at most
2–3 concurrent animations". Private blur σ=16 allocates a new blur filter
in `build()` per tile and renders through a filter layer plus scrim plus
badge.

## Likely issues (structure confirmed, magnitude unmeasured)

- **L-01.** First-page / album latency scales with MediaStore cost × 50
  serial file-size calls × album count; worst at 50k.
- **L-02.** JSON encode/decode jank: at 1–6 MB, each synchronous whole-file
  operation plausibly costs single-digit to tens of milliseconds
  mid-range — dropped frames plus battery.
- **L-03.** Hub scan rebuild: observer coalescing caps paints per frame,
  but per-frame O(N) builder arithmetic runs the whole scan competing
  with decode on the same isolate.
- **L-04.** The photo_manager Glide layer likely partly caches natively;
  the per-call `fromId` query, q100 re-encode, and channel copy are
  still paid per Dart call.
- **L-05.** The `image` package's AOT retention is plausibly the largest
  Dart dependency after the framework/GetX — confirm with
  `--analyze-size`; its runtime CPU cost is the stronger argument.
- **L-06.** Unobfuscated / fat-APK costs are quantifiable only from a
  real build.
- **L-07.** Retry-during-scan interleaving is plausible (missing guard
  plus retry clearing shared lists).
- **L-08.** Missing list keys likely cause flicker / re-decode; a widget
  test can confirm cheaply.
- **L-09.** Per-tile shimmer / blur raster cost is worst while decoding;
  needs a DevTools raster timeline.

## Hypotheses (need device evidence — do not treat as findings)

- **H-01.** Actual cold / warm / hot times are unknown, including whether
  Klara breaches Android Vitals slow-start thresholds (cold ≥ 5 s,
  warm ≥ 2 s, hot ≥ 1.5 s). Coded contributors make poor
  time-to-first-swipeable-card plausible; no number is claimed.
- **H-02.** Preload window sizing (+3) is reasonable if fetch + decode is
  much faster than the swipe interval; no authoritative benchmark exists.
  Settle with telemetry, not argument.
- **H-03.** Thumbnail byte sizes (the 30–100 KB range used in some
  arithmetic) are not measured.
- **H-04.** Eager-service cost is likely negligible versus engine startup.
- **H-05.** Transient thumbnail failure rate is unknown.
- **H-06.** OEM MediaStore variance is uncharacterised.

## Already good — do not regress

Lazy builders in all main lists/grids. Deck preload bounded and windowed.
Deck pagination re-entrancy guard plus the 10-card trigger. Analysis
persisted and reused; exact grouping is O(n) buckets; grouping capped.
Hub shows decks progressively per page. Whole-screen skeletons use a
single skeletonizer. `main()` does no work before `runApp`. Manifest is
lean: exactly 3 permissions (the missing
`READ_MEDIA_VISUAL_USER_SELECTED` is NOT a defect — partial access is
handled via photo_manager state, verified). Dialogs and snackbars go
through the mandated helpers. Empty-Trash uses one native sheet for all
ids. No auto-delete, no network/photo upload, no `MANAGE_EXTERNAL_STORAGE`
in the deck/thumbnail path, no full-size original loads for swiping.

## Open questions carried into the solutions file

Product decisions (genuine, not yet taken):
1. Is video compression in the first Play release? (Decides the biggest
   single dependency removal.)
2. Scan staleness policy: a completed scan is reused until when?
3. Storage wrapper for Stage 2: Drift (default recommendation) or sqflite
   over an identical schema?
4. Debounce durability trade-off: is a ~1–2 s / ~20-mark crash window
   acceptable, or must every mark flush to a serialised writer?
5. Symbols / signing ownership: who holds the keystore and archives
   split-debug-info per version?
6. Splash overlap versus design §13: confirm overlapping warm-up (not
   shortening the animation) is accepted, and pick the reduced-motion hold.
7. Deck card thumbnail size: is 512 px visibly soft at 3× DPR, and what
   size restores sharpness? (On-device A/B.)

Evidence questions (Phase 0 in the solutions file must answer these):
8. Actual cold / warm time-to-first-swipeable-card, and which startup
   step dominates on a real 50k library: MediaStore paging, file size, or
   file I/O?
9. Does the Glide layer cache make the shared thumbnail service simpler?
10. Real thumbnail byte sizes and failure rates?
11. Does icon tree-shaking deliver in the release AAB, and what is the
    true per-ABI download size?
12. The deck screenshot's sideways photo: original orientation, or EXIF
    ignored in thumbnail rendering? (One on-device comparison settles it.)
13. Merged release manifest: is `READ_MEDIA_VISUAL_USER_SELECTED` present
    or not, and what does the release artefact actually contain?

Deliberately NOT carried forward: the dead / commented-UI disposition
question. The owner has decided those UI items stay as they are, so the
solutions file does not ask about them again.
