# ADR-026: Enumeration Follows Cleanup — No File Opens, Per-Type Delivery

## Context

On 31 Oct 2026 the owner reported from a real device: after
~10 minutes in the Albums tab, NONE of the smart decks appeared
(Screenshots, Bursts, Blurry, Dark, Similar Videos, Duplicates).
Diagnosis (code-verified, no device needed): the failure is
structural, in the scan's front end.

1. The hub renders a deck row only for a deck with ≥1 asset,
   and `LibraryScanner` delivered its first page only after the
   ENTIRE native enumeration pass returned — it awaited the
   merged `enumerate(forceRefresh: true)` before the page loop.
   A stalled pass therefore meant zero rows of any kind, even
   the per-page decks.
2. The native pass itself (`MediaEnumerationChannel.kt`,
   Stage 2 / ADR-017 §4) repaired any row whose stored width
   or height was 0 by opening the real file inside the cursor
   loop — a bounds decode for images, a fresh
   `MediaMetadataRetriever.setDataSource` per video — and ran
   both media types sequentially on a single-thread executor,
   with no timeout anywhere. A few slow, corrupt or
   cloud-backed videos could stall the whole pass indefinitely.

The owner directed that the enumeration follow Cleanup in these
two things too. Cleanup's evidence (teardown notes/pipeline.md):

- Q1: its enumerator runs plain full-table MediaStore queries,
  one per media type, and takes row values AS THE CURSOR GIVES
  THEM — `originalSize = Size(w, h)` straight from the cursor,
  isEdited/isLive hard-coded false. No file is opened during
  enumeration: no decode, no metadata retriever, no existence
  check. Classification is in-row, from the file name.
- Q3: the per-type queries fan out as PARALLEL async tasks on
  a shared scope; nothing serialises the types behind one
  thread.
- Q2/Q5: the scan is fire-and-forget and results reach the UI
  progressively; the UI is never gated on one awaited
  all-or-nothing future.

ADR-017 §4's dimension repair was a deliberate mirror of
photo_manager's cursor conversion (behaviour preservation).
That rationale is superseded for the repair: on a real library
the mirror is the stall. This ADR records the reversal,
approved by the owner on 31 Oct 2026 (plan:
cleanup-teardown/ENUMERATION_PARITY_PLAN.md, Part A).

## Decision

1. **The native enumeration opens nothing (A1).**
   `MediaEnumerationChannel` returns width/height exactly as
   stored, zeroes included; the repair function, its
   BitmapFactory/MediaMetadataRetriever imports and the
   MIME_TYPE column (whose only consumer was the repair) are
   deleted. The executor becomes a fixed pool of 2, so the
   images and videos passes run concurrently (Cleanup's
   fan-out). Everything else is unchanged: fields,
   storeWidth/storeHeight raw columns, `_id DESC` sort,
   `BUCKET_ID IS NOT NULL` selection.
   **Recorded deviation from Cleanup:** the per-row
   `File(data).exists()` stat is KEPT. Cleanup performs no
   existence check; wipe. keeps it because the Dart list
   filter (`fileExists`) mirrors the plugin-era behaviour of
   skipping rows whose backing file is gone, and a stat is
   not an open — it cannot stall on file content the way a
   decode or a retriever can. Revisit only if on-device
   timing ever indicts it.
2. **Per-type reads on the shared pass machinery (A2).**
   `LibraryEnumerationService` gains `enumerateImages()` /
   `enumerateVideos()`. Each media type has its own memo slot
   and in-flight slot; `enumerate()` is the join of the two
   per-type reads plus the merge, so merged and per-type
   callers share ONE gateway call per type per pass, and the
   library-change invalidation drops every slot exactly as
   before. Consequences, recorded deliberately:
   - A type that fails fails only its own read; the merged
     read still fails while either type fails (its existing
     contract), and a retry re-queries only the failed type —
     the healthy type's memo stands (unlike ADR-017's
     all-or-nothing retry, and bounded by the same
     invalidation events).
   - A successful per-type refresh drops the merged memo, so
     a later merged read rebuilds from the per-type memos
     instead of serving a merge that predates the refresh.
   - A forced read still joins an in-flight pass rather than
     doubling the query (ADR-017's guard, unchanged).
3. **The scanner delivers per type (A3).** With enumeration
   wired, `LibraryScanner` requests both per-type passes up
   front, pages the IMAGES as soon as the images pass lands,
   then pages the VIDEOS when the videos pass lands (page
   size, cancel and pause gates per page, exactly as the
   paged source honours them; the pause gate still never
   gates the enumeration await). `estimatedTotal` is the
   images count until the videos pass lands, then the
   combined count. Phase B still runs once, over the full
   set. Failure semantics map onto the existing paged-source
   contract: images pass fails → the page-0 failure shape (no
   pages, pageFailed, previous snapshot stands, nothing
   persisted); videos pass fails after images were delivered
   → the mid-scan page-failure shape (arrived assets kept,
   pageFailed, memberships untouched). An empty library still
   delivers exactly one empty page, as the merged source did.
4. **Zero dimensions are safe (A4 audit).** With repair gone,
   width/height can be 0 where repaired values used to
   appear. The audit of every consumer (full table in the
   execution report): `isPluginListRow` reads the raw store
   columns and is unaffected — and it already excluded every
   store-dimension-zero image from every list and scan page,
   so list-visible images carried store dimensions before and
   after; the exact-duplicate key only ever sees those
   images, so it is unaffected; Similar Videos reads no asset
   dimensions (frame fingerprints come from decoded rasters);
   no UI lays out from `MediaAsset.width/height` (the
   duplicates tiles are fixed squares by design). The one
   real consequence: `AssetInfo` facts carry width/height, so
   a video whose store dimensions are 0 (previously repaired)
   changes facts — the first scan after this change treats
   the snapshot as not fresh and recomputes once; the raw
   values are the stable facts thereafter. No consumer needed
   a guard; nothing else changed.
5. **Requirements §7** describes neither the repair nor the
   all-at-once delivery (checked), so it is not amended; the
   behavioural record lives here and in ADR-017's superseded
   pointer at §4.

## Limits

- The Kotlin still cannot be compiled or run in this
  environment; on-device verification (pass duration on the
  owner's library, decks appearing progressively) is the
  owner's rebuild, as with every native change since Stage 2.
  No timing is claimed anywhere in this change.
- Delivery is per TYPE, not per row: within one type's pass
  the hub still waits for that type's query to return before
  its pages slice out. That is the plan's chosen parity
  point — Cleanup's own results also land per completed
  grouping pass, not per cursor row.
