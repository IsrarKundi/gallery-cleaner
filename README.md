# Klara — photo cleaning app (Android, Phase 1)

Klara helps you decide the fate of every photo, quickly and without
fear of losing anything. Swipe left to Keep, right to Delete (mark
only), up for Maybe, down for Favourite — with buttons for all four
actions, so no action depends on gestures alone. The full product
truth is `requirements.md`, the design system is `design.md`, and
session rules are `AGENTS.md`. Authority order: requirements →
design → AGENTS.

**Phase 1 status (gate, 25 Oct 2026): COMPLETE on host checks**
(see below for what is still owner-only). `flutter analyze` is
clean and the full `flutter test` suite passes (127 tests,
including the golden-path test below). Nothing here has been
verified on a real phone yet — on-device verification is the
owner's job (see "Human-only checklist").

## Prerequisites

- Flutter **3.47.7** (pinned in `app/.fvmrc`; use FVM if you have
  it, otherwise the Flutter SDK at that version).
- An **Android SDK** and a **real Android device** (or emulator).
  Klara is Android-only in Phase 1; there is no iOS target yet.
- **This VM has no Android SDK and no Java**, so no APK can be
  built or run here. Build and run on your own machine, where the
  Android toolchain exists.

## Run, check, test (from `app/`)

```sh
flutter pub get        # install dependencies
flutter run            # run on a connected Android device
flutter analyze        # must be clean
flutter test           # full suite, must pass
flutter test integration_test/   # golden path on a device (needs one connected)
```

## App identity

- `applicationId`: `mobile.klara.app`
- Package name in `pubspec.yaml`: `klara` (version `1.0.0+1`).
- Entry: `app/lib/main.dart` — a `GetMaterialApp` with the light
  theme only (dark mode is Phase 3), initial route `/splash`.
  Routes: `/splash`, `/` (deck), `/review`, `/trash`, `/history`,
  plus Phase 2A: `/decks` (smart-deck hub), `/duplicates`,
  `/smart-deck` (one smart deck as a swipe deck).

## Permissions — and why

Declared in `android/app/src/main/AndroidManifest.xml`, exactly
two, both read-only:

- `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` — the deck swipes
  through the whole library, which the system photo picker cannot
  do (it only returns user-selected photos). If the user grants
  only selected photos (Android 14 partial access), the app works
  on exactly those photos and says so on the deck.
- `MANAGE_EXTERNAL_STORAGE` is **never** requested (Play lists
  media-file access as an invalid use for it). No account, no
  sign-in, no photo upload: everything is on-device only, and no
  photo content is ever logged or sent anywhere.

## The trust flow (read this before judging any screen)

1. A swipe or button press only **marks** a photo (keep / delete /
   maybe / favourite). Nothing is deleted by a swipe.
2. The **review** screen shows the delete-marked photos as an
   editable grid with counts and total size; tapping a photo
   unmarks it.
3. Only the **Android native confirmation sheet** (MediaStore
   trash/delete request) moves photos to Trash. If the user denies
   it, those photos return to the deck with an explanation instead
   of silently vanishing.
4. **Trash is 30 days, recoverable.** Restore works for a single
   photo and for all of Trash. Space in Trash is shown as
   "recoverable until [date]" — **never** as freed.
5. Space counts as freed only after the user empties Trash (its own
   in-app confirmation first, then the native sheet) or the
   system's 30 days expire. Nothing auto-deletes, ever.

Three-state accounting is shown live on the deck: marked "to be
freed" / in Trash "recoverable until [date]" / freed only after
emptying or expiry.

## Record-based Trash — a real limitation

Android hides trashed assets from MediaStore queries, so Klara
cannot list the system Trash directly. The Trash screen lists only
assets trashed **through Klara**, from its own on-device record.
Photos trashed outside Klara (e.g. in another gallery app) will
not appear here, and Klara's record is metadata only (id, size,
dates) — Trash rows show no thumbnails, by design, since thumbnail
loads for trashed assets would fail.

## Phase 2A status (smart decks + duplicates, 25 Oct 2026)

Host checks pass (`flutter analyze` clean, full `flutter test`
suite green, 168 tests). On-device verification is still the
owner's job, as in Phase 1.

- **Detection (on-device, thumbnail heuristics — not exact
  measurements):** 8×8 average hash from the thumbnail; duplicates
  = same hash AND same dimensions; similar = Hamming distance at
  or under the slider threshold; blur = Laplacian variance on a
  64×64 grayscale thumbnail, blurry at or under 100.0; dark =
  mean luminance under 40.0. Hashes/scores are cached per asset
  id in LocalService (`klara_analyses.json`) so regrouping is
  instant and re-scans skip thumbnails for analysed assets.
  New dependency: pure-Dart `image` 4.12.0 (decoding only, used
  in service-layer code, never in feature code).
- **Duplicates screen:** greedy clustering around the first
  group's representative hash; keeper suggestion = sharpest,
  tie-broken by largest size (unscored assets rank last); tap
  any thumbnail to change the keeper. Similarity slider 0–10,
  default 5, regroups live from cached hashes. "Mark others for
  deletion" writes delete marks for non-keepers (keeper marked
  keep) into the `duplicates` session and navigates to `/review`
  — it never deletes directly and never bypasses review +
  native confirmation.
- **Smart-deck hub (`/decks`, also reachable from the deck
  AppBar):** Screenshots / WhatsApp / Downloads (album name
  contains, case-insensitive), Videos, Large (≥ 10 MB), Old
  (90+ days), Bursts (3+ photos, consecutive gaps ≤ 5 s),
  Blurry, Dark (the detection surface), plus a Duplicates row.
  Scanning is paged with a determinate progress bar (scanned
  count + % against the largest-album estimate); rows fill in
  per page, while Bursts/Duplicates stay "still scanning" until
  the scan completes. Videos are never blurry/dark-flagged
  (a video thumbnail frame is not the video).
- **Smart-deck swiping reuses the deck's own `SwipeCard` and
  `DeckActionBar`** (the bar is now callback-based so both
  controllers can use it) with the locked gesture mapping;
  marks write to the same LocalService session mechanism under
  `smart:<deck>` keys, so resume works and delete marks flow
  to `/review` exactly like main-deck marks.
- **Honest limitation:** the scan holds the full asset list in
  memory and decodes one thumbnail per uncached image on the
  UI isolate; first scan on a very large library takes a while,
  later scans are cheap via the cache. 50,000+ tuning is
  Phase 3 and was not attempted here.
## Phase 2B status (retention, 25 Oct 2026)

Host checks pass (`flutter analyze` clean, full `flutter test`
suite green, 212 tests). On-device verification is still the
owner's job, as in Phase 1 — including the two new platform
behaviours below, which no host test can prove: the share sheet
and the device-storage reading.

- **Maybe snooze:** `LocalService` gained snooze records
  (`klara_snoozes.json`, asset id → return date), a session
  listing, a weekly goal target and completion days
  (`klara_completions.json`). The hub's Maybe pile gathers
  Maybe-marked assets from all saved sessions (assets still in
  the library only) and offers Snooze 7 / 14 / 30 days and Clear
  snooze. Marking Maybe alone never snoozes. While snoozed the
  asset stays Maybe and the deck skips it; when the return date
  arrives, the next load of that session clears the Maybe mark
  (deck and smart-deck controllers, via the shared
  `DeckRetention` helper) so the asset returns as undecided,
  and the snooze record is cleared.
- **Goals + streaks (hub progress section):** presets 500 MB /
  1 GB / 2 GB per week, default 1 GB, stored in LocalService.
  Progress = MB freed this calendar week (Monday–Sunday) from
  history `mbFreed` only — trashed MB and marked MB never count.
  A streak day is a day with a completed deck session (final
  mark lands) or a history record (trash/empty run); the streak
  counts consecutive days ending today (or yesterday when today
  is still quiet) and resets on a gap over one day; current +
  best streaks are shown.
- **On This Day deck:** same month + day as today, previous
  years only (today's just-taken photos are excluded), as a
  smart deck (`smart:onThisDay`) reusing `SmartDeckController`
  and the hub scanner. Feb 29 photos match only in leap years.
- **Session summary + shareable result card:** when a main deck
  finishes, the finished state shows reviewed / kept /
  delete-marked (+ MB, labelled "to be freed") / maybe /
  favourite counts plus a Share button. Sharing uses
  `share_plus` 13.3.1: the card is captured as PNG via
  `RepaintBoundary` and shared as a file with the summary text;
  if capture fails, the same numbers are shared as text.
  Smart-deck finishes show the same counts without a share
  button. The summary never reports trashed MB as freed.
- **Storage projection bar (hub):** device free storage now →
  projected free after emptying Trash (free now + MB in Trash),
  via the `disk_space` 0.2.1 plugin (StatFs, MB) behind a
  `StorageService` interface. When device storage cannot be
  read (or no backend is registered), the bar shows a labelled
  library projection (in-Trash + marked figures from app
  records) and invents no device numbers.
- **New dependencies (both resolved cleanly on Flutter 3.47.7 /
  Dart 3.13):** `share_plus` ^13.3.1, `disk_space` ^0.2.1. No
  new Android permissions; no monetization code anywhere.
- **Refactors to hold the line budget:** deck retention glue
  (summary/share/snooze-expiry/completion) lives in
  `DeckRetention` (shared by both deck controllers) and the
  meter's service calls live in `DeckMeter` (in
  `space_meter.dart`); the main deck controller is 399 lines.
  Two tests were updated for superseded behaviour (the icon
  count pin 26 → 30 for the four new icons; the old "All
  decided" finished state is now the summary card).
- **Honest gaps / owner checks:** the share sheet and the
  `disk_space` reading are host-untestable and need his eyes on
  a real phone; `disk_space` reads shared-storage free space
  (the volume holding the photos), not internal-only storage.
  The string registry (`app_strings.dart`, 425 lines) is over
  the ~400 line guide — it grows monotonically with every
  feature and would need a locale split, not a Phase 2B change.

## Tests

- Unit + widget tests live in `app/test/` (211 tests plus
  the golden path below).
- **Golden path** (`app/test/golden_path_test.dart`, host-runnable
  twin of `app/integration_test/golden_path_test.dart`): splash →
  deck loads fake assets → mark one asset delete via the deck
  button → review → confirm trash (fake service simulating
  native-confirmation success) → Trash lists the entry with its
  recoverable-until date → restore it → Trash empties and history
  shows the trashed record (freed 0). The integration version
  drives the same flow on a device; on this host it cannot run
  (no device connected — `flutter test integration_test/` reports
  "No supported devices connected"), so the widget twin is the
  one that ran here.
- The real native sheet, real trash/restore, and back-gesture
  handling are **not** covered by any host test and are owner
  on-device checks, not claims.

## Provisional brand assets

The launcher icon (flat Google-blue field, photo stack + swipe
arrow, via `flutter_launcher_icons`) and the logo Lottie splash
choreography are **provisional** until the owner's eyes approve
them. Do not treat them as final Play assets. Palette (locked
25 Oct 2026, Option B Google blue): primary `#4285F4`, Keep
`#0F9D58`, Delete `#DB4437`, Maybe `#F4B400`, white background,
Favourite = heart filled with the primary. Flat design only — no
gradients anywhere in Phase 1 code.

## Human-only checklist (NOT done, needs the owner)

- [ ] Verify the name **"Klara"** on Google Play (the earlier
      working name "Swipe Clean" was abandoned — it collides with
      competitor "Swipe & Clean").
- [ ] On-device verification on a real phone: native sheet
      behaviour, real trash/restore, back-gesture handling, phone
      feel, light UI, and the provisional icon/logo approval above.
- [ ] App signing and Play submission (keystore, listing copy,
      screenshots). No signing or submission step has been done
      or guessed here.
- [ ] Monetization model + prices (deferred by decision — no
      paywall, ads, or subscriptions exist in Phase 1 code; do
      not add any before that decision).
- [ ] Phase 2+ scope (dark theme, video compression,
      document guard, localization, iOS) — none of it is in
      this build. Phase 2 itself (smart decks + retention) is
      complete on host checks; on-device verification of the
      Phase 2B share sheet and storage reading is still open.
