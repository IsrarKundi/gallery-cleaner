# ADR-001 — Phase 0 performance baselines (startup)

**Status:** Accepted (measurements captured 25–26 Oct 2026; temporary
instrumentation removed in the same change as this record).
**Context:** `docs/performance-solutions.md` Phase 0 requires device
baselines before any product code changes, so later phases are judged
against reality, not estimates. This record covers the startup baseline
only; the remaining Phase 0 items are listed under "Still open" and move
to their phase gates instead of blocking Phase 1.

## Method

- Device: Realme RMX3085, Android 13, library ~6,000 photos.
- Access: full photo permission (Android 13 has no system
  "selected photos" permission — that arrived in Android 14 — so a
  granted photo permission on this device means full access).
- Build: profile mode (`flutter run --profile` for Run 1; `adb` cold
  starts for Runs 2–3: `am force-stop` + `am start -n
  mobile.klara.app/.MainActivity`, timings captured with
  `adb logcat | grep KLARA_PERF`).
- Marks (temporary `KLARA_PERF` log lines, since removed): `runApp`,
  `splashComplete`, `permissionDone`, then each deck load step
  (`albumsDone`, `meterDone`, `tutorialDone`, `sessionDone`,
  `page0Done`, `restoreDone`, `protectionDone`), `deckReady`,
  `firstThumbnail` (first visible photo).
- Runs: 3 cold starts. Run 1 (6,507 ms) ran right after a fresh
  install and is treated as a fresh-install outlier; Runs 2–3 cluster
  at 4.4–4.7 s. Medians below are medians of all 3 runs.

## Results (median, milliseconds from `runApp`)

| Mark | Median | Step duration (median) |
|------|--------|------------------------|
| runApp | 0 | — |
| splashComplete | 1,693 | splash: 1,693 |
| permissionDone | 1,730 | permission: 37 |
| albumsDone | 3,124 | albums: 1,394 |
| meterDone | 3,131 | meter: 7 |
| tutorialDone | 3,132 | tutorial: 1 |
| sessionDone | 3,134 | session: 2 |
| page0Done | 4,346 | page 0: 1,212 |
| restoreDone | 4,350 | restore: 4 |
| protectionDone | 4,354 | protection: 4 |
| deckReady | 4,354 | — |
| firstThumbnail | 4,732 | first thumbnail: 378 |

Raw runs (firstThumbnail totals): Run 1: 6,507 ms; Run 2: 4,732 ms;
Run 3: 4,359 ms. Median total: **4,732 ms** to the first visible photo.
Each run produced exactly one `firstThumbnail` line (no double
registration).

## Findings (what the numbers settle)

1. **Albums dominate.** `getAlbums()` costs a median 1,394 ms — the
   largest in-app step (issues file F-05). It scales with folder
   count, not photo count, so it bites even at 6k photos.
2. **Page 0 is second.** 1,212 ms for the first 50-asset page
   (path-list re-enumeration + 50 serial file-size queries, F-04).
3. **Splash is third.** 1,693 ms, of which the Lottie itself is
   ~1,667 ms; Run 1 also showed a ~1.9 s first-frame stall
   (114 skipped frames). Splash overlap (solutions Phase 2) attacks
   this without shortening the animation.
4. **Meter / tutorial / session / restore / protection are not the
   problem on device** (1–7 ms each). The suspected file-read costs
   do not show up at 6k; they may still matter at 50k, which is
   unmeasured (see "Still open").
5. **In-app median 4,732 ms is under the 5 s Vitals cold-start bar,
   but tap-to-first-photo is longer** — engine startup before `runApp`
   is not counted in these marks, and Run 1 exceeded 5 s in-app.
   The honest statement is "near the bar at 6k, likely over it from
   tap", not "passing".
6. **This is a 6k baseline, not a 50k baseline.** Nothing here
   describes 50k behaviour; 50k claims in the issues file remain
   arithmetic extrapolations until tested at that scale.

## Observations (not gates, recorded for later phases)

- Profile build: 33.7 MB APK. Kotlin Gradle Plugin warning for
  `disk_space_plus`, `photo_manager`, `video_compress_advanced`
  (future Flutter versions will fail to build with KGP-applying
  plugins — a Phase 7 dependency item, not a Phase 0 blocker).
- Glide "no GeneratedAppGlideModule" warnings are benign
  (photo_manager works without an app Glide module); not a defect.

## Still open (measured at their phase gates, not forgotten)

- Hub first-visit vs return-visit scan timing; tab round-trip ×5;
  review fill at 200 / 1,000 marks; duplicates / smart-deck entry;
  trash restore/empty timing. These need fresh temporary
  instrumentation at their phases (the startup marks are removed now).
- Release AAB inspection (merged manifest, font subsetting, per-ABI
  sizes) and `--analyze-size` output — needs an SDK-machine release
  build (Phase 0 item 0.6, deferred to Phase 7).
- Thumbnail byte sizes and failure rates; whether the Glide layer
  caches repeat thumbnails; the sideways deck photo (original
  orientation vs EXIF handling); icon tree-shaking in the release AAB.
- 50k-library behaviour (all of the above, at scale).

## Decision

Phase 0 closes on the startup baseline above. Later phases compare
against the median table in "Results" on the same device and library
size where possible, and must state the device, Android version, and
library size with every new number. No phase may claim an improvement
without a before/after pair on device.
