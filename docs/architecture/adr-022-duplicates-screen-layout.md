# ADR-022: Duplicates Screen Layout — Cleanup's Structure, wipe.'s Design (fix plan Stage 7)

## Context

Stage 7 redesigns the Duplicates screen's layout and flow only.
The finding engine is Stage 4's (ADR-019): the screen shows the
scan's exact-duplicate groups, the keeper suggestion is the
existing rule, and the similarity slider was already removed in
Stage 4. The evidence for the layout is Cleanup's own Play Store
screenshot and string table (teardown notes/duplicates-ux.md):
results first with a totals summary, group cards headed by a
count and a size, large side-by-side photos, a badge on the
suggested keeper, every other photo pre-selected with a round
mark, one sticky bottom button with live totals, Select All /
Deselect All, and one explanation line per folder. The look
stays 100% wipe.: design.md tokens, flat, Inter, the existing
card style.

## Decisions

1. **Every count and size on this screen counts NON-KEEPERS.**
   The summary under the title is the non-keepers across all
   groups and their total size; each group header is that
   group's non-keeper count and their size; the sticky button
   counts the SELECTED subset of the same set. One definition
   everywhere means the numbers on the screen always agree:
   summary = sum of the group headers, button = what pressing
   it will actually mark. (Cleanup's screenshot does not say
   whether its group header counts all members or only the
   deletable ones; wipe. counts the deletable ones, because
   those are what the screen acts on.)

2. **The flow mapping is unchanged from the per-card flow it
   replaces.** The one mark action writes through the same
   mechanism the duplicates screen has always used:
   `LocalService.saveSession` on the `duplicates` session —
   `DeckMark.delete` for each selected non-keeper, `DeckMark.keep`
   for the keeper of each contributing group, Phase 3A protection
   untouched (a protected selected non-keeper is marked keep and
   counted in the banner instead) — and then navigates directly
   to Review with the marked list as arguments and
   `filterKey: duplicates`, exactly the completion the old
   per-card buttons performed. Recorded precisely because the
   Trash tab is NOT this screen's path: the ADR-015 union
   (`buildReviewUnion`) gathers the Clean deck's sessions plus
   sessions whose key starts with `smart:`; the `duplicates`
   session is neither, so these marks reach the user through
   the screen's own Review opening, as they did before Stage 7.
   Nothing about the union, Review, or deletion changed.

3. **Selection is controller-held screen state, modelled as the
   set of selected non-keeper ids.** Every non-keeper starts
   selected. Tapping a photo's mark spares or re-selects that
   one photo; tapping the photo keeps its existing keeper
   behaviour — the mark is a separate widget with its own 48dp
   hit target, so the two never compete. When the keeper
   changes, the selection follows: the new keeper leaves the
   selection (a keeper is never marked) and the previous keeper
   joins it, selected like every non-keeper — a spare set on it
   earlier is superseded by the keeper change itself. A spared
   non-keeper receives NO mark when the action runs (it stays
   undecided for a later run), and a group contributing no
   selected non-keeper is left completely untouched — its
   keeper does not even get the keep mark, because the run was
   never about that group.

4. **At zero selected, the sticky button is disabled in place.**
   The bar stays visible with the button in PrimaryButton's
   disabled state and the caption design.md §5 requires
   ("Select at least 1 photo") above it — the screen's one
   primary never jumps in or out, and the way back (re-select a
   photo) is on the same screen.

5. **Layout mechanics.** Photos render as square tiles, two per
   row, filling the card width; groups of 3+ wrap in the same
   grid (Cleanup's evidence shows pairs only; nothing else is
   invented, and there is no full-screen compare view). The
   brief-3.5 collapsed preview cap (20 previews + an overflow
   tile that expands) is retained at the new tile size — it is
   a render bound, not layout chrome, and hidden non-keepers
   are still counted and selected. The keeper's pill sits
   bottom-left on the photo in the success colours with the
   existing word "Keeper"; the selection mark sits bottom-right
   — filled error colour with a check when the photo will be
   marked, a scrim-filled ring when spared. Each mark carries
   its own accessibility label in the thumbnails' voice (state,
   then the action a tap performs).

6. **Reactivity shape.** The selection lives in an RxSet on the
   controller, but the cards are built inside the lazy list
   builder, whose reads fall outside an Obx's tracked scope.
   The list therefore sits in an Obx whose builder snapshots the
   selection into a plain set for the cards, and the summary
   header receives its selection-derived states as props read
   inside an Obx builder. (Verified by test: before this shape,
   the sticky bar updated on a mark tap while the marks
   themselves stayed stale.)

7. **Strings and tokens.** The repeated per-card helper sentence
   and the per-card button are gone, with their strings. New
   strings carry the summary, the one explanation line, the
   group header, the sticky button's live label, the
   zero-selection caption, Deselect all, and the marks'
   accessibility labels. The fixed `duplicateThumb` size token
   is retired — tiles are fluid now — and one token is added
   for the selection mark's circle (`selectionMark`). No raw
   colours, sizes, or strings appear in feature code.
