# ADR-016: State-Based Reminders (fix plan Stage 1)

## Context

Requirements §7 (Phase 3) originally specified notifications as "one
gentle weekly nudge only". The Cleanup teardown (notes/retention.md
§1.3) showed the competitor has no clock reminder at all: every local
notification names an unfinished state (trash waiting, scan finished
but nothing deleted, scan left part-way, feature never tried). The
owner approved wipe.'s version of that system on 30 Oct 2026 —
states, copy, timings (first reminder + one repeat per state, at most
one per day, early evening, cancelled when the work is finished) —
and requirements §7 was amended in the same change.

Cleanup does not reveal its scheduling values or its state-detection
internals (AOT + server config), so the detection and bookkeeping
below are wipe.'s own design, built only from state the app already
persists. Per AGENTS.md, unspecified decisions take the simpler /
cheaper / more private option; the choices that needed one are
recorded here.

## Decision

1. **Detection reads persisted state only** (no new tracking):
   - *Waiting*: delete marks across the saved deck sessions the
     Trash tab's union (ADR-015) can show — Clean filter sessions
     and `smart:` decks — minus ids already in the recorded Trash
     list, resolved through `MediaService.getAssetsByIds`. The
     `duplicates` session is excluded: the union never displays
     it (its marks are reviewed inside the Duplicates deck's own
     flow), so counting it would point the user at photos they
     cannot find waiting in the Trash tab. Ids MediaStore no
     longer resolves (already trashed/deleted photos keep their
     delete mark in the session by design — see DeckController)
     never count, so the reminder can only name genuinely waiting
     photos. Photo/video split of the resolved set feeds the
     counted message. (Amended by the Stage 1 fix pass — the
     original read included the `duplicates` session; checker
     note N5.)
   - *Finished deck*: a recorded completion day (both deck
     controllers record one when a session's final mark lands).
   - *Ever swiped / ever deleted*: any session mark exists / any
     Trash record or history record exists.
   - *Media granted*: `MediaService.requestPermission`, the same
     call the deck warm-up already makes at every launch.

2. **Ladder exclusivity.** The finished-with-nothing-deleted state
   requires: a completion exists, nothing was ever deleted, and
   nothing is waiting (waiting outranks it — it is the same work
   one rung further). The unfinished state may be true alongside
   waiting (a part-way deck that already produced delete marks);
   the approved priority order (waiting → finished → unfinished →
   never swiped) plus the one-per-day rule order their evenings.

3. **Clocks start at first observation.** The app persists no
   install date, and inventing one would be guessing. A state's
   delay counts from the first refresh that observes the state
   after the user turned reminders on. Refresh runs at launch
   (splash), on app pause, and when the toggle turns on.

4. **Evenings, priority and the one-per-day rule.** Reminders
   fire at 19:00 local. Every refresh re-places all unsent steps
   (the engine cancels and re-schedules the whole set anyway, so
   a step whose competitor vanished moves back to its own due
   evening). A step's first-choice evening is the first 19:00 at
   or after its due time (or tonight, when overdue). Steps are
   placed in order of that evening; steps that want the SAME
   evening are ordered by state priority (waiting → finished →
   unfinished → never swiped), so the more important state takes
   the evening and the other defers to the next free evening —
   deferred, never dropped. A step never fires before its own
   due evening, so priority cannot shorten the approved ladders.
   A step counts as sent once its scheduled time has passed; a
   step whose slot passed while it was never scheduled (reminders
   off, permission revoked) is placed at the next free evening
   instead of being silently consumed. (Amended by the Stage 1
   fix pass: the original placement ordered by due time with
   priority only breaking exact ties, which let a lower state
   due earlier in a day take that evening from a state-1 step
   due later the same day — checker note N1.)

5. **The counted message (plan state 4).** Cleanup's counts are
   items its unfinished scan found ready to delete. wipe. persists
   no equivalent count for a part-way deck; the only truthful
   "lined up for deletion" numbers in app state are the waiting
   delete marks. The counted step is therefore planned only while
   waiting photos/videos exist, uses those counts, and is
   un-planned if the counts reach zero before it fires. It never
   invents a number. The counts are the same mirrored waiting set
   as §1 — the `duplicates` session never feeds them, so the
   numbers always match what the Trash tab shows.

6. **Inexact scheduling, no new permissions.** Reminders use
   `AndroidScheduleMode.inexactAllowWhileIdle`. Exact alarms would
   need `SCHEDULE_EXACT_ALARM`, a new permission outside the set
   the owner approved; a reminder does not need alarm precision.
   The manifest needed no change at all: the plugin's scheduled +
   boot/update receivers and `RECEIVE_BOOT_COMPLETED` were already
   declared (finding F-33, fixed earlier), so reminders survive
   restarts and app updates. Fire times are built as TZDateTime
   from the instant in UTC — a one-shot schedule consumes the
   instant, so no timezone database or device-timezone plugin is
   needed; `timezone` is declared as a direct dependency (it was
   already resolved transitively via flutter_local_notifications).

7. **Reminder state storage.** Tracks live in their own JSON file
   (`klara_reminder_state.json`) behind a narrow
   `ReminderStateStore`, following the one-file-per-data-kind
   pattern of the other local stores. A JsonFileStore owns its
   file's snapshot, so the record cannot share the settings file
   safely; widening `LocalService` instead would have forced
   changes into every test fake of that interface (~40 files) for
   a single-consumer data kind. The settings toggle itself stays
   in `AppSettings`: the field was renamed `weeklyNudge` →
   `reminders`, with `fromJson` still reading the old key so
   existing installs keep the user's choice.

8. **Migration.** The engine cancels the legacy weekly-nudge
   notification id (7001) on every refresh and on toggle-off, so
   an old build's weekly nudge can never fire next to the state
   reminders. Turning reminders off cancels everything; a revoked
   system permission clears planned slots (so unsent steps are
   not later counted as sent) but keeps state start times and
   sent history.

9. **Permission ask.** Turning the toggle on shows an in-app
   permission sheet first (title + one-line benefit + Turn on /
   Not now), following the Settings sheet pattern and Cleanup's
   priming (retention.md §1.2); only the sheet's confirm triggers
   the system request. A denial leaves the toggle off with the
   reason shown. No ask happens at first launch.

10. **Review leave-guard.** Leaving Review (system back or bottom
    nav) while photos still wait in the grid shows a confirmation
    in wipe.'s words — "Open Review" stays, "Save and Exit"
    leaves; the marks are persisted either way, so exiting loses
    nothing. Selection-cancel still takes precedence over the
    guard, and an empty grid never prompts.
