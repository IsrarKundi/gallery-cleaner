# ADR-004 — Phase 4 storage, scan reuse, and lifecycle decisions

## 1. Write coalescing: fixed 1.5 s window, no count trigger (4.1)

The solutions doc's decision-4 window was "~1–2 s / ~20 marks".
The count trigger was DROPPED deliberately: the doc's own
acceptance benchmark (bytes written for 1,000 marks ≤ ~2× the
final sessions size) is unsatisfiable with a 20-mark trigger —
1,000 rapid marks would flush ~50 times over a growing file,
costing ~25× the final size, not ≤2×. With a fixed time window
only, 1,000 rapid marks cost exactly one write (1×, proven by
`json_store_test.dart`).

The window is FIXED, not a resetting debounce: the timer starts
on the first pending write and fires 1.5 s later even if more
marks arrive meanwhile, so continuous marking still flushes
mid-stream. The doc's window is honoured in spirit (~1.5 s sits
inside ~1–2 s); the 20-mark figure is the expected maximum
human marks within such a window, not a trigger.

## 2. Crash window for every debounced write (4.1)

Only session saves coalesce. A coalesced session write not yet
flushed is lost if the app is killed — at most ~1.5 s of session
marks (a handful of swipes at human speed). Backgrounding always
flushes first (app-paused is a mandatory flush point), so the
window only bites on a hard kill. Trash, history, settings, and
analyses always use immediate writes and have no window. A
failed disk write keeps the snapshot dirty so the next flush
retries it. Mandatory flush points, no exceptions: go-to-review,
filter change, app-paused, dispose. Trash writes never sit in a
debounce window past a mandatory flush point — they never enter
one at all.

## 3. Atomic writes and salvage (4.1)

Every disk write goes to `<name>.tmp`, flushes, then renames
over the target: a kill mid-write leaves the old or the new
file intact, never a truncation. A leftover `.tmp` is ignored
on load. List files salvage complete top-level objects from a
truncated tail (string-aware brace scan); map files cannot be
brace-salvaged (keys would be lost) and read as empty — atomic
writes prevent new truncations, so this path only ever meets
pre-4.1 damage. Per-entry salvage skips bad entries and counts
them instead of failing the whole file. A corrupt session entry
loads as null (deck starts fresh) instead of the old whole-file
failure; trash is unaffected by a corrupt sessions file.

## 4. Scan reuse: memoised within a session, dirty on resume (4.2/4.4)

A completed scan is memoised in the repository until
`markDirty()` (or a restart). A later `start()` replays its
pages with no media calls. A failed or cancelled scan is never
memoised. `start()` while a scan runs JOINS it (same future,
replayed past pages + live pages). `restart()` cancels the
running scan and starts fresh; a subscriber awaiting the
cancelled run gets a `cancelled` result and is expected to
call `start()` again to join the fresh run.

Subscription is detach-only: unsubscribing detaches callbacks
(a result arriving after the controller left is dropped) but
does NOT cancel the shared run — a returning controller replays
past pages and joins the live run, so leave-and-return neither
restarts nor duplicates work. A subscriber-less run continues
to completion and memoises; the cost is bounded work the user
asked for by opening the hub, and lifecycle pause (4.4) covers
backgrounding.

## 5. Pause/resume/restart hazard (4.4)

`restart()` does NOT clear a paused flag: a background-paused
scan restarted without a prior `resume()` stalls at its first
page gate forever. Every resume path therefore calls
`resume()` BEFORE any reload or restart, and every controller
`onClose` calls `resume()` so a controller disposed while
backgrounded never leaves the shared scan paused for the next
controller. The pause gate itself sits BEFORE each page fetch:
a page already in flight when pause lands completes (its
`onPage` fires); the NEXT fetch blocks. This is the designed
page-boundary semantic, not a leak.

## 6. Lifecycle shape (4.4)

One `WidgetsBindingObserver` (`AppLifecycleImpl`) delivers
pause/resume to controller listeners; it owns no feature
state. Pause flushes pending session writes centrally (see §2)
and pauses the preloader (no new fetches; in-flight deck
fetches cancel; cached bytes and failed marks survive) and the
shared scan. Resume is delivered only when previously
backgrounded (a launch-time resumed event is ignored);
`inactive` is ignored as transient. Permission state is never
persisted and never cached anywhere in this path: every resume
handler re-checks permission itself (Android 14 rule).

Resume decision tree (deck, hub, Duplicates alike): denied →
denied state + explanation; granted after denied/error →
reload from scratch (the deny → Settings → grant → return
path, no manual tap); otherwise the screen's own refresh.

## 7. Deck refresh: always page-0, marks preserved (4.4)

The deck refreshes page 0 on EVERY resume when ready and
granted (one page fetch — cheap), plus immediately on a
foreground library-change event. Background changes are
covered by the resume refresh. The merge (`mergePageZero`,
pure, in `deck_queue.dart`) prepends fresh ids, drops only
provably-gone page-0 members, adjusts the index so the same
card stays current, and never touches marks.

Gone vs displaced (the subtle rule): a full fresh page can
push old members past the window without deleting them. If
the fresh page is short it enumerates the whole library, so
every absent old member is gone. If it is full, an absent old
member is gone only when its date is strictly newer than the
fresh window's oldest date — a present member newer than the
window end must sit inside the window. Older-or-equal absent
members are kept (possibly displaced). Honest bounds: deeper
queue order is not re-sorted, deletions beyond page 0 are not
detected here, pagination continues from its old page
numbering. A filter change, relaunch, or full scan restores
exact order.

Race guard: `markCurrent` awaits an in-flight resume reload,
so a mark can never be overwritten by the reload's session
restore. `undo`/`clearDeleteMarks` are synchronous and have
no such guard — an undo during the sub-second reload window
on a permission-level change (the only reload path on resume)
may be overwritten by the restore. Bounded and documented,
not silently fixed: making those paths async would change
their call sites across the deck for a <1 s window on a rare
path. The common resume path (page-0 refresh) touches no
marks at all.

Snooze expiry on resume: applied once, via the existing
batched `clearSnoozes` (one write when something cleared,
zero writes when nothing cleared — the 4.1 batching).

## 8. Hub/Duplicates refresh: dirty-gated full re-scan (4.4)

A full re-scan is expensive, so unlike the deck it is NOT
done on every resume. Library-change events set a per-
controller dirty flag; resume reconciles it with a fresh
scan (resume → restart → reload). A clean resume only
unpauses a running scan and performs no media calls. A
foreground change does not restart a scan under the user's
scroll — it waits for the next resume. If native change
delivery fails to start, the flag never sets and hub/
Duplicates fall back to manual retry / relaunch for library
changes (the deck's always-refresh still covers the deck).

## 9. Change notification: separate capability, best-effort (4.4)

Change delivery is deliberately NOT a `MediaService` method:
adding one would break every test fake implementing that
interface, and delivery is a separate capability from media
queries. `LibraryChangeSource` (production:
`PhotoManagerChangeSource` over `addChangeCallback` +
`startChangeNotify`) feeds the lifecycle service's broadcast
stream; each controller subscribes independently, so there is
no consumed-once flag problem. Note: `notifyStream` is NOT
the change event — it only reports whether delivery is
enabled — so the source filters `MethodCall`s to method
`change`. The callback carries no asset ids and no photo
content, only a "something changed" flag. Delivery is
best-effort: a start failure is swallowed and consumers fall
back as in §8.

## 10. Scope boundaries kept (4.4)

- Smart decks get NO lifecycle wiring: the controller holds
  no permission/error state (its queue arrives via launch
  arguments from already-permission-checked screens), so a
  re-check would have nothing honest to display. Returning
  to the deck or hub re-checks permission there. If a smart-
  deck denied state is ever added, resume wiring belongs
  with it.
- The Albums tab mapping and the smart-deck "window 10/20"
  numbers are still open product decisions and were not
  assumed anywhere in Phase 4.
- `media_service_impl.dart` and `deck_controller.dart` grew
  during Phase 4 (lifecycle orchestration in the deck
  controller; the pure merge lives outside it in
  `deck_queue.dart`). The Phase 2 over-length note stands;
  later phases must not grow them further without
  extracting a cohesive unit.
- The Phase 3 bottom-nav mid-swipe residual is unchanged:
  Phase 4 adds no new navigation bypass paths.
