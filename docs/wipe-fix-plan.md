# wipe. Fix Plan v2 — detailed, built ONLY from what Cleanup actually does

Status: **DRAFT — waiting for the user's approval. No coding starts before approval.**
Date: 30 Oct 2026
Sources: Cleanup teardown (~/workspace/cleanup-teardown/TEARDOWN.md + notes/pipeline.md, notes/algorithms.md, notes/retention.md) and our own app audit (~/workspace/klara-performance-audit-report.md).

## How this plan is written (the rule the user set)

Every stage has four parts:

1. **What Cleanup does** — only things we actually saw in their app (code, settings, or their own text inside the app).
2. **What wipe. does today** — from our own audit.
3. **The exact change** — only the parts that come from point 1. Nothing invented.
4. **What Cleanup does not tell us** — where their app hides the answer, we say so. Those points are left open for the app owner (you) to decide once, NOT filled in by guessing.

Hard rules (unchanged): our own code only, never Cleanup's code. No ads, trackers, daily limits, or paywall tricks. Swipes only mark photos; deletion still needs review + Android's confirm.

**Execution rule (owner, 30 Oct 2026):** while executing this plan, if the executor gets stuck on any point — a behaviour, a value, a detail the plan doesn't spell out — **do not assume or guess**. First go back to Cleanup (the teardown, the notes, the app itself) and see how Cleanup does that exact thing, and follow the evidence. Every time this happens during execution, it must be **named in the final report** to the owner: what the stuck point was, what Cleanup showed, and what was done with it.

---

## Stage 1 — Notifications and reminders

### What Cleanup does (seen in their app)

**The system parts:**
- They use scheduled local notifications (the `flutter_local_notifications` plugin).
- Their Android manifest declares two receivers: one that fires scheduled notifications, and a **boot receiver** that re-registers all reminders after the phone restarts or the app updates (actions: BOOT_COMPLETED, MY_PACKAGE_REPLACED).
- Permissions they declare for this: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, WAKE_LOCK, VIBRATE.

**How they ask for permission:**
- Not with a bare system popup first. The ask sits in a permission sheet with a one-line benefit. Their words: title "Notifications", subtitle **"Storage advice & notifications. Easy to manage anytime."**
- A second popup version: "Allow Notifications" — "Don't miss newly released prompts special offers and more by allowing notifications."

**The messages — this is the important part. There is no weekly/daily clock reminder in Cleanup. Every message is sent because of a STATE the user left behind:**

| # | User's state (= when it is sent) | Cleanup's title | Cleanup's message |
|---|---|---|---|
| 1 | Photos were moved to Trash but the trash was never emptied | "Your trash bin is waiting!🗑️" | "Photos are still in the trash. Come back and delete them!" |
| 2 | A scan finished, duplicates were found, but the user deleted nothing | "Scan is complete ✅ Don't wait!" | "You've found duplicates but didn't delete them. Free up storage now!" |
| 3 | A scan was started and left unfinished (first time) | "Come back to finish finding duplicates!👯‍♀️" | *(no subtitle found in their text table)* |
| 4 | A scan was started and left unfinished (with numbers) | "Don't miss out! Reclaim more storage now!☁️" | "%@ photos and %@ videos are ready to be deleted—come back and remove them with one tap!" (the two %@ are real counts from the user's phone) |
| 5 | User installed the app but never tried swiping | "Try photo swiping today!🤏🏻" | "Declutter your gallery with a simple swipe to remove unwanted photos." |
| 6 | User never tried the contacts cleaner | "Get rid of duplicate contacts with ease!📇" | *(no subtitle found)* — **not used for wipe.: we have no contacts feature** |

Read as a story, the order is a ladder: never tried it → started but didn't finish → finished but didn't delete → deleted but didn't empty the trash. Each unfinished step gets exactly one matching message.

### Chosen message copy for wipe. (draft picks — from the owner's rephrased set, 30 Oct 2026)

The owner provided rephrased versions of Cleanup's messages (a primary + two alternatives per state). Picks below — these are DRAFT picks while the plan is still under review, not final approval of the plan.

| wipe. state | Chosen title | Chosen message | Why this one |
|---|---|---|---|
| 1. Photos waiting in the Trash tab | "Finish what you started 🗑️" (Alt B) | "Your trash is still full. Empty it now and see how much space you get back." | Matches the unfinished-work idea and our own "Trash" tab name |
| 2. Deck finished, photos found, nothing deleted | "Your results are ready ✅" (primary) | "We found duplicates eating up your storage. Review and clean them up in seconds." | Clear benefit, no false promise |
| 3. Deck/scan left unfinished, first time | "Curious what we'll find? 👀" (Alt A) | "Your scan is paused. Finish it and see what's taking up your space." | Honest — does not claim the scan is "almost done" when we don't know how far it got |
| 4. Still unfinished, with real counts | "Ready to clean up? ✨" (Alt B) | "%@ photos and %@ videos are lined up for deletion. Open the app and finish the job." | The only variant with no "one tap" claim — wipe. always has review + confirm steps, so "one tap" would not be true |
| 5. Installed, never swiped | "Fun way to declutter ✨" (Alt A) | "Swipe through your photos and say goodbye to the ones you don't need." | No swipe directions in the text — see the warning below |

**Skipped, and why:**
- **State 6 (contacts), all variants** — wipe. has no contacts feature.
- **State 5 primary** ("Swipe left to delete, swipe right to keep") — **wrong directions for wipe.** That is Cleanup's mapping. wipe.'s locked mapping is the opposite: **left = Keep, right = Delete**. If a message ever names directions, it must say "swipe left to keep, swipe right to delete."
- State 1 primary / Alt A — they call the photos "deleted" before they are (in wipe. they are only marked and waiting).
- State 4 primary / Alt A — "one tap" is not true for wipe.'s review-first flow.

All chosen titles are under 40 characters, so they will not be cut off on a lock screen.

**One more piece, inside the app:** if the user tries to leave while photos sit in the Trash, Cleanup stops them with a popup: "Are you sure you want to leave?" — "There are some photos in the Trash Bin. Review and delete permanently." Buttons: "Open Trash" / "Save and Exit".

**What Cleanup does NOT tell us:** the exact waiting time before each message (hours/days after the state starts) is NOT readable in their app — the scheduling values are not plain constants in the code we can inspect. Their trial-reminder messages (40 text keys about a free trial ending) exist too, but wipe. has no trial, so they are excluded.

### What wipe. does today

- One weekly reminder, same for everybody, not based on what the user left unfinished.
- The reminder's receivers are **already in our Android manifest** (audit finding F-33 was fixed before this plan was executed): the scheduled-notification receiver, the boot/update receiver (BOOT_COMPLETED, MY_PACKAGE_REPLACED) and RECEIVE_BOOT_COMPLETED are all declared.
- No state-based messages. No "are you sure you want to leave?" popup. Permission is not introduced with a benefit line like Cleanup's sheet.

### The exact change

1. Use the same two receivers Cleanup uses (scheduled-notification receiver + boot/update receiver) — already declared in our manifest (see above), so no manifest change is needed: reminders fire and survive a phone restart.
2. Replace the single weekly reminder with state-based reminders, using the same states, mapped to wipe.'s own flow:
   - Cleanup state 1 (trash waiting) → wipe.: **photos marked and still waiting in the Trash tab** (our waiting room before deletion). Message meaning stays the same: "you have photos waiting — come back and finish."
   - Cleanup state 2 (scan done, nothing deleted) → wipe.: **a deck was finished (for example Duplicates) and photos were found, but nothing was marked/deleted.**
   - Cleanup states 3+4 (scan unfinished) → wipe.: **a deck was started and left part-way.** The numbers version shows the real count of photos waiting, like theirs.
   - Cleanup state 5 (never swiped) → wipe.: **app installed, photos allowed, but no first swipe session yet.**
   - Cleanup state 6 → skipped (no contacts feature in wipe.).
   - The message words will be our own simple words with the same meanings — we do not copy their sentences.
3. Add Cleanup's leave-guard in our words: leaving Review with photos still waiting shows a popup — "Open Review" / "Save and Exit".
4. Ask for the notification permission the way Cleanup does: inside a permission sheet with a one-line benefit, before the system popup.

### Reminder times — DECIDED by the app owner (approved 30 Oct 2026)

Cleanup hides its times, so these are wipe.'s own chosen numbers, approved by the app owner. The app follows them by itself, for every person who uses wipe. The person using the app does NOT set these times — they only choose reminders on or off.

| State | First reminder | One last repeat |
|---|---|---|
| 1. Photos waiting in the Trash tab (marked, not deleted yet) | after **1 day** | after **3 more days**, then stop |
| 2. Deck finished, photos found, nothing deleted | after **1 day** | after **3 more days**, then stop |
| 3. Deck started, left unfinished (simple message) | after **1 day** | — (state 4 is the repeat) |
| 4. Still unfinished (message shows the real count of waiting photos) | after **3 more days** (day 4 in total) | then stop |
| 5. App installed, never swiped even once | after **2 days** | after **5 more days** (day 7 in total), then stop forever |

Rules that go with the times:

- Never more than **1 reminder in a day**, even if two states are true at once — send only the most important one (state 1 first).
- Reminders come at a **normal hour** (early evening), never at night.
- If the person opens the app and finishes the work, the reminder is **cancelled** — it never comes.

---

## Stage 2 — Loading photos and scanning

### What Cleanup does (seen in their app)

- **One query per type.** Photos come from one MediaStore query, videos from one MediaStore query. No paging, no limit. The single query already returns: id, file name, folder name, **file size, width, height**, date added, date taken, date modified, favourite flag, and path info. Sort: newest first (`date_added DESC`). Only files with size > 0.
- **Sorting into types happens during that same pass**, using the name/folder that already came back:
  - A photo is a **screenshot** if its lower-case file name contains `screenshot`, `screen_shot`, or `screen-shot`, or starts with `screenshot_` or `screen_`. (Name rule only — no image reading.)
  - Chat photos are tagged by folder name (WhatsApp, Telegram, Snapchat, Messenger).
- **The scan runs in the background.** The "start scan" call answers instantly; a guard flag means pressing start twice does not start two scans. Results are written to files, and the screens watch the files for results.
- **Checking a photo never reads the full photo.** The fingerprint is made from a thumbnail of at most **1024×1024** px. Blur checking is a **separate second pass**, at most **8 photos at a time**.

### What wipe. does today

- Loads in pages of 50, and for every page it asks for each file's size **one by one** (50 separate slow calls per page), and re-lists the library again for each new screen (audit F-04).
- Photo analysis runs on the screen's own thread, which is why the app can feel stuck (F-20).
- Screens each start their own full scan; scans are not shared and cannot be cancelled (F-05 in the audit's scan findings).

### The exact change

1. One list pass per type that brings size, width, height, and dates **with the list itself** — the per-photo size questions stop completely.
2. Mark screenshots during that same pass, using Cleanup's exact name rules above.
3. One shared scan for the whole app, running in the background, with Cleanup's "already running" guard — screens read its results instead of rescanning.
4. All photo checks (Stage 4) read a thumbnail of at most 1024×1024, never the original photo. Blur stays a separate second pass with a small number of photos at a time (Cleanup uses 8).
5. **Loading screens (owner decision, 30 Oct 2026):** an earlier idea — show a mascot clip on loading screens and comment out the skeleton — was **dropped by the owner**, who decided clearly: **for loading we stick to skeletons.** The existing skeleton loading screens stay exactly as they are.

### What Cleanup does not tell us

- Nothing important here — this part of their design was fully visible. (Their scan engine is native Kotlin code; ours will be our own code doing the same steps. If our current photo plugin cannot return size in the same pass, we add a small native query of our own — same idea, our code.)

---

## Stage 3 — How progress and results are saved

### What Cleanup does (seen in their app)

- **No database.** Three files:
  - `assets.json` — every known photo/video with its info (id, type, favourite, edited, width×height, dates, size on disk, folder id, chat source).
  - `folders.json` — the groups (Similar, Duplicates, Blurred, …), each with its member list.
  - `duplicateReference.json` — for each duplicate set: which photo is the main one, and which photos are its duplicates.
- **Every save is done the safe way:** write the new content to `<name>.json.tmp`, force it to disk (flush + sync), then rename it over the old file. If the rename fails, they copy instead. A crash mid-save can never leave a half-written file.
- **Hashes are NOT saved.** Only the group memberships above are saved. A photo's fingerprint is made again only when that photo actually has to be compared with another one (see Stage 4) — and if a rescan changes no memberships, no photo is read again at all.
- Swipe progress and small counters live in a separate small store (Hive boxes per feature — swipe progress, folder progress, review counters), not inside the three big files.

### What wipe. does today

- The whole sessions file is rewritten after **every single swipe** (audit F-08: calculated ≈27.5 GB of writes over 50k marks), and the analysis file is rewritten for every scan page (F-09).
- Writes are not atomic — a crash at the wrong second can damage the file.

### The exact change

1. Every save switches to Cleanup's write-temp-then-rename method. No exceptions.
2. Save the same three kinds of things Cleanup saves: the photo info list, the group memberships, and the duplicate main→members map — instead of one growing sessions file for everything.
3. Swipe marks go to their own small store (like Cleanup's per-feature boxes), so one swipe = one tiny save, never a full rewrite.
4. Follow Cleanup on hashes: **do not save them.** Save memberships; make fingerprints only when a comparison needs them.

### Taken OUT of the old plan (v1)

- The v1 plan suggested moving to a database (SQLite) and saving fingerprints to beat Cleanup. Cleanup uses neither — those were our additions, so they are removed.

### Stage 3 execution note (30 Oct 2026, ADR-018)

- Done: every JSON save now uses Cleanup's full atomic pattern (tmp + sync + rename + copy fallback) via one shared writer; swipe marks and favourites moved out of the per-session blob into their own per-row tables (schema v2, transactional no-loss migration from both the v1 database and the old JSON files), so one swipe writes one small mark row and commits immediately — no batching window.
- Recorded difference from the plan text: the plan was written against the audit-era files, but the repo's own Phase 6 had already put a database under the app before this stage ran — the stage reshaped the stores inside that reality (marks out of the blob) instead of replacing the database with files.
- Deferred to Stage 4 as a recorded stuck point (ADR-018 Decision 5): the asset-info / membership / duplicate-reference reshape and removing the saved hash. Today's slider regrouping, keeper scores, and the scanner's freshness rule genuinely depend on the saved hash; Stage 4's comparison-time fingerprints are what make memberships sufficient. The hash stays until then BY RECORDED DECISION, not by oversight.

---

## Stage 4 — Finding similar photos, duplicates, and blurry photos

### What Cleanup does (seen in their app — the numbers are exact)

**Each photo gets a two-part fingerprint** (made from the ≤1024 px thumbnail, Stage 2):
1. A 64-bit "shape" fingerprint (a difference hash — it captures the layout of light/dark areas).
2. A **colour summary**: for each of the red, green, and blue channels, a histogram folded into 8 brightness bands → 24 numbers, each divided by (width × height) / 16.

**Two photos are "similar" only if ALL of these hold** (same type first — photos only compare with photos, screenshots with screenshots):
- Count how many bits differ between the two shape fingerprints = **d**.
- **Normal photos (and video frames):**
  - d must be **less than 18**.
  - If d is **0–4**: similar, no colour check needed.
  - If d is **4–10**: similar only if the colour distance is **≤ 7**.
  - If d is **10–18**: similar only if the colour distance is **≤ 5**.
- **Screenshots (stricter):**
  - d must be **less than 16**.
  - If d is **0–2**: similar, no colour check.
  - If d is **2–10**: colour distance **≤ 5**.
  - If d is **10–16**: colour distance **≤ 2**.
- Colour distance = add up the differences of all 24 colour numbers.

**Grouping:** sort photos by date. Take the first photo as the **seed**. Every photo that matches **the seed itself** joins its group (matching a different member is NOT enough). Then take the next ungrouped photo as a new seed. Groups of 1 are thrown away.

**Exact duplicates** are a separate, stricter rule: same type + same width×height + same shape fingerprint + same edited flag + same file size — all equal, or it is not a duplicate.

**Blurry photos** are found in the separate pass (Stage 2), from the photo file read at a small size (**512**). Three sharpness measures are combined:
`score = reBlur weight × reblur + 1.0 × edgeWidth + coherence weight × coherence`, and the photo is blurry if `score ≥ threshold`.
The fallback numbers inside their code are **reBlur weight 2.3, coherence weight 0.75, threshold 2.2** (edge width always counts ×1.0).

**What Cleanup does NOT tell us:** their live blur weights/threshold come from their server, so the numbers above are only their built-in fallbacks. Also, Cleanup shows a "Best" badge on one photo per group, but the rule for choosing it is inside compiled code we cannot read — only its ingredients are visible (blur score, photo size, resolution, favourite, edited). **We will not invent a "best photo" rule.**

### What wipe. does today

- One single weak fingerprint (an average hash) and **one rule for every type** — screenshots and photos are treated the same, there is no colour check, and grouping is not seed-based (audit, similarity findings).
- The work runs on the screen's thread with full-size reads in places (F-20).

### The exact change

1. Build the same two-part fingerprint (shape + colour summary) — our own code, Cleanup's recipe and numbers above as the starting point.
2. Use Cleanup's exact compare table, including the stricter screenshot rule (screenshots are identified in Stage 2 by name).
3. Group exactly the Cleanup way: date order, seed-only matching, groups of 1 dropped.
4. Duplicates by Cleanup's exact-key rule.
5. Blur as its own pass at size 512 with Cleanup's formula and fallback numbers as the starting point; before this stage is called finished, we test on our own sample photos and show the user the results (because Cleanup's real numbers are server-side, ours must be proven on real photos, not trusted blindly).
6. All of this runs in the background, never on the screen thread (Cleanup's scan is background-only — Stage 2).

### Stage 4 execution note (30 Oct 2026, ADR-019)

- Done: the matching engine is replaced with Cleanup's rules, all as wipe.'s own code — two-part fingerprint (64-bit difference hash + 24-number colour summary) from the ≤1024 px thumbnail; the exact compare table per class (colour distance truncated first, fast-accept band checked first, bands in order; photos d<18, screenshots d<16 with the stricter colour caps); seed-only grouping in date order with groups of 1 dropped; exact duplicates by the full key (type + dimensions + shape fingerprint + edited flag + file size); blur as its own second pass at 512 px with the fallback formula 2.3 × reblur + 1.0 × edgeWidth + 0.75 × coherence, blurry at ≥ 2.2.
- Stage 3's deferred item is landed: grouping moved into the scan, and the persisted product is memberships (asset-info facts / group memberships / duplicate reference) in schema v3 — the persisted hash is REMOVED (the analyses table is dropped; legacy rows convert to facts only at version 0 and are rescanned, never converted into groups). Saved memberships are reused only when every asset-info fact still matches the live library; a cancelled or page-failed scan never overwrites them.
- The similarity slider is REMOVED (owner approval, Stage 7 decision given early): the Duplicates screen now shows the scan's exact-duplicate groups; the Similar deck is fed by the seed groups; the Blurry deck by the blur pass. Requirements §7 amended in the same change. Stage 7 still owns the Duplicates screen layout redesign.
- Smart-deck membership now uses Stage 2's file-name screenshot marking (Stage 2's deferred item), so photos and screenshots group separately for real.
- Sample-photo blur validation (plan item 5) was run on the free-license store photos plus PIL Gaussian variants at radii 1/2/4/8: scores rise monotonically with blur for every photo and every blurred variant is flagged — but ALL FOUR sharp originals are also flagged (2.62–3.78 vs the 2.2 threshold). Recorded as a stuck point, NOT silently retuned: the fallback weights/threshold were calibrated against Cleanup's own measure scales, and the three native measure formulas are unknown. The owner's calibration decision is parked in the stage report.
- Recorded modelling choices (ADR-019): the dHash bit convention is ours (native convention unobservable; only self-consistency matters); the edited flag is false (no enumeration — ours or Cleanup's Android side — carries one); the keeper rule is the pre-existing one fed by the new blur score (lowest score = sharpest; unscored below scored); blur measures are the classic gradient-domain measures the recovered names denote.

---

## Stage 5 — The finish screen and the review ask

### What Cleanup does (seen in their app)

- After a clean, a **"Congratulations!"** screen lists what happened: "You have deleted …", "You saved …", and a "saved time" line. During cleaning there is a live counter: **"Storage freed so far"**.
- Deck states have names: "To Be Cleaned", "In Progress", "Total Photos", and there is a "{} photos in the trash" counter.
- **Resume:** a popup "Continue where you left off?" — their text: "Cleanup remembers your changes, so it will scroll to where you left off for effortless cleaning." Their app reopens a deck at the exact place the user stopped.
- **Review ask:** the app **counts swipes and deletes separately**. When a count passes a limit, it asks — **at most once per place** (home / swipe / delete are counted separately). It is two steps: first their own sheet — "Thanks for using Cleanup!" / "Are you enjoying Cleanup? Please don't hesitate to leave a review!" — and only happy users go to the store prompt; unhappy users get a feedback form ("Tell us what you think") instead.

**What Cleanup does NOT tell us:** the exact counts (how many swipes/deletes before asking) are settings from their server, not readable in the app.

### What wipe. does today

- The space-freed numbers are already calculated in our code, but the payoff view is switched off (audit F-29).
- Tab switches throw away screen state, so "continue where you left off" is not guaranteed (audit, navigation findings).
- There is no review ask at all.

### The exact change

1. A finish screen after each delete batch showing the two honest numbers Cleanup shows: **how many photos were deleted** and **how much space was freed**. (Their third number, "saved time", is NOT copied — we have no honest way to measure it.)
2. Decks reopen at the exact photo where the user left, with the same "continue where you left off" behaviour.
3. A review ask built the Cleanup way: count swipes and deletes separately, ask at most once per place, two steps (our own sheet first, store only for happy users, feedback for unhappy users).

### Review-ask counts — DECIDED by the app owner (approved 30 Oct 2026)

Cleanup hides its counts, so these are wipe.'s own numbers, chosen by the app owner. The system is Cleanup's: count swipes and deletes separately, ask once per place, two steps (our own sheet first — store only for happy users, feedback form for unhappy users).

| Place | Ask when |
|---|---|
| After deleting (on the finish screen) | the person has deleted **more than 10 photos in total** — asking is allowed already on the **first** clean |
| After swiping (when a deck session ends, never in the middle) | the person has done **60 swipes in total** |
| Home screen | the person has used the app on **3 different days** and deleted something at least once — only if the two asks above never happened |

Rules that go with the counts:

- **Once per place, ever.** If a place already asked, it never asks again.
- If the person closes the ask without answering, that place may ask again only after **double** the work (this doubling is Cleanup's own multiplier trick): deletes 10 → 20 → 40; swipes 60 → 120 → 240.
- If the person gave a review or feedback, **no ask ever comes again**, in any place.

### The small winning details on these screens (from Cleanup's own asset files)

(Research note: ~/workspace/cleanup-teardown/notes/delight-assets.md. The IDEA is Cleanup's; every picture stays wipe.'s own — Cleanup's image files are their artwork and are never used, same rule as their code. wipe.'s versions use our own small artwork in our flat style. The finish-screen picture is DECIDED (the Fluent popper, below) and the review-sheet picture is DECIDED too (the owner's heart-paws kitten, below); only the delete-moment picture is still the owner's open choice; an earlier mascot idea (Miso) was dropped by the owner on 30 Oct 2026 and is NOT part of this plan.)

- **Finish screen:** Cleanup puts a celebration picture (party popper) on top, then two stat rows, each with its own small icon: "You have deleted …" and "You saved …". **wipe. version:** the **Fluent Emoji flat party popper** on top of our finish screen — **DECIDED by the owner, 30 Oct 2026** (from Microsoft's Fluent Emoji set, MIT license: free to ship in the app, no credit needed; the vector file is 4.4 KB, kept at ~/workspace/empty-assets/congrats/fluent_popper.svg; screen mockup in wipe.'s design: congrats_screen_A_popper.jpg in the same folder), then our two honest rows (deleted count; space with its true state — "in Trash until [date]", never "freed" early). Cleanup's extra "saved time" row stays out (Stage 5 already decided). One honest line worth copying as an idea: even Cleanup's congrats screen reminds people that space is really freed only when the system trash is emptied — our screen says the same in our words.
- **Review sheet:** Cleanup's sheet is built around a **cute cat picture with five gold stars**, plus a small **animated star strip** (a 3-second Lottie). Their text: "Thanks for using Cleanup!" / "Are you enjoying Cleanup? Please don't hesitate to leave a review!" / buttons "Let's Go!" and "Maybe Later". **wipe. version — DECIDED by the owner, 30 Oct 2026:** the picture is the owner's own **heart-paws kitten** photo (picked from 5 kittens the owner supplied; background removed; cutout at ~/workspace/empty-assets/rateus/cut/kitten3_heart_paws.png). The five stars are **soft, rounded, gradient gold**, redrawn to match a reference screenshot the owner supplied (stars_soft.svg in the same folder; static first, animation only as a later extra). The words are the owner's own copy: **Title: "You just freed up {X} GB"** ({X} = the real amount from that clean; the mock shows 2.4 GB) — **Body: "Enjoying your extra space? Show wipe. some love with a quick rating!"** Buttons stay "Let's Go!" / "Maybe Later". Final mock: ~/workspace/empty-assets/rateus/final_rateus_heartpaws.jpg. (Build-time consistency note: the finish screen words the same amount as "in Trash until [date]" — this sheet uses that same real number.)
- **The delete second:** Cleanup plays a **2-second animation** the moment a deletion finishes (their final_delete_lottie). **wipe. version:** when the Android confirm succeeds, a short celebration moment of our own (~2 seconds; artwork: owner's choice, still open) before the finish screen.
- **Empty screens:** Cleanup gives **each empty screen its own illustration** ("There are no photos to clean up!"), not one generic icon. **wipe. version:** a picture ONLY on the two empty screens the owner chose — **History** and **Trash**; every other empty screen keeps the plain icon it has today. (Owner scope + style, 30 Oct 2026: the earlier 10-picture set AND a second drawn set were both rejected; the owner then supplied a reference image and chose its style — soft light-blue shaded, semi-3D, transparent background. TRASH: bin with leaning lid drawn in that style, ACCEPTED by the owner (~/workspace/empty-assets/refstyle/trash_refstyle.svg, ~2 KB; mock: trash_screen_mock.jpg). HISTORY: calendar drawn in the same style (~/workspace/empty-assets/refstyle/calendar_refstyle.svg, ~2.5 KB; mock: history_screen_mock.jpg). **BOTH ACCEPTED by the owner, 30 Oct 2026 — "we use these."**)
- **Waiting/loading screens:** unchanged in this plan — the existing skeleton stays (see Stage 2, point 5).
- **During the work:** Cleanup shows a live **"Storage freed so far"** counter while cleaning. **wipe. version:** our meter already exists ("To be freed" / "Freed" — Stage 5 restores it); it keeps our three honest states separate (marked is not freed).

### Stage 5 execution note (30 Oct 2026, ADR-020)

- Done: the finish screen (Fluent popper + the two honest rows — count, and space as "Freed from your storage" for a Review batch or "In Trash — freed on [date]" for a trash batch, the date read back from the recorded Trash entries; no saved-time row); the deck's live three-state meter restored (F-29a only — the other switched-off payoff surfaces stay as the owner left them); resume fixed so a reopened deck lands on the exact left-off photo even across page boundaries; the counted review ask in all three places with the owner's numbers (deletes > 10, swipes ≥ 60, home at 3 days + a delete and only if the others never fired; dismissal doubles 10 → 20 → 40 and 60 → 120 → 240; a review or feedback anywhere silences all places forever), two steps — the decided kitten sheet, then the Play in-app review prompt (`in_app_review` added), or the feedback form for unhappy users; History and Trash empty states carry the two accepted pictures, every other empty screen untouched.
- "Delete batch" is mapped to the app's two real completion points (ADR-020 decision 1): a whole-set Review permanent delete that empties the grid (partial/mixed runs keep their existing snackbar/dialog endings), and the Clean deck's batched trash completion (`flushAwaitingTrash`). The flush's former shell trigger was removed by the owner in 306f75d — Stage 5 hooks the completion, never a new trigger, so the finish screen + counting are live the moment any trigger exists, and committed Clean photos today still complete through the Review union exactly as the owner set it up.
- Counters are seeded once from real records (history counts + photos currently in Trash; marks across all persisted sessions; completion days ∪ history days), then counted at the real events. The sheet's amount is the finish screen's own number at the delete place; the just-ended session's delete-marked bytes at the swipe place; the last batch / lifetime freed at home — always a real recorded number.
- Stuck point, recorded loudly: the app has NO support/feedback channel anywhere (no address in the repo; the Settings feedback string is unused). The feedback form therefore submits through the system share sheet — the user sees the text, picks the destination, and sends it themselves; nothing is sent silently. A real support inbox is the owner's decision to add. The decided sheet design has only two buttons, so the unhappy path is a quieter third text action under "Maybe Later" ("Not happy? Tell us what's wrong") that swaps the same sheet to the form.
- NOT built, per the stage scope: the ~2-second delete-moment celebration — its artwork is still the owner's open choice. The hook points are the two completion branches above (a moment would slot in immediately before the finish route opens). No placeholder artwork ships.
- Requirements §4 and §7 and design §6 amended in the same change; the golden-path test now walks through the finish screen. Verification: analyze clean; 700 pass / 20 fail / 1 skipped — the failing set is exactly the pre-existing baseline 20, with 58 new Stage 5 tests passing.

---

## Stage 6 — Similar Videos

### What Cleanup does (seen in their app — settings are exact)

- Only videos of **400 MB or smaller** are checked.
- From each video, take still frames spread **2 to 10 seconds apart**: normally **7 frames**, at most **13**.
- Each frame is shrunk to **9×8 px** and fingerprinted with the same shape+colour method as photos (Stage 4), using the normal-photo compare rule.
- **Two or more matching frames = the videos are similar.**
- (Their settings also carry a 100 MB "big file" mark, used to flag large videos.)

### What wipe. does today

- No similar-videos feature. Videos are only a size/type deck.

### The exact change

- A new **Similar Videos** deck that uses Cleanup's sampling numbers above as the starting point (≤400 MB, frames every 2–10 s, 7–13 frames, ≥2 matching frames), our own code, tested on sample videos with the results shown to the user before the stage counts as done.

---

## Stage 7 — Duplicates screen: Cleanup's layout, wipe.'s own clothes

(Research note with all evidence: ~/workspace/cleanup-teardown/notes/duplicates-ux.md. This stage changes how the screen LOOKS and FLOWS only — the finding maths is Stage 4, and this stage comes after it.)

### What Cleanup does (seen in their app)

From their own Play Store screenshot of the duplicates screen, plus their text table:

- The screen opens with the results, not with controls. Header: "Duplicate Photos", and under it one summary line: **"235 photos · 2.4GB"** — how many photos and how much space, before anything else.
- Groups are cards in a list. Each card's header: **"3 Duplicates"** on the left, the group's total size (**"2.5MB"**) on the right.
- The photos inside a group are **large, side by side, two per row, filling the card width** — you can compare them at a glance.
- The suggested keeper has a **"★ Best" badge** on the photo. Every other photo is **already selected for deletion**, shown by a round checkbox on the photo (filled red check = will be deleted, empty circle = will not).
- One **sticky button at the bottom** carries the live totals: **"Delete 147 Duplicates (Save 2.4GB)"**.
- One short explanation line per folder type (theirs for duplicates: "These are identical copies of the same photo. Remove all duplicates in one go while keeping the originals."), plus "Select All / Deselect All" controls.
- **There is no slider and no "distance" number anywhere in their screen.** The user never sets a sensitivity — the rule (Stage 4) just works.

### What wipe. does today (from our code)

- The screen opens with a **"Similarity" slider (0–10)** and the value shown as a raw number ("Distance 5"), plus a hint line. A technical control is the first thing the user meets.
- Each group card repeats the same helper sentence ("Tap a photo to make it the keeper") on every single card.
- Photos are **small squares** — hard to compare two photos properly.
- The keeper is a green border + a "Keeper" strip (works, but quiet). Nothing on the other photos shows they will be marked — that only happens when the card's button is pressed.
- Every card has its **own secondary-style button** ("Mark others for deletion"). There are **no totals anywhere**: no summary at the top, no bottom bar — the user must add up each card in their head.

### The exact change (Cleanup's layout, translated into wipe.'s design system)

**Hard rule for this stage: only the layout and flow change. The look stays 100% wipe.** — the app's own design tokens (design.md), flat style, Inter text styles, the locked colours (#4285F4 primary, #0F9D58 keep/success, #DB4437 delete/error), the same AppScaffold and card style as the app's other screens. No dark theme, no gradients, no gloss from Cleanup's screenshots. If the build later needs a new size token, it is added in the token files like every other size in this app — never a raw number in the screen code (repo rule).

1. **Summary at the top:** under the "Duplicates" title, one line with the totals, Cleanup-style: how many duplicate photos (the non-keepers across all groups) and how much space they take.
2. **The slider goes away.** When Stage 4 lands, the rule is fixed (like Cleanup) and there is nothing for a slider to control. (Until Stage 4, this stage does not start.)
3. **Group card header:** "N duplicates" on the left, the group's size on the right — no helper sentence repeated per card. One short explanation line sits once, under the top summary.
4. **Photos large, two per row**, filling the card width, so two versions can really be compared.
5. **Keeper badge:** the suggested keeper gets a clear pill badge on the photo — our existing word "Keeper", in our success colours. Tapping any photo still makes it the keeper (today's behaviour, unchanged).
6. **Selection marks on the photos:** every non-keeper shows a round mark on the photo — filled delete-colour check = will be marked, empty circle = will not. Non-keepers start selected, like Cleanup. Tapping the mark (not the photo) spares or re-selects that one photo.
7. **One sticky bottom button** with live totals, in our words and our flow: **"Mark N duplicates for review · X GB"**. It marks and goes to Review — it never deletes directly, because wipe.'s trust flow (review → Android confirm) does not change. The per-card buttons are removed.
8. "Select all / Deselect all" for the whole list, like Cleanup's controls.

### What Cleanup does not tell us

- Groups bigger than 2 photos: their screenshot only shows pairs fully — we use the same two-per-row grid and let it wrap; nothing new invented.
- Whether tapping a photo opens a full-screen compare view: no evidence — NOT included.

---

## Left out on purpose (Cleanup gives no example, or it is not for wipe.)

- **Keeping tab state when switching screens** — real problem in our audit, but Cleanup shows no example of it. Removed from v1.
- **A database** — Cleanup uses files, not a database. Removed.
- **Saving fingerprints between scans** — Cleanup deliberately does not. Removed (v1 wanted to "beat" them here; that was our addition).
- **Daily caps, ads to unlock deletes, paywalls, trial reminders** — Cleanup does these; the user already decided wipe. will not.
- **Contacts cleaner and its reminder** — not a wipe. feature.
- **A "best photo" rule** — Cleanup's is hidden; we will not invent one.
- **Notification times** — hidden in Cleanup, so not guessed: the app owner chose wipe.'s own times instead (Stage 1, approved 30 Oct 2026). **Review-ask counts** — hidden in Cleanup, so not guessed either: the app owner chose wipe.'s own counts (Stage 5, approved 30 Oct 2026).

## Order and approval

Stages run in order 1 → 7, each tested before the next begins (Stage 7 needs Stage 4's fixed rule, so it comes after Stage 4). The notification times (Stage 1) and the review-ask counts (Stage 5) are decided. **No open points remain.** Nothing in this plan is executed until you approve the plan itself.
