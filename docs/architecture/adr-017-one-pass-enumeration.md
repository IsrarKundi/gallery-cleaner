# ADR-017: One-Pass Library Enumeration (fix plan Stage 2)

## Context

The Cleanup teardown (notes/pipeline.md Q1) showed the competitor
enumerates with ONE MediaStore query per media type: the single
pass already returns id, name, bucket, file size, dimensions,
dates and the favourite flag, screenshots are classified by file
name during the same pass, and the scan is one guarded,
background, shared job whose results every screen reads.

wipe. instead paged photo_manager (50 per page), and although the
Phase 2.1 rework cached path lists and bounded the parallelism,
every page still paid one `fileSize` channel call per asset
(audit F-04: at 50k photos, ~50k serialisable size queries), each
screen's first page re-listed the library, and the shared scan
(ScanRepository, solutions 4.2) paged through the same calls.

Verified in the photo_manager 3.12.0 sources before designing:
its converted entity map carries NO file size (`fileSize` is a
separate per-id channel call → one ContentResolver query per
id), so the pass that must carry size cannot be the plugin's.
The fix plan explicitly allows the alternative used here: a
small native MediaStore query of our own — same idea, our code.

Per AGENTS.md, unspecified decisions take the simpler / cheaper /
more private option and are recorded; the owner additionally
required visible behaviour to be preserved exactly (same assets,
same order, same filters, same partial-access handling), which
outranks Cleanup's choices wherever the two differ.

## Decision

1. **Own native enumeration.** `MediaEnumerationChannel.kt`
   (registered by MainActivity, channel
   `mobile.wipe.app/media_enumeration`) runs ONE query per type
   (Images / Video external tables) on a background executor and
   returns primitive row maps. Read-only; no image bytes ever
   cross the channel (zero-dimension repair reads file HEADERS
   only, see 4). Dart reaches it through
   `NativeMediaEnumerationGateway`, behind the
   `MediaEnumerationGateway` seam so tests count calls.
2. **Order is MediaStore id descending, merged across types** —
   NOT Cleanup's `date_added DESC`. wipe.'s visible order today
   is the plugin's default: Klara sets no explicit orders, and
   the plugin's empty-orders fallback is `_id DESC`. Ids are
   unique across the image/video tables, so merging the two
   per-type passes by id reproduces the mixed-type order
   exactly. Behaviour preservation outranks Cleanup's sort.
3. **Field semantics mirror the plugin's cursor conversion**,
   because the app was built on them: createDate = DATE_TAKEN
   in whole seconds when nonzero else DATE_ADDED (the plugin
   truncated to seconds; its Dart getter scaled back);
   modifiedDate = DATE_MODIFIED scaled likewise, never null;
   favourite = IS_FAVORITE on API 30+, false below;
   relativePath on API 29+, null below. The month filter
   compares DATE_ADDED in whole seconds, both ends inclusive —
   the plugin's create-time condition, identically.
4. **The list set mirrors the plugin's paged set; the row
   set is the wider union that also feeds id resolution.**
   Selection `BUCKET_ID IS NOT NULL` (the plugin's
   whole-library album selection). The plugin's paged lists
   carried a second condition — its size condition
   (CommonFilterOption.sizeWhere): MediaStore `WIDTH > 0
   AND HEIGHT > 0` for images, no dimension condition for
   videos, active on every wipe. list because the app's
   FilterOption never ignored size. The pass mirrors it at
   the Dart list level: pages and the scanner source exclude
   an image whose STORED width or height is 0, judged on the
   raw store columns (`storeWidth`/`storeHeight`), which
   ride along next to the header-repaired dimensions — a
   header-repaired row (store 0, header real) was still
   never listed by the plugin. (This precision is the stage
   checker's Finding A, fixed after the stage: the first
   version of this section claimed the mirror without the
   condition.) Id resolution does NOT apply the rule: it
   mirrors the plugin's per-id entity path, which carried no
   list filter, so a stored-dimension-zero image still
   resolves by id exactly as before. Rows whose backing file
   is gone are flagged and skipped by asset lists (the plugin
   skipped them) while still counting for bucket existence
   (the plugin's path list never checked backing files); a
   zero width/height is repaired from the file header —
   bounds decode for images, metadata retriever for videos,
   as the plugin repaired from EXIF/retriever.
   (Substitution noted: bounds decode reads the same header
   dimensions without depending on a transitive plugin
   dependency for EXIF classes.) Cleanup's `_size > 0`
   selection is NOT adopted: the plan's change list does not
   drop assets, and a size-0 row the plugin listed must stay
   listed.
5. **A narrow service, off the MediaService interface** (the
   LibraryChangeSource precedent and Stage 1's store):
   `LibraryEnumerationService` is constructed once in
   InitialBinding and injected into its two consumers —
   MediaServiceImpl (pages and id lookups served from the
   memoised pass) and ScanRepositoryImpl (each scan run forces
   ONE fresh pass and pages over its list). MediaService test
   fakes are untouched. The screen-level sharing the plan asks
   for already existed (ScanRepository: one memoised run,
   start-joins, replay for late subscribers — verified, not
   rebuilt); this stage adds the pass-level guard below it:
   concurrent enumerations join the single in-flight pass.
6. **Memoisation and freshness.** A completed pass is memoised
   until: the granted permission changes (the media service's
   existing invalidation hook also invalidates the pass — a
   limited grant's rows are a subset and must never serve a
   fuller one), the library-change stream fires (the pass
   subscribes to the same AppLifecycle stream the deck and hub
   reconcile on), or a scan forces a fresh pass. A generation
   counter stops a pass invalidated mid-flight from memoising
   its possibly-stale rows. A failed pass is never memoised.
7. **Legacy path kept as fallback.** If the native pass fails,
   or names an album the pass does not know (a bucket created
   after the pass ran — the plugin path is authoritative for
   it), getAssets/getAssetsByIds serve through the Phase 2.1
   plugin path, unchanged. In that degraded mode the per-asset
   size calls return; the mode is entered only on failure, the
   same shape as the scanner's isolate fallback (solutions 5.1).
   An album is "known" to the pass when any row of a covered
   kind names its bucket (see 4); the plugin's whole-library
   album id (`isAll`, as getAlbums reports it) means no bucket
   filter. getAssetsByIds treats an id absent from a completed
   pass as gone (its contract is skip, never fail); freshness
   for genuinely new ids is covered by 6.
8. **Screenshot marking in the pass.** `MediaAsset.isScreenshot`
   is computed as the asset is listed (both the enumeration
   mapping and the legacy mapping) from the file name alone,
   using the teardown's exact rules (contains `screenshot` /
   `screen_shot` / `screen-shot`, or starts with `screenshot_` /
   `screen_`). Smart-deck MEMBERSHIP keeps its existing
   album/title predicate in this stage — membership is grouping
   behaviour, which is Stage 4's territory, and silently
   widening/narrowing a deck would change visible behaviour.
9. **Scan totals and failure shape on the new source.** The
   progress total is the pass's exact length (replacing the
   largest-album estimate on this path); a failed pass returns
   the page-0-failure shape (no pages, no checkpoint save, no
   prune, pageFailed set). Page size, checkpoints, cancel/pause
   boundaries and the prune-after-full-enumeration rule are
   unchanged.
10. **Bounded reads unchanged.** Checks never read originals:
    analysis thumbnails were already bounded (128px, far under
    the plan's 1024×1024 cap) and stay so; the enumeration reads
    no image bytes at all. Thumbnail display still resolves an
    AssetEntity via `fromId` on first sight (LRU-cached in the
    media service) — enumeration rows are not plugin entities,
    and this stage does not change that path.
11. **No separate blur pass exists to preserve.** Blur/dark
    scores are computed inside the per-page thumbnail analysis
    batch in today's code (thumbnail fetches already run at
    concurrency 8, Cleanup's blur-pass bound); per the stage
    rule, no second pass was invented.
12. **Accepted limits.** (a) The deck's first page now waits for
    one full metadata pass instead of one 50-asset page; the
    splash warm-up starts the pass, and every later page is a
    memory slice. No speed is claimed either way — this VM has
    no device to measure on. (b) The per-type external tables
    cover the primary storage volume; the plugin's Files-table
    query could in principle see extra volumes on rare
    multi-volume devices. (c) Chat-folder tagging (Cleanup has
    it) is not in the plan's change list and was not built.
