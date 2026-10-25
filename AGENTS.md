# AGENTS.md — Klara

Standing rules for any AI coding agent working in this repo. **Read this file first, every session.**

Adapted from PeopleGone's `AGENTS.md` + `FOLDER_STRUCTURE_AND_CONVENTIONS.md` (IsrarKundi/people_gone). **The PeopleGone originals were NOT modified** — this is Klara's own copy, changed where Klara differs. Where this file and PeopleGone's differ, THIS file wins for Klara.

## Read before writing any code
1. `requirements.md` — the only product truth. Read it fully before any code; read the section you are implementing before each task.
2. `design.md` — the design system. Tokens, components, motion and accessibility rules live there.
3. This file — session rules.

Authority order: `requirements.md` → `design.md` → this file. If they conflict, the higher one wins and the conflict is reported, never silently resolved.

## Toolchain
- Flutter via FVM. Pin the exact version in `.fvmrc` at project creation (this machine already uses 3.47.7 for PeopleGone — reuse that pin unless the project sets its own).
- Every requirement is testable. A task is done only when its acceptance criteria pass.
- Never invent a decision `requirements.md` or `design.md` already makes. If something is genuinely unspecified, choose the option that is (a) simpler, (b) cheaper to run, (c) more private — in that order — and record it in `docs/architecture/` as an ADR.

## NEVER (Klara)
- Auto-delete anything. Every deletion is user-confirmed via review + the Android native confirmation.
- Claim a photo is deleted or space is freed while it sits in Trash. Three-state accounting only (Marked / In Trash until [date] / Freed).
- Use the word "permanent" while restore exists.
- Request `MANAGE_EXTERNAL_STORAGE` (Play lists media-file access as an invalid use for it).
- Log, store in analytics, or send to any third party the content of a user's photo. On-device only, no account, no cloud.
- Hard-code prices. Monetization is deferred; when it lands, prices come from the store at runtime.
- Commit any secret, key, keystore, or real `.env` values.
- Put a raw `Color(...)`, a raw font size, or a magic padding/radius number in feature code (tokens only — `design.md` §10).
- Use `google_fonts` (fonts are bundled assets only).
- `Get.put` inside `build()`; registering the same controller twice; navigating with `Navigator.push` (use named routes).
- Call `Get.snackbar` / `Get.dialog` ad hoc in features (use the `AppSnackbar` / `AppDialog` helpers).
- Ship a screen with a dead button or a placeholder action.
- Copy a Dribbble concept that conflicts with `design.md` §11 (floating glass hiding actions, multiple primaries, hidden nav, neon over photos).
- Restore commented-out code or UI that was removed on purpose (same standing rule as PeopleGone, applied to Klara's own removals).

## ALWAYS (Klara)
- **Media permission IS required** (`READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` + Android 14 partial access) — this is an explicit REVERSAL of PeopleGone's picker-only rule, because whole-library swiping cannot work through the system picker. Handle partial access honestly: work on exactly the granted photos and say so. If the user denies the native delete confirmation, return those photos to the deck with an explanation.
- **Gesture mapping locked:** left = Keep, right = Delete, up = Maybe, down = Favourite. Buttons for all four actions. First-run tutorial + persistent edge labels are mandatory.
- **Trust flow, no step skipped:** mark-only swipes → review screen → Android native confirmation → 30-day Trash → restore / empty / expiry. Never skip review, never skip confirmation, never auto-delete.
- Cite the requirements/design section you implement in the commit. Commit format: `<phase>-<task>: <summary> (requirements §n / design §n)`.
- Run `flutter analyze` (must be clean) + `flutter test` (must pass) before declaring any task done.
- Keep every hand-written file under ~400 lines.
- Update `requirements.md` / `design.md` in the same change if behaviour or visuals change.
- Stop at human-only steps (Play account, "Klara" name verification, signing, pressing Submit) and leave them as a checklist for the developer instead of guessing.

## Structure & conventions (adapted from PeopleGone)
- Project root holds `requirements.md`, `design.md`, `AGENTS.md`. The Flutter app lives in `app/` (pubspec, analysis_options, assets, lib, test, android, ios).
- `app/lib/`:
  - `main.dart` — minimal entry ONLY: binding, config load, runApp. No UI, no feature logic.
  - `core/` — `bindings/initial_binding.dart` (the ONLY place global `Get.put` lives), `constants/` (`app_colors.dart`, `app_text.dart`, `app_sizes.dart` — the ONLY files with colours, font sizes, layout numbers), `routes/` (`app_routes.dart` constants + `app_pages.dart` wiring), `strings/app_strings.dart` (every user-visible string as a key + English map), `theme/` (`app_theme.dart` built ONLY from tokens + `theme_ext.dart` context shortcuts), `utils/` (pure formatters + `Result<T>`), `widgets/` (the shared kit — see `design.md` §10).
  - `features/<name>/` — `binding/` + `controller/` + `model/` + `view/` + `widgets/`, for: `deck`, `review`, `trash`, `decks`, `settings`. Template: one view file per screen; view = layout + Obx only; controller registered ONLY in its feature binding with constructor injection.
  - `services/` — interfaces + implementations for `media` (photo library access), `trash` (trash/restore/empty), `local` (history, settings, session state). Purchase service arrives with monetization (Phase 4), not before.
- **Dependency rules:** views → own controller + `core/*` only (views never import services). Controllers → service interfaces + own feature's model + `core/utils` + `core/strings` + `core/routes`. Service implementations are the ONLY files importing platform/storage SDKs. Features NEVER import another feature's internals — cross-feature navigation uses Routes; cross-feature data goes through a service.
- **Errors reach the UI as state, not exceptions:** services return `Result<T>`; controllers expose error state as string keys; views render `ErrorView` / `AppSnackbar`. No `try/catch` in views, no raw exception text shown to users.
- **Strings:** every user-visible string via `app_strings.dart` keys (English v1; locales added later without touching views). Prices never in code.
- **Tests:** every controller ships success + failure path tests; every shared widget at least one widget test; a golden-path integration test for mark → review → trash → restore.
- **Definition of done (any task):** implements exactly the cited section(s) — nothing extra, nothing missing; `flutter analyze` clean; `dart format` applied; `flutter test` passes including new tests; no file over ~400 lines; no raw colours/sizes/strings outside their token/string files; works in light theme (dark = Phase 3); no new permission beyond the media set in `requirements.md`; no secret in the repo; human-only steps listed as a checklist, NOT guessed or faked.

## Differences from PeopleGone, recorded (so nobody "fixes" them back)
| PeopleGone rule | Klara rule | Why |
|---|---|---|
| No media/library permission; system picker only | Media read permission required + partial-access honesty | Whole-library swiping cannot work through the picker |
| App calls ProcessingApi → own gateway; never an AI vendor | No server, no gateway, no vendor — on-device only | Klara deletes local photos; nothing is processed remotely |
| Never silently downscale a photo | No output photos exist; nothing is downscaled or exported | Klara's output is a cleaner library, not an edited image |
| "Magic Eraser" / watermark-removal marketing ban | Not applicable (no such feature or copy) | Dropped, not weakened — it has no Klara equivalent |
| Paywall + RevenueCat from v1 | No paywall, ads, or subscriptions in Phase 1; monetization deferred | Owner decision 25 Oct 2026; purchase service arrives in Phase 4 |
| Urdu via NotoSansArabic/Nastaliq | English only v1, i18n-ready architecture; Urdu fonts kept as the localisation plan | Owner decision 25 Oct 2026 |
| Motion tokens 180ms/300ms | Motion ladder 100/200/300/400ms (`design.md` §8) | Research-backed ladder for this project |
