# Klara — Design System

**Status:** v1, 25 Oct 2026. Built from the Dribbble 2026 research (report dated 25 Oct 2026) + the PeopleGone folder-structure and conventions doc + this project's `requirements.md`.
**Authority order:** `requirements.md` (product truth) → this file (visual and interaction truth) → `AGENTS.md` (session rules). If this file and `requirements.md` conflict, `requirements.md` wins and this file must be amended.
**Palette status: PICKED 25 Oct 2026 — Option B "Google blue".** §2 records the picked hex values. Nothing else in this file invents a palette.

---

## 1. Direction in one paragraph

The 2026 modern look: rounded, not sharp; pill/fully-rounded primary actions and floating pill-shaped bottom bars; restrained, mostly flat surfaces with gradients and glass used as accents (bars, hero cards, empty and loading moments) rather than everywhere; one dominant accent plus tonal containers; large, weight-driven headlines over small grey secondary text; an 8dp grid with 16dp phone padding; bottom-anchored primary actions for thumb reach; short, springy motion (roughly 150–400ms) with ripple on Android.

For Klara — a utility, not a portfolio piece — borrow the boring parts: one primary action per screen, a bottom-anchored Keep/Delete/Review bar, review before permanent delete, progress as "photos reviewed / MB freed", and plain, high-contrast empty states. Do NOT copy the portfolio parts: floating glass bars that hide actions, several colourful primaries in one frame, hidden navigation, neon text over photos, or light-grey captions that fail contrast. A 2026 trend piece warns explicitly against "Dribbble-driven design: floating layers and hidden nav that wow a portfolio but confuse a paying user" — that warning applies directly to this app.

**Concept vs shipped, read before copying any shot:** Dribbble shots in the research (Nexora fintech concept, eSIM telecom concept) are portfolio concepts — useful for shape, colour mood and layout ideas, not proof a pattern shipped, tested, or is accessible. The shipped systems (Material 3 Expressive on Android 16, Apple Liquid Glass on iOS 26, the cleaner apps PhotoSwooper and Wipeclear) are the default whenever a concept idea conflicts with them. No Dribbble shot in the research was a photo-cleaner app, and no shot was pixel-measured — Dribbble claims below are indexed shot descriptions, not measurements.

---

## 2. Colour

- **Flat is the baseline.** Gradients and glass are accents, not the system. At most ONE gradient in the app: the empty-state/onboarding hero, or the "freed space" celebration — never on every card.
  - **Klara rule (requirements §6 wins over this bullet):** Klara ships flat-only — NO gradients anywhere in Klara code (verified by grep in Phase 2B). The "at most one gradient" allowance above does not apply to Klara.
- **Glass only for the bottom bar and sheet scrims over photos, with an opaque fallback.** Never for the photo grid, list text, form inputs, or the Delete confirmation. Apple's own Liquid Glass needed a more opaque "Tinted" fallback in iOS 26.1 after readability criticism — that is the lesson, not a detail.
- **Accent count: 1 primary accent + 1 supporting tonal colour + semantic colours used only for their meanings.** Two saturated accents (the Nexora concept uses lime + indigo) look great in a fintech portfolio frame and noisy in a photo grid full of colourful thumbnails — the photos are already the colour.
- **Semantic rule (locked, from `requirements.md` §6):** Keep = green family, Delete = red family, Maybe = amber, Favourite = heart filled with the primary colour. **Never encode Keep/Delete by colour alone** — always icon + label + position (§9).
- **Semantic roles (fixed now; hex values filled on palette pick):** `primary`, `onPrimary`, `primaryContainer`, `secondary`, `background`, `surface`, `surfaceVariant`, `textPrimary`, `textSecondary`, `textTertiary`, `border`, `success` / `successBg`, `warning` / `warningBg`, `error` / `errorBg`, `scrim`. Note: Material 3 has NO built-in success or warning role — those must be explicit custom tokens, not overloaded secondary/tertiary.
- **Palette PICKED 25 Oct 2026 — Option B "Google blue":** primary #4285F4, Keep #0F9D58, Delete #DB4437, Maybe #F4B400, background white (Files by Google vibe). Favourite = heart filled with the primary #4285F4. Remaining neutral roles (surface, surfaceVariant, text, border, successBg / warningBg / errorBg tints, scrim) are set in `app_colors.dart` at build time from Material 3 light defaults and must pass 4.5:1 — no other hues are introduced. A red primary was deliberately avoided — red reads as danger in a cleaning app. (Options A "Trust green" and C "Dark premium" were offered and not picked.)
- **Dark theme (Phase 3, not v1):** #121212-family surfaces, NOT pure black. Elevation in dark = lightness (higher surfaces slightly lighter), not shadow. Desaturate brand colours in dark. Test every token pair in both themes. Dark-mode-first neon glass over the photo grid is forbidden.
  - **Phase 3A shipped values (see `app_colors.dart` for the full contrast reasoning):** background #121212, surface #1E1E1E, surfaceVariant #2C2C2C; dark brand colours are LIGHTENED Google-family tones (primary #8AB4F8, Keep #81C995, Delete #F28B82, Maybe #FDD663) with dark ink labels (#202124 on the fills), because light fills need dark text to pass 4.5:1. Dark tints pair with light text. Favourite in dark = dark primary.
- **Contrast:** 4.5:1 for normal text, 3:1 for large text and UI components. Secondary text must pass at its size — 12sp light grey usually fails, so darken it. Disabled text is exempt from the contrast requirement but must still be readable and explained.

---

## 3. Typography

- **Family: Inter, bundled as an asset (weights 400 / 600 / 700).** `google_fonts` is FORBIDDEN — no runtime downloads (PeopleGone convention, carried over). System Roboto is the fallback only if bundling fails. Do not pair a display serif with a UI sans — that is a marketing-page pattern, not a cleaner pattern. For future localisation: NotoSansArabic for Urdu body text, NotoNastaliqUrdu for Urdu headings only (line height 2.0), digits always Latin and LTR (PeopleGone convention, carried over).
- **Scale (Material 3, sp — values live ONLY in `app_text.dart`):**

| Style | Size / Line height | Weight | Use in Klara |
|---|---|---|---|
| displaySmall | 36 / 44 | 700 | Hero number ("2.4 GB can be freed") |
| headlineLarge | 32 / 40 | 700 | Large hero alternative |
| headlineSmall | 24 / 32 | 700 | Screen titles |
| titleLarge | 22 / 28 | 600 | Screen titles (alternative), card titles |
| titleMedium | 16 / 24 | 600 | List-row titles |
| bodyLarge | 16 / 24 | 400 | Primary reading text |
| bodyMedium | 14 / 20 | 400 | Default body, list subtitles |
| bodySmall | 12 / 16 | 400 | Metadata ("12 Mar 2025 · 3.2 MB") |
| labelLarge | 14 / 20 | 600 | Buttons |
| labelMedium | 12 / 16 | 600 | Chips, badges, metadata alternative |
| labelSmall | 11 / 16 | 600 | Fine print ONLY |

- **Never below 12sp for functional text.** 11sp is fine print only.
- **Hierarchy: size first, weight second, colour last and never alone.** Material 3 Expressive's emphasised styles keep size and line height and change only weight, so swapping one in never reflows the layout — use weight (not a second hue) for emphasis. Labels are concise and sentence case, never all-caps shouting. Body line height ~1.5x.
- **Text scaling:** the user's system text setting applies, clamped to 0.85–1.30 in the app builder (PeopleGone rule) so accessibility scaling works without breaking layouts.

---

## 4. Spacing, radii, layout

- **Grid: 8dp base, 4dp for micro-detail** (Android official guidance). Spacing scale (values live ONLY in `app_sizes.dart`): `xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32, huge 40, giant 48`. A size not in the scale does not exist — no invented 10dp, 15dp or 18dp values.
- **Screen padding: 16dp on phones.** 20–24dp only for hero/empty screens where more air is a deliberate choice.
- **Gaps:** 8dp between related elements (chips, icon + label, row icon and text), 16dp between related groups, 24–32dp between sections. Chip-to-chip minimum 8dp.
- **Corner radii:**

| Element | Radius |
|---|---|
| Filter chips | Pill (or 8–16dp) |
| Primary buttons | Pill (radius = half height) |
| Secondary / tonal / outlined buttons | 12dp rounded rectangle |
| Cards | 16–24dp |
| Bottom sheets | 28dp top corners |
| Photo thumbnails | 12–16dp — photos themselves are NEVER pill-rounded; they must stay recognisable |

- **Layout:** phone screens are full-width minus 16dp padding. On tablets/foldables, centre content and cap the column — the exact cap is a product decision (no sourced phone max-content-width token exists; only the sheet cap, 640dp, was found). Breakpoints (window classes): compact < 600, medium 600–839, expanded ≥ 840. What changes at breakpoints is layout (e.g. grid columns), not sizes.
- **Sizing rule (binding): fixed logical pixels + breakpoint layout changes. `flutter_screenutil` and any percentage-of-screen sizing are FORBIDDEN.**
- **Thumb reach:** the primary bar is pinned to the bottom, above the nav bar, respecting safe area and gesture insets. Full-width on the review screen. A floating pill bar (16dp side margin) on the grid is allowed ONLY if it never covers the last row — otherwise a pinned bar is safer. **Delete is never a lone floating FAB.**

---

## 5. Buttons

- **Treatments (Material 3 Expressive's five):** filled = primary; tonal or outlined = secondary; text = tertiary. Mapping for Klara:
  - Primary (filled): "Start scan" on Home; "Delete N photos" on the Review screen ONLY.
  - Secondary (tonal/outlined): "Keep all", "Skip".
  - Tertiary (text): "Learn more", "Undo". **Never a text button for destructive Delete — it must not look like a link.**
- **Heights: primary 48–56dp, compact/secondary 40dp, hit area always 48dp.** CONFLICT NOTE: Material 3 Expressive height ladders disagree across sources (32/40/56/96/136dp vs 24/32/40/48/56dp) — verify on m3.material.io before freezing tokens. The 48–56 / 40 rule above is the safe subset.
- **Content padding:** 8dp vertical / 24dp horizontal for the default button; 16dp between related buttons, 24dp between distinct sections.
- **Icon + label:** primary actions ALWAYS icon + label (e.g. trash icon + "Delete"); leading icon 20dp. Icon-only only for 48dp toolbar icons with a content description.
- **Disabled state:** ~0.38–0.5 opacity + a caption explaining why ("Select at least 1 photo"). Disabled "Delete" at 0 selected is the standard case.
- **Loading state:** spinner in the button for short ops, button disabled to prevent double-submission. For jobs over ~4 seconds (scan, delete), use a determinate progress bar with % + count (§6), not an in-button spinner alone.
- **One primary per screen:** 1 filled primary + at most 1 tonal/outlined secondary + text tertiary. Dribbble frames often show several colourful CTAs — that is a portfolio frame, not a screen state.

---

## 6. Components

- **Bottom navigation:** 3–4 destinations max (e.g. Clean, Duplicates, Albums, Settings — or fewer), icon 24dp + label, pill selected state. Use the library default for the selected-pill size (sources conflict: 56×32 vs 64×32dp — do not hand-set it). Height 80dp expanded / 56dp compact per the M3 summary. Filters *within* Clean (All / Photos / Videos / Screenshots) are top tabs or chips, NOT nav items.
- **Bottom sheets:** filters, sort, category detail, Delete confirmation. 28dp top radius, 640dp max width, drag handle, primary action pinned at the sheet's bottom, safe area and keyboard respected. **Never stack sheets.**
- **Cards — sparingly:** one Storage summary card (hero number + progress), one card per category (Duplicates, Screenshots, Large videos, Blurry) with thumbnail strip, count and size. Photos themselves are NOT in cards — the grid is the content. Bento-grid values from web tutorials (24px padding, heavy shadows) are web values; the Android card equivalent is a tonal surface + 12–16dp radius, not a heavy shadow.
- **List rows:** 56–72dp two-line rows, 16dp horizontal padding, leading thumbnail/icon + title 16sp + subtitle 14sp + trailing metadata/chevron, dividers between groups only, not every row. GAP NOTE: no Dribbble list-row measurement was found — this is the M3-library default, not a Dribbble token.
- **Chips / filters:** 32dp visible height, 48dp hit area, 8dp gap. Selected = filled/tonal primary; unselected = outlined/surface. Never chips for the primary Delete action.
- **Progress:** determinate linear progress + % + count for scan/delete jobs ("Scanning 1,243 photos… 42%"); indeterminate spinner only for unknown duration; skeleton screens for loading lists.
- **Empty states — design all three, each with exactly one CTA:**
  1. First run: "No scan yet" + [Scan now].
  2. Clean result: "No duplicates found" + [Scan again] + storage summary.
  3. No filter results: "No screenshots in this period" + [Clear filters].
  Illustration small, above the CTA, never full-screen. Never a bare "Nothing here yet" with no direction.

---

## 7. The deck (Klara's core screen — §5/§6 plus these)

- **Card:** full-bleed photo, 12–16dp corners. Edge labels per the locked gesture mapping (`requirements.md` §3): KEEP left, DELETE right, MAYBE top, FAVOURITE bottom. Buttons for all four actions below the card; Undo always visible.
- **Bottom-anchored action bar** with Keep / Delete / Review. Delete on the deck only MARKS — the destructive confirmation lives on the review screen.
- **Live three-state space meter on the deck** (Marked "to be freed" → In trash until [date] → Freed only after emptying/expiry) — never hidden away in Stats. This is the #1 differentiator and it must be visible where the user swipes.
- **Photo context on the card:** date, size, folder — small caption, never covering the photo's subject.
- **Swipe exit animation:** platform spring, transform + opacity only (§8).
- **No blocking "building deck" overlay:** deck construction happens in the background; the deck is instantly interactive (the competitor's shuffle-blocked-card flaw, fixed).

---

## 8. Motion, haptics, press

- **Duration ladder: 100 / 200 / 300 / 400ms.** Micro-feedback 100–150ms, button taps 150–200ms, small transitions (toggles, dropdowns) 200–300ms, pages/sheets 300–400ms. Longer than 400ms only for complex choreography — never for routine transitions.
- **Easing:** standard ease-out `cubic-bezier(0.2, 0, 0, 1)` for state changes; Material 3 Expressive spring `cubic-bezier(0.34, 1.56, 0.64, 1)` for entrances (sheet, card). **No custom bounce per component.**
- **Press (Android):** ripple + state layer (press opacity 0.12) is the default. An optional 0.97 scale may be added on the swipe-card and the large primary CTA only — never scale every list row.
- **Haptics:** light tick on select, medium click on Delete confirm, success haptic on "freed" completion. Nothing on scroll or hover. Clear > rich; buzzy long vibrations are banned.
- **Reduced motion:** always respect the system setting (Android: Remove Animations / animator scale 0). Replace slides, parallax, rotates and large scale with opacity fades; keep functional indicators simplified. An in-app toggle is not a substitute for the system setting (offering one as well is harmless).
- **Skip in this utility app:** kinetic typography, parallax, scroll-jacking, auto-playing celebrations on every open, confetti loops. The freed-space celebration is one calm moment, not a loop. At most 2–3 concurrent animations; animate transform + opacity only (GPU, no layout recalculation).

---

## 9. Accessibility (always, not Phase 3)

- **Touch targets: 48×48dp minimum, 8dp between adjacent targets.** A visible glyph may be 20–24dp inside the 48dp hit area (e.g. a 24dp icon in a 48dp chip area). Note: WCAG 2.2 AA's legal minimum is 24px — 48dp is the platform recommendation and this project's target, not a WCAG quote.
- **Phase 3B correction — the button itself must be 48dp tall.** A 40dp button centred inside a 48dp box does NOT give a 48dp tap target (proven by tap tests: taps at the box's top edge, outside the 40dp button, missed). SecondaryButton, the Maybe snooze buttons, and the trash Empty-trash button are all 48dp buttons now, not 40dp visuals in 48dp boxes.
- **Contrast:** 4.5:1 normal text, 3:1 large text and UI components, in both themes. Never copy a Dribbble shot's grey-on-white caption colour without checking it.
- **Phase 3B contrast fixes (locked palette, no new hues):** TextButtons are plain text, so their foreground is text ink, not primary (light primary #4285F4 on white is 3.56:1 — below 4.5:1; ink is 16.1:1 light / 13.83:1 dark). The snackbar action is inverse ink for the same reason (old primary was 1.75:1 on the dark theme's light bar). Plain error-coloured text is likewise avoided (light error #DB4437 on white is 4.29:1); error stays as a component colour (icon/badge), where the 3:1 bar applies. Dark tertiary #80868B passes on the base background (5.09:1) but FAILS on surfaceVariant #2C2C2C (3.79:1) — no widget renders tertiary text today, and tertiary must never be used on an elevated dark surface until the token changes.
- **Never colour-alone:** Keep/Delete, errors, and selection always carry icon + label (+ checkmark/border for selection).
- **Content descriptions** on every icon-only control (TalkBack). Text resizes with the system setting (clamped per §3).
- **App motion law (from PeopleGone, kept):** calm only. No stagger, no bounce, no celebrations as a pattern — the freed-space moment in §8 is the single exception.

---

## 10. Token discipline (from PeopleGone conventions — binding)

- Colours ONLY in `core/constants/app_colors.dart` (AppPalette ThemeExtension, light + dark sets). Text styles ONLY in `app_text.dart`. Sizes ONLY in `app_sizes.dart`. Strings ONLY in `core/strings/app_strings.dart` keys (English v1; other locales added later without touching views).
- Feature code NEVER contains a raw `Color(...)`, a raw font size, or a magic padding/radius number. Violations fail review.
- Fonts are bundled assets. `google_fonts` is forbidden.
- Assets: `img_<name>.png`, `ic_<name>.svg` (Material icons are the default — custom only when Material lacks the glyph), `anim_<name>.json` (must have a static fallback).
- Shared kit in `core/widgets/` — every screen builds from these: AppScaffold, PrimaryButton / SecondaryButton, LoadingOverlay, ErrorView, EmptyView, AppDialog, AppSnackbar, SectionHeader, AppCard.

---

## 11. What NOT to copy from Dribbble

- Floating glass bars that hide Keep/Delete; multiple colourful primaries in one frame; hidden navigation; neon text over photos; light-grey captions that fail contrast; full-screen gradients; bento grids for the photo grid itself; heavy shadows on every card (flat + hairline borders is the baseline, shadows only for floating elements).
- Rule: if a shot's idea conflicts with a shipped-system rule above, the shipped rule wins.

---

## 12. Open questions and conflicts (do not silently resolve)

- **Palette: PICKED 25 Oct 2026 — Option B "Google blue"** (see §2). No longer open.
- **M3 Expressive button heights conflict** (32/40/56/96/136dp vs 24/32/40/48/56dp) and **nav active-indicator conflict** (56×32 vs 64×32dp) — verify on m3.material.io before freezing tokens.
- **No counted Dribbble sample:** pill-vs-rectangle prevalence, primaries-per-screen counts, and list-row heights cannot be stated as Dribbble percentages or dp values — this file gives direction + shipped tokens, not Dribbble statistics.
- **Dribbble evidence is index descriptions, not pixel measurements** (live shot pages rendered blank in the research browser); shot pages show no publication date in indexed text — do not cite a shot as "2026" without checking its shot page date.
- **Phone max-content-width:** no sourced token (only sheet 640dp) — a product decision when tablet/foldable layout is built.
- **Secondary guides** (notably copyprogramming.com summaries) were used only where they summarised a platform spec — do not quote them as Google/Apple specs.
- **Mockup warning:** the concept mockups in `~/workspace/swipe-clean-mockups/` show the OPPOSITE gesture mapping (delete left / keep right) and the mockup palette — both are superseded by the locked gestures in `requirements.md` §3 and the picked palette in §2. Regenerate before use as design reference.

---

## 13. Brand assets: icons, logo, splash (added 25 Oct 2026, from PeopleGone/Uncrowd analysis)

- **In-app UI icons: one centralized system, exactly like PeopleGone's `lib/core/constants/app_icons.dart` (audit 2026-10-19).** Honest note: PeopleGone's UI icons ARE Phosphor via the `phosphoricons_flutter` pack (MIT) — what makes them not "random pub.dev icons" is the centralization. Regular is the default weight, Fill marks selected/active only, Duotone is reserved. Feature code NEVER names `Icons.*` or `PhosphorIcons*` directly (PeopleGone has zero direct Material `Icons.*` usage in views); every icon resolves through named `AppIcons` constants (trash, check, close, camera, undo, history, …), so a glyph is re-chosen in exactly one place. Klara does the same: create `core/constants/app_icons.dart` with the same rule, named by meaning (keep, delete, maybe, favourite, undo, review, trash, history, …). If the owner wants zero pack icons at all, that is a different decision (a custom SVG set via `flutter_svg`) and must be said explicitly — do not silently swap families.
- **Launcher icon: custom, like Uncrowd's `icon2.png` via `flutter_launcher_icons`.** Uncrowd's icon is a custom image, not a pack glyph: blue gradient field, white focus-corner frame, a central white keeper person with two faded people behind — the product metaphor in the icon itself — with adaptive background `#0B54EF`. Klara's launcher is likewise a custom foreground on the Google blue family (`#4285F4`), with a photo-cleaning metaphor (photo stack / swipe), wired through `flutter_launcher_icons` (Android only in v1). The final icon needs the owner's eyes before any Play listing; the v1 built overnight is provisional until he approves it.
- **Wipe rename (27 Oct 2026):** app renamed Klara → Wipe (package mobile.wipe.app); the Clean tab app bar shows the wipe. wordmark (`assets/icons/wipe_logo.svg`, one adaptive currentColor file, blue dot #1D6FF8) instead of the 'Clean' text title. The bottom-nav label stays 'Clean'.
- **Logo like Uncrowd: a lowercase bold wordmark as vector paths, not typed text.** Uncrowd is "uncrowd" in Poppins ExtraBold letter paths plus a blue dot `#2563EB`; letters use `currentColor` (ink `#111827` on light, white on dark) and the dot is always brand blue; files `uncrowd_logo.svg` / `_white.svg` / `_adaptive_bluedot.svg`, rendered via `flutter_svg`. Klara: "klara" lowercase bold wordmark as vector paths (bundled Inter ExtraBold, logo-only asset) plus a dot in primary Google blue `#4285F4`; letters theme-adaptive (ink on light, white on dark); files `assets/icons/klara_logo.svg` + `klara_logo_white.svg` (or one adaptive file). Name files for Klara from day one — do not repeat PeopleGone's stale `framora_logo.svg` filename still referenced by its home screen after the rename.
- **Splash Lottie: like PeopleGone's splash.** `lottie` package, `assets/animations/klara_logo_lottie.json` (+ white version), splash completes on Lottie finish with the hold timer as fallback only (cancel-timer pattern), tap-to-skip, and reduced-motion shows the final frame statically. Uncrowd's Lottie choreography is the model: letters rise and fade in left to right, the blue dot scales in last, about 1.67s, transparent background, built from the real logo paths. Klara's Lottie follows the same choreography, built from the real Klara logo paths, dot last. Final style approval is the owner's eyes (Uncrowd precedent: styles were previewed first and the real Lottie built only for an approved style — the overnight v1 uses this Uncrowd-style choreography and the owner approves or changes it on wake).

## Sources (key — full list in the research report)

- Android grids (official): https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units?hl=en
- Material 3 type scale: https://developer.android.google.cn/develop/ui/compose/designsystems/material3
- Material 3 Expressive announcement: https://9to5google.com/2025/05/13/android-16-material-3-expressive-redesign/
- M3 Expressive buttons extraction: https://github.com/albermonte/android-skills/blob/HEAD/skills/material-3-expressive/references/m3-buttons.md
- Apple Liquid Glass: https://www.apple.com/om/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- Liquid Glass Tinted fallback: https://www.macrumors.com/how-to/ios-26-1-reduce-liquid-glass-effects/
- Dribbble concept, Nexora: https://dribbble.com/shots/26702139-Fintech-Mobile-Banking-App-Nexora-Cards-Transfers-Wallet
- Dribbble concept, eSIM: https://dribbble.com/shots/27407458-The-Design-concept-for-the-eSim-Telecom-Mobile-App-UI
- 2026 trends round-up (Dribbble-sourced): https://www.elinext.com/services/ui-ux-design/trends/key-mobile-app-ui-ux-design-trends/
- Dribbble-driven-design warning: https://gmi.software/blog/mobile-app-design-trends
- Flat design baseline: https://www.manypixels.co/blog/illustrations/icon-trends
- Shipped cleaner patterns: https://www.makeuseof.com/photoswooper-fixed-my-messy-photo-gallery/ and https://www.appbrain.com/app/wipeclear-swipe-photo-cleaner/com.storage.phonecleaner.photoswipe
