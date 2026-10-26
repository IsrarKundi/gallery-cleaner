# ADR-007 — Phase 7: navigation shell, dependency diet, Baseline Profile procedure

## 1. Keep-alive shell (7.1 — fixes F-26, closes the Phase 3 bottom-nav residual)

### Design

`/` is now the shell route (`ShellView` + `ShellBinding` in
`app/lib/features/shell/`), not the deck directly. The shell hosts
three retained tabs in an `IndexedStack`:

| Nav destination | Stack child | Retained? |
|---|---|---|
| 0 Clean | `DeckView` | yes |
| 1 Decks | `DecksView` | yes |
| 2 Trash | — (action, opens fresh Review) | n/a |
| 3 Settings | `SettingsView` | yes (stack index 2) |

Tabs build lazily on first visit (unvisited stack slots render
`SizedBox.shrink` — `IndexedStack` builds all children eagerly, so
the visited-set guard is what makes the build lazy) and stay
mounted afterwards, so a tab switch is never a relaunch: the deck
keeps its queue and marks, the hub keeps its shared scan (Phase
4.2). `ShellController.navIndex` is 0, 1 or 3 only; Trash is never
a retained tab.

Review/Trash off-all-on-return semantics are PRESERVED exactly as
the doc requires: tapping Trash always opens a FRESH Review route
(no route arguments — it loads the current delete set from the
session, the F-19 path), and returning from Review/Trash
(`offAllNamed('/')`) recreates the shell and a fresh deck. A
retained Review would go stale; the shell deliberately does not
retain it. Standalone `/decks` and `/settings` pages stay routed
for direct/test navigation; production nav goes through the shell.
Each tab view takes `showBottomNav` (default true); the shell
constructs them with `false` so only the shell renders one nav
bar. `AppBottomNav` takes an optional `onDestinationSelected`
callback; with no callback the legacy off-all mapping stays, so
standalone views and existing tests are unchanged. Review/Trash
pass a callback that lands back in the shell at the tapped tab
(`offAllNamed('/', arguments: index)`); `ShellBinding` reads that
argument (validated to 0/1/3, else Clean) as the initial tab.

### Composition-root exception (recorded, not silent)

AGENTS.md forbids features importing another feature's internals.
The shell is a composition root, like `AppPages`: it imports the
tabs' views and bindings, and `ShellController` imports
`DeckController` — but only to ask whether a card exit is in
flight (see §1.1). The shell owns no feature state and no feature
imports the shell. This exception covers the shell only; it does
not license other cross-feature imports.

### 1.1 The mid-exit residual is CLOSED (not just moved)

The Phase 3 residual was: bottom-nav taps during the ≤300 ms
card-exit window bypassed the settled-review gate because
navigation destroyed the deck. Two changes close it:

1. **Retained switches never destroy the deck.** A tab switch
   during a flight leaves the deck mounted off-stage; the flight
   completes and its mark records.
2. **Trash-tab navigation is gate-aware.** `ShellController`
   opens Review through the deck's gate
   (`DeckController.runAfterCardExit`, a public wrapper over the
   existing private `DeferredAction`) — but only when the deck
   tab has been visited. A never-visited deck has no exit in
   flight, and `Get.find` on it would create it (and prompt
   permission); the shell never does that.

### 1.2 Gate-ordering fix (required for the residual to close)

`SwipeCard` fires `onExitEnd` BEFORE `onSwiped`. The old view
wiring released the gate on exit-end, so a deferred Review
captured its set (args path) or session (session path) BEFORE the
in-flight mark recorded — the gate protected the wrong moment.
Fix, in view wiring only (`SwipeCard` API unchanged):

- `deck_view.dart`: `onSwiped` awaits `markCurrent(mark)` and
  then releases the gate (`setCardExiting(false)`). `onExitEnd`
  is no longer wired to the gate. A refused mark still
  completes, so the gate can never wedge on a refused swipe.
  The reduced-motion path (no flight) is unchanged.
- `smart_deck_view.dart`: same contract, sync version
  (`markCurrent` is sync there; release follows it directly).

Consequence: a deferred Review (args path via the deck action
bar, session path via the shell Trash tab) now always includes
the in-flight mark. The stale `DeckController` comment claiming
bottom-nav taps stay a residual until Phase 7 is updated.

### Tests (all green)

`app/test/features/shell/shell_test.dart` (4 widget tests,
GetMaterialApp + counting fakes, the proven harness pattern):

- Tab round-trip ×5: identical Deck/Decks controller
  instances, flat `getAssets`/`requestPermission` counts.
- Trash opens a fresh Review showing the current delete set,
  growing from 1 to 2 on a second visit (session path — this
  caught a fake bug during development: `getAssetsByIds` must
  resolve ids, or every session-path Review looks empty).
- Trash tap during a card exit does not navigate until settle,
  then Review includes the mark.
- Tab switch during a card exit does not drop the mark
  (identical deck instance, mark present off-stage and after
  returning).

Existing suites re-checked green: golden path, deck view, decks
view, widgets (AppBottomNav), review — except the ONE known
pre-existing failure (Review empty-state test expecting the
intentionally-commented "Back to deck" CTA; not restored).

### Open observation (NOT fixed in Phase 7, needs owner word)

`DeckWarmUp` is permanent and `started` stays true, with no
consume/invalidate API. A fresh `DeckController` (its own
`_warmUpUsed` starts false) after a Review return therefore
re-joins the launch-time warmed page 0, which can re-show
since-trashed photos whose session marks were cleared. This is
pre-existing behaviour on the preserved Review-return path, not
a Phase 7 regression, and it was NOT verified with a test in
this phase. Fixing it (e.g. a service-level consume flag) needs
owner word; recorded here so it is not mistaken for closed.

### No requirements/design update for 7.1

Requirements §4 (core flow / trust rules) and design §6
(components: bottom navigation) specify destinations and the
trust flow, not tab rebuild-vs-retention internals. 7.1 changes
no destination, label, or user-visible flow — it stops an
in-flight mark from being lost, which restores the already
specified flow. No doc edit is owed; this paragraph is the
record of that decision.

## 2. Dependency diet (7.2 — recorded decisions, not stalls)

- **Video compression SHIPS** (`video_compress_advanced` kept,
  route kept). Only
  `lib/services/video/video_compression_service_impl.dart`
  imports it; everything else talks to the
  `VideoCompressionService` interface. Release smoke test added:
  `test/features/compress/compress_smoke_test.dart` pumps the
  real `/compress` route + binding with fakes and proves list →
  preview → save wiring (the native codec itself stays an
  owner on-device check, as before).
- **`package:image` KEPT.** It is imported only by
  `lib/services/detection/thumbnail_analysis.dart` (analysis
  decode). The doc's replacement condition (native
  `instantiateImageCodec` at analysis size, bit-comparable
  outputs, guarded by tests) was aimed at UI-thread decode cost;
  Phase 5 already moved analysis off the UI isolate, so the
  remaining cost is isolate-side, and a bit-exact replacement
  buys no measured gain. Revisit only with a device
  measurement showing otherwise.
- **Kotlin MethodChannels for `package_info_plus` /
  `disk_space_plus`: SKIPPED** (optional in the doc; ~15 lines
  each of new native surface for no measured gain).
- **No transitive churn:** the 14 transitive upgrades are NOT
  taken (doc: do not churn them).
- **No behaviour change** in 7.2: one new test file, zero
  production lines changed.
- **`--analyze-size` before/after: OWNER CHECK** (see §3) — it
  needs a release build this VM cannot produce. Nothing about
  size is claimed from this VM.
- **KGP-applying-plugins warning** (Phase 0 note:
  `disk_space_plus` / `photo_manager` /
  `video_compress_advanced`): warning-only, caused by the
  plugins' own build files, fixable only by plugin upgrades —
  which the no-churn rule forbids. Left as-is; the owner
  confirms on the SDK-machine build that it stays a warning.

## 3. Baseline Profile + budgets (7.3 — procedure, not a fake profile)

No CI exists in this repo, so budgets are a DOCUMENTED MANUAL
CHECK, not a pipeline gate. No Baseline Profile file is added
here: generating one needs an Android SDK + device runs, which
this VM does not have, and an untestable plugin would be worse
than none. What this section records is the exact procedure the
owner runs on an SDK machine, and the exact checks that gate
the release candidate (Phase 8 re-verifies all of this).

### 3.1 Baseline Profile journeys

Generate with the standard AndroidX Macrobenchmark Baseline
Profile generator (benchmark module + `baselineprofile` plugin
— added on the SDK machine per AndroidX docs, NOT added here).
The generator must cover exactly these three journeys, in
order, on a release build:

1. **Cold → deck:** cold launch → splash completes → deck
   first thumbnail visible (the Phase 0 baseline path:
   splash + albums + page 0).
2. **Swipe ×10:** ten consecutive decided swipes on the deck
   (mix of Keep/Delete so both mark paths compile).
3. **Review grid:** open Review from the bottom nav with the
   ten marks, scroll the grid, return to the deck.

Acceptance (doc 7.3): the profiled journeys show a cold-start
improvement vs the Phase 0 baseline (median 4,732 ms to first
thumbnail on RMX3085, ~6k photos) on the SAME device. That
comparison is an owner device measurement; it is NOT claimed
here.

### 3.2 Verification that the profile ships

After generation, before any submission:

- The profile file is present in the AAB (check with
  `--analyze-size` output / bundletool dump — the profile
  must appear in the AAB contents, not just in the repo).
- The release candidate is built WITH the profile and cold
  start is re-measured on the same device as Phase 0.
- If the profile is missing from the AAB, the candidate fails
  the gate — it does not ship on the assumption that it is
  there.

### 3.3 Manual budget checks (run on every release candidate)

No CI, so the owner runs these by hand and records the table
in the release record. The FIRST SDK-machine release build
establishes the baseline numbers; later candidates are
compared against that table, and any increase must be
explained in the release record before submission.

| Check | Command / location | Baseline / rule |
|---|---|---|
| Per-ABI sizes | `flutter build apk --release --split-per-abi` (ADR-002 QA command), then sizes under `build/app/outputs/flutter-apk/` | First SDK-machine build records the table; later candidates compared against it |
| `--analyze-size` breakdown | `flutter build appbundle --release --analyze-size` (ADR-002 submission command + flag) | Record the breakdown table per candidate; before/after vs the previous candidate |
| Shipped font sizes | `app/assets/fonts/`: Inter-Regular/SemiBold/Bold, 68 KiB each (~204 KiB total, measured in-repo) + font entries in `--analyze-size` | No new font asset without an ADR note; icon-font subsetting is a Phase 8 item |
| Merged-manifest diff | Merged manifest under `build/app/intermediates/` for the release build, diffed vs the previous candidate | Only the three manifest permissions from requirements §5 survive; `MANAGE_EXTERNAL_STORAGE` must never appear |
| Mapping / resources presence | `build/symbols/<version>/` exists after the build and is archived OUTSIDE git before any `flutter clean` (ADR-002) | Missing symbols = failed candidate (obfuscated traces would be unreadable) |
| Reference anchor (not a budget) | Phase 0 profile APK: 33.7 MB | Profile-mode size, NOT comparable to a release AAB/APK — recorded only so nobody mistakes it for a release budget |

## 4. Release finish (7.4 — follows in the next commit)
