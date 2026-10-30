# ADR-020: Finish Screen, Payoff Meter, Resume, and the Review Ask (fix plan Stage 5)

## Context

Stage 5 restores the payoff surface the audit found switched off
(F-29) and adds the retention loop Cleanup runs after a clean:
a congratulations screen, a live "freed so far" meter, decks
that reopen where the user stopped, and a counted review ask
(teardown `notes/retention.md` §4.2–4.3, `notes/delight-assets.md`).
The counts, copy and artwork are the owner's decisions, recorded
in the plan's Stage 5 section (30 Oct 2026). Cleanup's own
thresholds are server-side and unreadable, so the numbers here
are wipe.'s own, chosen by the owner. Everything the new screens
show comes from the app's real records — no invented statistics.

## Decisions

1. **"Delete batch" maps to the app's two real completion
   points.** (a) Review permanent delete (ADR-014): the finish
   screen replaces the direct return to the deck only for the
   pure whole-set outcome — the run deleted at least one photo,
   nothing was denied or failed, and the grid is empty.
   Partial (selection) runs keep the existing snackbar-and-stay
   behaviour, and mixed denied/failed runs keep their counted
   dialog: both already report their numbers, and the review
   session is not finished there. (b) The Clean deck's batched
   native trash run (`DeckController.flushAwaitingTrash`,
   ADR-013): on a completed flush with trashed photos, the
   controller publishes the batch (the denied-banner pattern:
   an Rx the deck view consumes) and the deck navigates to the
   finish screen. The flush's only UI trigger was removed by
   the owner in 306f75d ("AG fix"); Stage 5 hooks the
   completion, never a new trigger, so the deliberate removal
   stands and the hook is live the moment any trigger exists.

2. **Finish-screen numbers are the batch's own outcome.**
   Deleted count and bytes are summed from the ids the native
   sheet actually confirmed. The space row states the flow's
   truth: Review deletes are permanently deleted, so the space
   is "Freed from your storage"; a trash batch is "In Trash —
   freed on [date]", the date read back from the recorded
   TrashEntries (`trashedAt + 30 days`, `TrashEntry`'s own
   rule). There is no "saved time" row — wipe. has no honest
   way to measure it (the plan already decided this).

3. **Meter restore is F-29a only.** The deck's existing
   `SpaceMeterBar` (three honest states, numbers the code
   already calculates) is uncommented in `DeckView`. The other
   owner-disabled surfaces (F-29b hub banner/header, F-29c
   labelled action-bar branch, F-29d Review empty-state CTA)
   stay exactly as the owner left them.

4. **Resume: first-undecided stays the position rule; the fix
   is paging.** Both deck controllers already resume at the
   first undecided card, which is where the user left in every
   flow that can rewind (undo, Review unmark/denied all target
   the same index). The gap was pagination: a decided run
   crossing a page boundary left the first undecided card on an
   unloaded page, so a reopened deck showed the finished
   summary instead of that photo. On load, the Clean deck now
   pages forward until the first undecided card is loaded or
   pages run out (a failed page stops the walk and keeps the
   old behaviour). Smart decks hold their whole queue in
   memory and needed nothing. No popup: the app's established
   resume is silent, and the brief fixes behaviour, not chrome.

5. **Review-ask state lives in a narrow store.** A
   `ReviewAskStore` (own JSON file, Stage 3 atomic writes via
   `JsonFileStore`) — not new `LocalService` methods: that
   interface is faked across the whole test suite, and this
   record has one consumer (the ADR-016 §7 reasoning, applied
   again). State: total swipes, total deletes, usage days,
   per-place next threshold + times shown, home exhaustion,
   the answered flag (review / feedback), and the last batch's
   count + bytes.

6. **Counters are seeded once from real records, then counted
   at the real events.** First load seeds: total deletes =
   sum of history record counts (Review permanent deletes and
   Trash emptyings — both are permanent deletions of photos)
   plus the photos currently recorded in Trash (deleted by
   past batches, not yet emptied); total swipes = marks across
   all persisted sessions; usage days = completion days ∪
   history-record days. After seeding, a swipe is counted when
   a mark records (both deck controllers), and deletes are
   counted at the two completion points with the outcome's own
   counts (Review: every run that deleted photos, partial and
   mixed included — the counting point is `_applyDeleted`;
   Clean flush: the trashed count). Emptying Trash never
   re-counts photos already counted at trash time.

7. **Threshold semantics are the owner's words, literally.**
   After deleting: due when total deletes **> 10**; after
   swiping: due when total swipes **≥ 60**; home: due at 3+
   distinct usage days AND at least one delete AND neither
   other place ever shown. Once per place: a dismissal doubles
   that place's threshold (deletes 10 → 20 → 40; swipes
   60 → 120 → 240, endlessly). Home has no count to double —
   a dismissed home ask is final for home. A review or a
   feedback given anywhere silences every place forever.

8. **The sheet's amount is per-place, always a real number.**
   The owner's title copy is "You just freed up {X}". Delete
   place: X = the finish screen's own batch amount (the plan's
   build-time consistency note: the sheet uses the same real
   number the finish screen shows, even when that screen words
   it as in-Trash). Swipe place: X = the just-ended session's
   delete-marked bytes; when the session marked nothing, the
   fallback below. Home place: the fallback. Fallback = the
   last recorded batch's bytes, else the lifetime freed bytes
   from history records. Formatted with the app's own
   `Formatters.formatBytes`, so sheet and finish screen can
   never disagree about the same amount.

9. **The unhappy path is a subordinate text action.** The
   decided sheet design has exactly two buttons ("Let's Go!" /
   "Maybe Later"), and "Maybe Later" is a dismissal, not a
   negative answer. The brief requires an honest way to say
   "not enjoying", so under "Maybe Later" the sheet carries a
   small text action, "Not happy? Tell us what's wrong",
   which swaps the SAME sheet to the feedback form (design.md
   §6: sheets never stack). Submitting the form is the
   feedback answer; opening it and cancelling is a dismissal.

10. **Store prompt via `in_app_review`.** The plugin is added
    (Cleanup ships the same one, retention.md §4.3). "Let's
    Go!" marks the ask answered first — the Play dialog's own
    outcome is not observable, so the tap is the answer — then
    `isAvailable()` gates `requestReview()`, with
    `openStoreListing()` as the unavailable fallback; any
    error is swallowed after marking, so the flow degrades
    silently and never re-asks.

11. **Feedback submission is a stuck point, resolved to the
    most honest available action.** The app has NO support
    channel: no support address exists anywhere in the repo,
    there is no feedback backend (on-device only,
    requirements §5/§9), and the Settings "Feedback" section
    string is unused. Inventing an address would send user
    words to a made-up destination. So Submit hands the text
    to the system share sheet through the existing
    `ShareService`: the user sees the text, picks the
    destination, and sends it themselves — nothing is sent
    silently, and the ask is marked answered at submit. A
    real support inbox is the owner's decision to add later;
    this is recorded loudly in the stage report.

12. **Presentation follows the TrashView pattern.** Ask state
    is computed by `ReviewAskService` and surfaced by
    controllers as Rx state; views present the sheet from
    post-frame / `ever` watchers (the `_ArrivalSnack`
    precedent), at most once per trigger. The service is
    optional-injected into the deck, smart-deck and review
    controllers (null = inert), so existing tests and
    constructions are untouched. Usage days are recorded at
    splash launch and on deck resume.

13. **The delete-moment celebration is NOT built.** Cleanup
    plays a ~2 s animation when a deletion lands; wipe.'s
    artwork for that moment is the owner's still-open choice.
    The hook points are the two completion branches above
    (Review's pure-delete outcome, the flush completion): a
    moment would slot in immediately before the finish route
    opens. No placeholder artwork ships.

14. **Artwork ships as decided.** The Fluent party popper
    (MIT), the owner's heart-paws kitten cutout, the soft
    gold stars and the two ref-style empty-state pictures
    live under `assets/images/` with `img_` names (design.md
    §10). The SVGs use only paths and linear gradients
    (flutter_svg-safe); their internal shading is the owner's
    accepted artwork, not UI chrome. The kitten PNG is
    re-encoded losslessly-optimised at its native size.
    Empty-state pictures appear ONLY on History and Trash
    (`EmptyView` gains an optional image; every other caller
    is unchanged).

15. **`FinishSummary` is a route-argument model** in
    `features/finish/model/`. The review and deck controllers
    import it to build finish-route arguments (and the deck
    view's watcher names it for the same hand-off) — a
    documented cross-feature exception of the same kind as the
    decks feature importing the deck's `retention.dart`: a pure
    data class, no behaviour, no state.

## Addendum — 30 Oct 2026: decision 11 SUPERSEDED (owner decision)

The owner ruled: **feedback goes nowhere.** Decision 11's
share-sheet resolution is superseded. The feedback form
stays exactly as it is — the user writes, submits, and sees
the "Thanks" confirmation — but submitting now does only one
thing: it marks the ask answered (feedback; decision 7's
silencing is unchanged). The text is simply discarded: the
sheet keeps it in its own text field and never passes it
out, the service's feedback answer takes no text at all, and
the review-ask service no longer holds a `ShareService`
dependency. Nothing is sent, shared, or stored. A real
feedback channel is a future owner decision, not this
change. The form's fields and the cancel-as-dismissal path
are unchanged, and `ShareService` itself is untouched — the
deck's session-summary share still uses it.
