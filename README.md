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
  Klara is Android-only in v1; there is no iOS target yet.
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
- Entry: `app/lib/main.dart` — a `GetMaterialApp` with light +
  dark themes (default System, persisted choice re-applied at
  launch), initial route `/splash`.
  Routes: `/splash`, `/` (deck), `/review`, `/trash`, `/history`,
  plus Phase 2A: `/decks` (smart-deck hub), `/duplicates`,
  `/smart-deck` (one smart deck as a swipe deck), plus Phase 3A:
  `/settings`.

## Permissions — and why

Declared in `android/app/src/main/AndroidManifest.xml`, exactly
three (the third arrived in Phase 3A):

- `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` — the deck swipes
  through the whole library, which the system photo picker cannot
  do (it only returns user-selected photos). If the user grants
  only selected photos (Android 14 partial access), the app works
  on exactly those photos and says so on the deck.
- `POST_NOTIFICATIONS` — only for the one weekly nudge, only
  requested when that toggle is turned on (Phase 3A).
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

## Phase 3A status (dark mode, settings, private blur, favourites protection, 25 Oct 2026)

Host checks pass (`flutter analyze` clean, full `flutter test`
suite green). On-device verification is still the owner's job, as
in Phase 1 — including the new platform behaviours below, which
no host test can prove: the real weekly notification delivery,
the system favourite flag on a real library, and dark-theme feel
on a real phone.

- **Dark theme:** full `AppPalette.dark` set (`app_colors.dart`,
  every value documented with contrast reasoning against
  `#121212`): background `#121212`, surface `#1E1E1E`,
  surfaceVariant `#2C2C2C` (tonal elevation, never shadow),
  lightened Google-family brand colours (primary `#8AB4F8`,
  Keep `#81C995`, Delete `#F28B82`, Maybe `#FDD663`) with dark
  ink labels (`onPrimary #202124`, because the fills are light).
  `ThemeData.dark()` is built only from tokens, exactly like the
  light theme. Every screen re-themes, because no screen
  hard-codes light colours — all colours come from
  `context.palette`.
- **Settings (`/settings`, deck AppBar gear button):** theme
  (System / Light / Dark, default System, applied live via
  `Get.changeThemeMode` and re-applied at launch from the
  persisted record), private blur, favourites protection, weekly
  nudge, haptics, reduced motion, trash auto-empty prompt, plus
  an About row (app name, version read at runtime via
  `package_info_plus` — never hard-coded — and the trust-flow
  note). Settings live in `klara_settings.json` alongside the
  goal/tutorial keys, which saving never drops.
- **Weekly nudge (real, not faked):** `flutter_local_notifications`
  22.3.2 schedules exactly one weekly nudge (inexact schedule,
  low importance) when the toggle is ON and cancels it when OFF;
  a denied notification permission leaves the toggle OFF with an
  explanation. This is the single new Android permission:
  `POST_NOTIFICATIONS` (Android 13+ needs it to show any
  notification), requested at toggle time only. No other
  permission changed; no media/storage permission was added.
- **Haptics (design.md §8, previously none existed):** light tick
  (`selectionClick`) on every mark/select, medium click
  (`mediumImpact`) when a review delete is confirmed, firm pulse
  (`heavyImpact`) when trash is emptied. Gated by the haptics
  toggle (default ON); long vibrations are never used.
- **Reduced motion:** the in-app toggle, when ON, forces
  `MediaQuery.disableAnimations` app-wide even if the system
  setting is off; when OFF, the system setting applies (existing
  behaviour). Splash already honoured the system setting; it now
  honours the toggle too through the same MediaQuery override.
- **Splash adapts to theme:** dark → dark background + white
  logo SVG + white Lottie variant; light → white background +
  ink logo + normal Lottie. The white assets already existed —
  they are wired, not regenerated.
- **Private blur (default OFF — blurring by default would hide
  exactly what the user must judge before a restore/delete):**
  when ON, Review grid thumbnails render blurred (sigma 16)
  with tap-to-reveal per item; a reveal lasts until blur is
  toggled or the screen is left. The deck is NEVER blurred (it
  is the decision screen). Trash rows are metadata-only, so
  there is no thumbnail to blur there — the eye toggle still
  lives on Trash because the setting is global, and the rows
  themselves already show no photo content.
- **Favourites protection (default OFF — it changes delete
  behaviour, so it must be an explicit choice):** when ON, a
  delete mark on a protected photo is blocked on the deck and
  smart decks (banner explanation, card stays), favourited
  non-keepers on Duplicates are marked keep instead of delete
  (with an explained count), and review excludes favourited
  items from the trash run (they stay in the grid, with an
  explained count). Protected = Klara favourites from any
  session OR system favourites (`photo_manager`
  `AssetEntity.isFavorite`, Android 11+ `IS_FAVORITE`, mapped
  into `MediaAsset.isSystemFavourite`; Klara never stars or
  unstars photos). "Edited" protection is NOT implemented:
  photo_manager 3.12.0 exposes no on-device edited flag for
  Android (its `hasAdjustments` note is Darwin-only) and
  MediaStore offers no edited column this app can read — the
  Settings copy says so honestly instead of faking a signal.
- **Trash auto-empty — trust-rule resolution (requirements §4
  wins over any literal auto-delete reading):** the setting
  (default OFF) NEVER silently deletes media. When ON and trash
  records pass their recoverableUntil date, Trash shows an
  in-app prompt dialog; confirming runs the normal empty flow
  (native sheet follows), declining drops only the expired
  local records (their system media is already gone after 30
  days — record cleanup, not media deletion). Still-recoverable
  records are never touched by either path. When OFF, expired
  records are left for manual emptying with no prompt.
- **New dependencies (both resolved cleanly on Flutter 3.47.7 /
  Dart 3.13):** `flutter_local_notifications` ^22.3.2,
  `package_info_plus` ^10.2.2. No monetization code anywhere;
  no ads exist and none were added.
- **Honest gaps / owner checks:** weekly notification delivery,
  the `IS_FAVORITE` flag on a real library, and dark-theme feel
  all need his eyes on a real phone; the settings view and the
  trash prompt dialog are host-tested for state, not for
  on-device timing. The string registry (`app_strings.dart`,
  now 543 lines) is further over the ~400 line guide — it grows
  monotonically and would need a locale split, not a Phase 3A
  change. Deck controller is 399 lines, review controller 400.

## Phase 3B status (denied/partial polish, 50k performance, accessibility, 25 Oct 2026)

Host checks pass (`flutter analyze` clean — zero issues — full
`flutter test` suite green: 272 tests, up from 240). No new
permission, no new dependency, no monetization/ad code. On-device
verification is still the owner's job, as in every phase — the
host numbers below prove the algorithms scale, not that a phone
does, and he may not own a 50k library.

- **Denied / partial-access polish (every path audited, gaps
  fixed, tests for each):** media denied states (deck, hub,
  duplicates) now offer "Allow access" + "Open settings" (the
  permanent-denial loop — retrying a grant Android will never
  re-prompt — is closed; the settings action is the one
  deliberate exception to the one-CTA empty-state rule).
  Partial (Android 14 limited) access gets a banner with honest
  copy plus "Add more photos" (`presentLimited` + reload — the
  system picker that ADDS photos, never a faked full grant)
  and "Open settings", with a hint explaining the
  Settings → "Allow all photos" → return → "Add more photos"
  round trip (the system gives no callback on return).
  Native trash-confirmation mixed runs are no longer hidden
  behind a single outcome: trashed+denied+failed gets a counted
  dialog ("{trashed} moved to trash, {denied} returned to the
  deck, {failed} could not be moved") with a "View trash"
  choice when anything was trashed; trashed+failed shows the
  error banner plus a moved-to-trash snackbar; denied photos
  have their session marks cleared so the deck re-shows them
  undecided, failed photos keep delete marks for retry. Native
  restore/empty partial denials likewise report counts/bytes
  instead of hiding partial success. Verified already correct
  (not duplicated): notification-permission denial leaves the
  weekly-nudge toggle OFF with an error key; share failure
  falls back to the same numbers as text.
- **50,000+ photo performance:** duplicate grouping was
  O(n·g) — quadratic on a mostly-distinct library. Now:
  threshold 0 (exact duplicates) is a one-pass Map bucket,
  O(n), with output identical to the old greedy scan (proven
  by an equivalence test against a re-implementation of the
  old scan); threshold > 0 keeps the greedy scan but caps
  representative comparisons per asset at 512, so worst case
  is O(n·512) instead of O(n²). Stated trade-off: a partner
  whose representative sits beyond the cap is missed and
  starts its own group — a safe split, never a wrong merge,
  and grouping only ever suggests a keeper (deletion still
  flows through review + native confirmation). Corollary: a
  pair entirely beyond the cap vanishes as a group (both
  members stay singletons and are dropped from duplicates) —
  the photos stay ungrouped in the library, never deleted.
  Hub scan is now incremental per page (deck byte totals,
  marked MB, asset-by-id map accumulated once, not rebuilt
  per rebuild), and the hub list is a `ListView.builder`
  (settings' fixed list and the filter sheet stay eager by
  design — see the code comments). Host benchmarks (this VM):
  grouping 5k distinct 215ms, 10k distinct 393ms, 10k with
  duplicates (bucket) 68ms; hub scan over 5k cached analyses
  265ms with correct totals. Residual, documented: the
  scanner still returns the full asset list (bursts/duplicates
  need list-level results) and decodes one thumbnail per
  uncached image on the UI isolate; later scans are cheap via
  the hash cache. Deck thumbnails stay bounded (64-entry
  eviction cache); review/duplicates thumbnail maps grow only
  with the user-marked/grouped subset, not the library.
- **Accessibility audit (table in the Phase 3B report):**
  TalkBack labels added where tiles/rows announced nothing
  (hub deck rows, duplicate thumbnails, review tiles — all
  with photo names or a "Photo" fallback). Hit-area fixes:
  SecondaryButton, Maybe snooze buttons, and the trash
  Empty-trash button are now 48dp buttons themselves (the old
  40dp-in-48dp-box pattern failed edge taps — proven by tap
  tests). Contrast fixes within the locked palette: TextButton
  foreground is text ink (light primary was 3.56:1 on white),
  snackbar action is inverse ink (old primary was 1.75:1 on
  the dark bar), plain error text replaced by ink text in the
  two places it appeared (light error is 4.29:1 on white).
  One documented constraint: dark tertiary #80868B fails on
  surfaceVariant (3.79:1) — unused by any widget today, and
  must not be used on elevated dark surfaces until the token
  changes. Goal preset chips wrap instead of overflowing at
  the 1.30 text-scale cap. Text-scale clamp 0.85–1.30 and
  reduced-motion handling (system + toggle) re-verified
  unchanged.
- **Line-budget extractions (same precedent as Phase 3A):**
  `DeckAccess` + `deck_queue.dart` (deck controller),
  `ReviewDeletePlan` (review controller),
  `TrashBottomBar` (trash view), `maybeItemsFor` (hub
  controller). Every hand-written file is back under ~400
  lines except the `app_strings.dart` registry (unchanged
  exception — it grows monotonically and needs a locale
  split, not a Phase 3B change).
- **Honest gaps / owner checks:** real 50k on-device timing,
  the Android 14 limited-grant picker flow, and TalkBack
  behaviour on a real phone all need his eyes; host tests
  prove state and labels, not device timing or TalkBack
  delivery.

## Phase 4 status (video compression + document guard, Android only, 25 Oct 2026)

Host checks pass (`flutter analyze` clean, full `flutter test`
suite green: 290 tests, up from 272). On-device verification is
still the owner's job, as in every phase — the native transcoding
run, the MediaStore save of a compressed copy, and the real
screenshot/document mix in his library cannot be proven here.

- **Video compression (requirements §7, Phase 4: "preview + keep
  original until user confirms"):** a Compress screen (`/compress`,
  deck AppBar film-strip button) lists the library's videos
  (paged, newest first, capped at 200). Tapping one video — the
  only trigger, never automatic, never bulk — transcodes a copy
  into the app cache with a determinate progress bar and Cancel,
  then shows the honest preview: original size, compressed size,
  and "smaller by X". Saving writes the copy into the library as
  a NEW item (`<name>_compressed.<ext>`) via photo_manager's
  editor save; the original is never deleted, overwritten or
  replaced by compression, and the saving is never called
  "freed" while the original exists — removing the original is a
  separate review + native-confirmation trash step, and space
  counts as freed only after trash is emptied or expires. A
  compressed copy that is not smaller cannot be saved (the UI
  says so plainly). Failure or cancellation leaves the original
  untouched and discards the partial cache copy. New dependency,
  resolved cleanly on Flutter 3.47.7 / Dart 3.13:
  `video_compress_advanced` 4.0.2 (DefaultQuality,
  `deleteOrigin: false`, progress stream, cancel supported),
  behind a `VideoCompressionService` interface; only the
  implementation imports the SDK and photo_manager's editor.
  Manifest exception, documented not hidden: the plugin's own
  manifest declares legacy `WRITE_EXTERNAL_STORAGE`, so it
  appears in the merged manifest; Klara's own manifest is
  unchanged (the three permissions above), Klara never requests
  it at runtime, and on Android 13+ it grants nothing.
- **Document guard (requirements §7, Phase 4: "warn before
  deleting screenshots that look like receipts, IDs, tickets, QR
  codes"):** Klara has no OCR and no content classification, so
  the guard honestly uses only on-device metadata signals — a
  screenshot album/folder (the Screenshots deck's match) or a
  document token in the filename (receipt, invoice, ticket,
  boarding, passport, licence, identity/id, QR, barcode,
  document, contract, certificate, voucher, prescription;
  matched as whole tokens, so "id" never matches inside "video").
  Enforcement is at Review, the only place deletion is initiated
  (swipes only mark, so deck/smart-deck/Duplicates marks are all
  caught there): a banner while document-like items sit in the
  grid, and a counted confirmation dialog at delete time that
  stops the run BEFORE any native sheet. "Delete anyway" is the
  deliberate override and stands (still via the native sheet +
  30-day Trash); "Keep these documents" unmarks only those items.
  The guard never deletes and is never an unblockable block.
  What it cannot do is stated in the code: a receipt screenshot
  with a generic filename in a non-screenshot folder is not
  flagged, and a meme in the Screenshots folder is flagged —
  the copy says Klara cannot read what a photo shows.
- **Line-budget extractions (same precedent as Phase 3A/3B):**
  `ReviewBlur` (private-blur state) and `review_session.dart`
  (session-mark writes) out of the review controller, which is
  back at exactly 400 lines. The string registry
  (`app_strings.dart`, now 664 lines) remains the one known
  exception — it grows monotonically and needs a locale split,
  not a Phase 4 change.
- **Honest gaps / owner checks:** the real transcode (quality,
  speed, and whether DefaultQuality shrinks his actual videos),
  the MediaStore save appearing in his gallery, and the guard's
  real-world hit/miss balance on his screenshots all need his
  eyes on a real phone. Localization, monetization and the iOS
  port (the rest of Phase 4 in requirements §7) are NOT in this
  build — they were excluded from this run and remain open.

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
- [ ] Remaining Phase 4 scope (localization, monetization,
      iOS) — none of it is in this build. Phase 4 Android items
      (video compression, document guard) are complete on host
      checks; on-device verification of the transcode, the
      MediaStore save, and the guard's real-world behaviour is
      still open, as is on-device verification of the Phase 2B
      share sheet and storage reading.
