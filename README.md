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
  Routes: `/splash`, `/` (deck), `/review`, `/trash`, `/history`.

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

## Tests

- Unit + widget tests live in `app/test/` (126 pre-gate tests plus
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
- [ ] Phase 2+ scope (smart decks, goals/streaks, dark theme,
      video compression, document guard, localization, iOS) —
      none of it is in this build.
