# ADR-025: Per-Action Loading on the Review Bottom Bar

## Context

On 30 Oct 2026 the owner reported the Review (Trash/Review)
screen's loading behaviour from real use: pressing Delete or
Keep made the loading spinner appear on BOTH bottom buttons,
and it looked continuous — "not professional". Analysis of
the shipped code confirmed three defects:

1. **One shared flag drove both buttons.**
   `ReviewBottomBar` read the single observable
   `ReviewController.isDeleting` and passed it as `isLoading:`
   to BOTH the Keep (`SecondaryButton`) and Delete
   (`PrimaryButton`) buttons. Both shared button widgets
   render a `CircularProgressIndicator` whenever `isLoading`
   is true, so any delete run spun both buttons. Reproduced
   in a widget test: with a delete held pending, the bar
   contained exactly 2 progress indicators.

2. **The flag could strand at `true` forever.**
   `deleteSelected` set `isDeleting = true`, awaited the
   delete planning and the trash service, and cleared the
   flag by hand on only two paths (the all-protected early
   return, and after the service returned a `Result`). There
   was no `try/finally`: any throw in between (a service
   implementation surfacing an error as an exception rather
   than a `Result`) stranded the flag permanently — and the
   method's own entry guard (`isDeleting` → return null)
   then silently swallowed every later Delete tap, so the
   screen could never recover: both buttons spinning for
   the rest of the session. Reproduced in a test whose fake
   settings load throws: after the throw, `isDeleting` was
   still `true`.

   Even with no throw, the flag's lifetime covered the whole
   native confirmation wait inside `deletePermanently`
   (`MediaStore.createDeleteRequest`), so the double spinner
   sat on screen for as long as the system sheet was up.

3. **Keep had no loading state at all.** `keepAll` /
   `keepSelected` never set any flag, so a Keep tap gave no
   feedback while the session write ran — and after a
   stranded delete flag, Keep taps happened under a
   permanently spinning bar, matching the owner's "delete
   OR keep" report.

design.md §5 already specifies the professional pattern —
"spinner in the button for short ops, button disabled to
prevent double-submission" — the Review bar was the
deviation.

## Decisions

1. **Per-action busy flags in the controller.** `isDeleting`
   now belongs to the Delete action alone; a new `isKeeping`
   belongs to the Keep actions (`keepAll`, `keepSelected`).
   A derived `isBusy` (`isDeleting || isKeeping`) gates
   entry: an action starts only when neither is running.
   No action's mechanics, outcomes, navigation, counting,
   or the celebration hop changed — presentation and state
   plumbing only.

2. **Finally-style clearing everywhere.** `deleteSelected`,
   `keepAll` and `keepSelected` set their flag, run their
   existing body inside `try`, and clear the flag in
   `finally`. The spinner lasts exactly as long as its own
   action on every path: success, denied, failed, and a
   thrown exception (the exception itself still propagates,
   as before — services contract on `Result`; the finally
   only guarantees the flag cannot strand).

3. **The bar wires each flag to its own button only.**
   Keep gets `isLoading: isKeeping`, Delete gets
   `isLoading: isDeleting`. While the OTHER action runs, a
   button's `onPressed` is `null` — disabled and dimmed per
   the shared widgets' existing disabled treatment, not
   spinning and not tappable. While its OWN action runs,
   the shared widgets' `isLoading` already disables the
   button, so it cannot be re-tapped. No shared widget was
   changed; the fix is entirely at the Review call site and
   in the controller, per the minimal-change rule.

4. **Scope: Review only.** The Trash screen's bottom bar
   has the milder relative of this pattern — one shared
   `isBusy` spins Restore-all while Empty-trash is merely
   disabled — and is left as-is by this decision (noted in
   the fix report for a possible future pass). No other
   action bar passes `isLoading` to the shared buttons.

## Consequences

- Pressing Delete spins only Delete; pressing Keep spins
  only Keep; the idle button sits disabled until the action
  finishes, however it finishes.
- The stranded-spinner state is unreachable: no path out
  of the three actions leaves its flag set.
- `review_loading_test.dart` pins the contract with
  Completer-gated fakes: per-button spinners while an
  action is pending (whole-set and selection modes), the
  other button disabled, and clearing on success, denied,
  failure, and thrown exception.
