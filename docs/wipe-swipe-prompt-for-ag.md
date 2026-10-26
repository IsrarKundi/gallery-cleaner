# Prompt for AG — Wipe swipe rework (copy everything below into AG)

You are working in the Wipe repo (IsrarKundi/gallery-cleaner). **Pull latest first** — remote main is at `18a694e`, which already includes the wipe. wordmark in the Clean tab app bar. The app was renamed Klara → Wipe (package `mobile.wipe.app`, appTitle `'Wipe'`); do not reintroduce "Klara" strings.

## What to build

### 1. Swipe tint effect on the photo card

In `app/lib/features/deck/widgets/swipe_card.dart` (shared by the Clean deck and smart decks — change it once, both get it):

- While the user drags a card, show a **gradient overlay anchored to the BOTTOM of the image card only** — not a full-card wash. It fades from solid color at the bottom edge to transparent toward the middle of the photo.
- Color: Keep = green (palette Keep token `#0F9D58`), Delete = red (palette Delete token `#DB4437`).
- Strength scales with drag progress — reuse the same intensity curve the edge labels already use.
- A big icon + word label (Keep / Delete) appears together with the tint, like the reference screenshots (green thumbs-up + "Keep", red archive icon + "Archive" — our action is called Delete, not Archive).
- The tint shows only for the direction being dragged toward, never both at once.

### 2. New swipe directions (default)

- **Right = Keep, Left = Delete.** This is the REVERSE of the current mapping.
- Current code (for reference): in `_EdgeLabels`, keep intensity = `-drag.dx` (left), delete = `+drag.dx` (right), maybe = `-drag.dy` (up), favourite = `+drag.dy` (down); exit offsets send maybe up and favourite down. Flip the horizontal mapping.

### 3. No vertical swipes

- Remove up/down swiping completely: no Maybe gesture, no Favourite gesture.
- Remove the top and bottom edge labels (only left/right edge labels remain).
- Update the first-run tutorial (`app/lib/features/deck/widgets/tutorial_overlay.dart`) to teach only left/right.

### 4. Settings option for swipe directions

- Add a "Swipe directions" setting in Settings (`app/lib/features/settings/controller/settings_controller.dart` + `app/lib/features/settings/view/settings_view.dart`), persisted in `AppSettings` via `LocalService` — follow the existing settings pattern (like theme/haptics: SettingsController owns the persisted record and applies it).
- Two choices: **"Right = Keep, Left = Delete" (DEFAULT)** and **"Right = Delete, Left = Keep"**.
- The deck and smart decks must read it live and apply it immediately with no restart. Flipping it flips: which drag direction means Keep vs Delete, which side the tint/label appears on, the edge labels, and which direction triggers the delete-undo below.

## DO NOT TOUCH

- **The bottom action bar (`app/lib/features/deck/widgets/deck_action_bar.dart`) — buttons, order, and behavior stay EXACTLY as they are, including the Maybe and Favourite buttons.** Only the swipe gestures change, not the buttons.
- The app bar (it already shows the wipe. logo).
- `app/lib/features/review/view/review_view.dart` and `app/lib/features/review/widgets/review_grid_tile.dart` — the owner's files, never modify them.
- Never restore commented-out code or UI.

## Repo rules (binding)

- Strings only via `app_strings.dart` keys. Colors, sizes, and radii only via tokens (`design.md` §10) — no raw values in feature code.
- Views = layout + Obx only. Features never import another feature's internals.
- This reverses a LOCKED gesture decision, so update `requirements.md` (§3/§4 gesture mapping) and `design.md` in the same change.
- Run `flutter analyze` (must be clean) + `dart format` + `flutter test` (must pass) before declaring done.
- **Known pre-existing failures — do NOT chase or fix these** (identical on the clean baseline): `swipe_card_mechanics` edge-labels test, `ReviewView` empty-state test (it expects a commented-out "Back to deck" CTA — never restore it), `app_icons` valid-IconData test. Baseline: 549 pass + these 3.
- Commit format: `<phase>-<task>: <summary> (requirements §n / design §n)`. Push when done — the owner pulls in Cursor and verifies on his phone.
- Device checks the owner will do on his phone (do not fake these from the VM): tint looks like a bottom gradient (not a full wash), directions match the setting, flipping the setting flips everything immediately, delete-undo works on the new Delete direction.