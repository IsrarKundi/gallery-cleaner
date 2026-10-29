# Klara — Requirements

Status: FINALIZED from user decisions, 25 Oct 2026. Items marked OPEN still need a decision before the
related work starts. This file is the single source of truth for the build; the earlier research report
(artifact: swipe-clean-teardown-and-plan) and the screenshot teardown feed into it but do not override it.

## 1. Identity

- Working name: **Klara** (user decision, 25 Oct 2026). OPEN: verify on Google Play before listing —
  the previous working name "Swipe Clean" is ABANDONED because the competitor is literally named
  "Swipe & Clean" (near-identical name, same niche).
- App type: photo cleaning app for Android. One job: help the user decide the fate of every photo,
  quickly and without fear of losing anything.
- Tagline / store copy: OPEN (after name verification).

## 2. Platform and language

- Platform: **Android first** (Flutter). iOS is OUT of scope for v1 and belongs to a later phase —
  iOS handles deletion and trash differently, so it is a separate port, not a free extra.
- Language: **English only in v1**. Architecture MUST be i18n-ready from the start (all user-visible
  strings through localization files) so later languages are a translation job, not a rewrite.
  Localization itself is a later phase.

## 3. Gesture mapping (LOCKED, user decision 25 Oct 2026)

- Swipe LEFT = Keep
- Swipe RIGHT = Delete (mark for deletion — nothing is deleted by the swipe itself)
- Swipe UP = Maybe (decide later)
- Swipe DOWN = Favourite (protect)
- Buttons for all four actions must exist on the deck screen — no action may depend on gestures alone.
- First-run interactive tutorial AND persistent edge labels (KEEP / DELETE / MAYBE / FAVOURITE) are
  MANDATORY. Reason: this mapping is the opposite of the common convention in swipe cleaners
  (usually left = delete, right = keep), so users will otherwise guess wrong on destructive swipes.
- NOTE: mockups generated 25 Oct 2026 show the opposite mapping (DELETE left / KEEP right). They are
  SUPERSEDED by this section and must be regenerated before being used as design reference.
- AMENDED 26 Oct 2026 (owner decision, ADR-013, Clean deck only): a delete swipe still marks first,
  but the mark confirms after a 2-second undo window, or at once when the next photo is swiped —
  the photo then leaves the deck for the batched native trash run, and Review is no longer the
  mandatory gate for Clean-deck deletes. Smart decks keep the mark → review → native sheet flow
  unchanged. The native sheet remains the only path to Trash.
- AMENDED 27 Oct 2026 (owner decision, Wipe swipe rework): Gesture mapping defaults to
  Swipe RIGHT = Keep, Swipe LEFT = Delete. Vertical swipes (up = Maybe, down = Favourite) are
  completely removed from gesture input (Maybe and Favourite actions remain accessible via the
  bottom action bar). Edge labels are reduced to left and right edges. A "Swipe directions" setting
  in Settings allows switching between "Right = Keep, Left = Delete" (default) and
  "Right = Delete, Left = Keep", applied live immediately. While dragging, a bottom-anchored
  gradient tint appears on the photo card along with a large action icon and label (Keep / Delete).

## 4. Core flow (non-negotiable trust rules)

1. Swipe only MARKS a photo (keep / delete). No swipe ever deletes anything.
2. Review screen: editable grid of marked photos with counts and MB. User can unmark here.
   Photos are always shown revealed (no blur, no tap-to-reveal, no document guard). Long-press
   or the Select text button enters selection mode: taps then toggle selection, Select becomes
   Select all, and Keep/Delete act on the selection with its count (Keep X / Delete X); without
   a selection they act on the whole set (Keep all / Delete N). Back first cancels an active
   selection, then leaves the screen.
3. Android native confirmation: the system delete/trash sheet (MediaStore request) is the only path
   to Trash. The app must never claim a photo is deleted before this confirmation.
4. Trash: 30 days, recoverable. Restore (single + multi) must be visible and working.
5. Permanent deletion happens ONLY when the user empties Trash or the 30 days expire.
6. Three-state space accounting, shown everywhere (deck, review, trash, summary):
   Marked = "to be freed" (pending) / In Trash = "recoverable until [date]" (NOT freed) /
   Freed = only after emptying or expiry. Never report trashed MB as freed. Never use the word
   "permanent" while restore exists.
7. NEVER auto-delete. Every deletion is user-confirmed via review + native sheet.
- AMENDED 26 Oct 2026 (owner decision, ADR-013, Clean deck only): rule 7's "via review" no longer
  applies to Clean-deck deletes — the confirmation is the swipe decision plus its 2-second undo
  window (or the next swipe), and the native sheet still gates entry to Trash. Rules 3–6 stand
  unchanged: nothing is claimed deleted before the native sheet, Trash stays 30 days recoverable,
  and permanent deletion still happens only via emptying or expiry. This amendment CONFLICTS with
  the earlier "never skip review" rule; the owner's explicit 26 Oct 2026 order outranks it, and
  the conflict is recorded here and in ADR-013 rather than silently resolved.
- AMENDED 26 Oct 2026 (owner decision, ADR-014, Review delete is permanent): Review's delete button
  (bottom bar "Delete N photos" / "Delete X") permanently deletes photos via the native delete
  confirmation (MediaStore.createDeleteRequest on API 30+) instead of moving them to Trash.
  Permanently deleted photos never enter Trash and their space is counted directly as freed.
  Rules 4–5 no longer apply to Review deletes. Whole-set Review delete returns directly to the deck
  (never the Trash screen). Denied photos return to the deck. This amendment CONFLICTS with the
  earlier "every deletion enters Trash" rule; the owner's explicit 26 Oct 2026 order outranks it,
  and the conflict is recorded here and in ADR-014 rather than silently resolved.
- AMENDED 26 Oct 2026 (owner decision, ADR-015, Shell Trash tab shows union set): The shell Trash tab
  displays the union of Clean-deck delete-marked photos (pending + awaiting) and all smart-deck
  delete-marked photos (persisted sessions under 'smart:<deck>' and live SmartDeckController). Order
  is visit-stable: Clean deck first (awaiting then queued), followed by smart decks sorted
  alphabetically by session key with newest swipes last. All Review actions (unmark, keep, permanent
  delete, denied delete) sync back to the origin deck of each photo independently without corrupting
  per-deck sessions. Smart decks' own internal review flow from inside a folder continues to work
  scoped to its own set. Smart decks remain marks-only without an undo window.

## 5. Permissions and platform rules

- Scoped storage. READ_MEDIA_IMAGES / READ_MEDIA_VIDEO (Android 13+); Android 14 partial access
  (READ_MEDIA_VISUAL_USER_SELECTED) must be handled honestly: if the user grants only selected
  photos, the app works on exactly those and says so.
- The system photo picker is NOT sufficient for whole-library swiping (user-selection only) — the
  app needs media permission, not the picker, for the deck.
- If the user denies the native delete confirmation, those photos return to the deck with an
  explanation instead of silently vanishing from the queue.
- Do NOT request MANAGE_EXTERNAL_STORAGE: Google Play lists media-file access as an invalid use
  for it. No account, no sign-in, no photo upload — processing is on-device only.

## 6. Design

- Flat design, no gradients, no shadows-as-decoration (mockup direction, 25 Oct 2026).
- Semantic colour rule (applies to every palette): Keep = green family, Delete = red family,
  Maybe = amber, Favourite = heart filled with the primary colour. Delete must never share a hue
  with the primary brand colour.
- Colour palette: PICKED 25 Oct 2026 — Option B "Google blue"
  (primary #4285F4, Keep #0F9D58, Delete #DB4437, Maybe #F4B400,
  white background, Favourite = heart filled with the primary).
  Recorded in `design.md` §2; the earlier OPEN status here was
  stale and is corrected by this line.
- Dark mode: Phase 3 (light theme first).

## 7. Phases (user decision: build in phases)

### Phase 1 — Core (the complete cleaning loop, no extras)

Deck with 4-direction swipes + buttons; multi-step undo; month / album / folder filter; review
screen (counts + MB + editable grid); native confirmation; 30-day Trash; restore (single + multi);
deletion history; live three-state space meter on the deck; session resume per deck (remember
where the user stopped); thumbnail preloading for large libraries; first-run tutorial + edge
labels; English; Android; flat design. NO monetization code in Phase 1 (see §8).

### Phase 2 — Smart decks and retention

AMENDED 26 Oct 2026 (owner decision): the Smart decks hub is labelled "Albums" in the
app UI, and a single smart deck screen is labelled "Album". The internal feature name
("smart decks") and code names are unchanged — only the user-visible labels change.

Duplicate / similar grouping with changeable keeper (app suggests best shot, user may pick another);
blurry and dark photo detection; smart decks (Screenshots, WhatsApp, Downloads, Videos, Large
photos, Old photos 90+ days, Bursts); similarity slider; Maybe snooze (7 / 14 / 30 days); goals
("free 1 GB this week"); streaks; On This Day deck; session summary + shareable result card;
storage projection bar (device storage before → after).

### Phase 3 — Trust and polish

Private blur mode for trash thumbnails (review thumbnails are always revealed); favourites /
edited / starred protection toggle;
denied-confirmation and partial-access polish; large-library performance (50,000+ photos);
settings (theme, dark mode, notifications — one gentle weekly nudge only, haptics, reduced motion,
trash auto-empty preference); accessibility (buttons for every gesture, large tap targets);
no mid-session ads ever (applies whenever ads exist).

### Phase 4 — Later

Video compression (preview + keep original until user confirms); localization to multiple
languages; monetization implementation (once decided, see §8); iOS port.

## 8. Monetization — DEFERRED (user decision 25 Oct 2026)

No decision yet. Do not build a paywall, subscription, or ads in Phase 1. A monetization decision
(model + prices) is REQUIRED before the Play listing. Standing guidance from research, to revisit
then: free tier must complete a real cleaning session with no card and no trial countdown; avoid
weekly subscriptions (user backlash + Play's "sustained or recurring value" rule for subscriptions
makes a one-off cleanup a poor fit for recurring billing); lifetime-first was the recommended
direction, but it is NOT locked.

## 9. Explicitly OUT of scope for now (user decisions 25 Oct 2026)

- Backup badge ("is this backed up?") — NO backup badge for now. Reason: Android offers no
  official per-photo backup-status API, so an automatic badge cannot be verified. May revisit with
  a manual per-deck confirmation design.
- iOS (Phase 4).
- Cloud backup / sync, photo editing, gallery replacement.
- Auto-delete of any kind.

## 10. Open decisions (must be resolved before the work they block)

1. ~~Final colour palette (user pick pending).~~ PICKED 25 Oct 2026
   (Option B Google blue — see §6).
2. Name verification on Google Play ("Klara").
3. Monetization model + prices (before listing).
4. Store listing copy, icon, and screenshots (after palette + name).
5. Order of Phase 4 items.

## 11. Sources

- Competitor teardown from user-shared screenshots (25 Oct 2026): competitor "Swipe & Clean",
  17 features, 12 ranked UX problems.
- Market research (deep research, 25 Oct 2026) and report page (artifact swipe-clean-teardown-
  and-plan): competitor table, Android deletion mechanics, monetization backlash patterns,
  differentiation gaps.
