# ADR-018: Marks Store, Completed Atomic Writes, and the Deferred Membership Reshape (fix plan Stage 3)

## Context

The Cleanup teardown (notes/pipeline.md) showed the competitor
saves three JSON files (asset info, group memberships,
duplicate reference), every save atomic (write `<name>.tmp`,
flush + sync, rename over the target, copy on rename failure),
hashes never persisted, and swipe progress in small per-feature
stores.

wipe.'s reality when Stage 3 started was NOT the audit-era one
the plan text describes. The repo's own solutions Phase 4/6 had
already landed: JsonFileStore gives every JSON file an
in-memory snapshot, serialised writes and tmp+flush+rename
atomicity, and the Drift database (ADR-006) had replaced the
files as the authoritative store — analyses, trash, history,
snoozes and completions are per-row, and the JSON -> DB
migration (verified, marker-gated) already exists. Two
audit-era shapes survived inside that newer structure:

- **Sessions were still one blob per filter.** The v1 schema
  stored a session's whole marks map as JSON text in its row,
  so every swipe re-encoded and rewrote the entire map
  (F-08's quadratic shape, one level down: at 50k marks the
  blob is ~1.1 MB per swipe). Saves were also unserialised at
  the store level.
- **JsonFileStore's atomic write had no copy fallback** —
  Cleanup's pattern has one for the filesystems where a
  rename is refused.

And one plan item collided with shipped behaviour: Stage 3's
"save memberships, not hashes" presumes comparisons can be
recomputed from memberships on demand (Stage 4's design).
Today the persisted analysis — above all its hash — is
load-bearing in three places (Decision 5).

Per AGENTS.md, unspecified decisions take the simpler /
cheaper / more private option and are recorded; the owner
additionally required visible behaviour to be preserved
exactly, which outranks reshaping storage for its own sake.

## Decision

1. **Atomic writes completed, in the one shared writer.**
   `AtomicFileWriter` implements Cleanup's exact sequence —
   write `<target>.tmp` in the same directory, flush (the
   dart:io sync), rename over the target, and on a refused
   rename copy the temp file over the target and remove it.
   JsonFileStore (behind settings, the Stage 1 reminder
   state, and the legacy JSON stores) writes only through it.
   Database writes need no file-level pattern: they are
   SQLite transactions in WAL mode, atomic by engine.
   Audit of every other save path: the only remaining direct
   file write in the app is the share service's summary PNG
   into the cache directory — a regenerated export artifact
   under a fixed name, not app state — so it stays a plain
   write, recorded here as audited, not missed.

2. **Swipe marks get their own store (schema v2).** Two new
   tables — `marks (filter_key, asset_id, mark)` and
   `session_favourites (filter_key, asset_id)` — and
   `sessions` slimmed to the per-deck resume position.
   `SessionStore.save` keeps the LocalService whole-session
   overwrite semantics but writes only the delta: it diffs
   the incoming session against a mirror of what it has
   persisted (loaded from the database on a filter's first
   touch) and, in one transaction, upserts changed mark rows,
   deletes removed ones, and touches the progress row only
   when the index moved. One swipe = one small mark row (+
   the tiny progress row when the index moved) — proven by
   row-write counters in tests, the JsonFileStore.diskWrites
   precedent. Saves serialise on one future chain, closing
   the unawaited-interleave race F-08 named. There is NO
   coalescing or debounce on this path: every mark commits
   in its transaction, so a hard kill right after a swipe
   cannot lose it (the Phase 4 1.5 s window ADR-006 already
   retired for migrated stores stays retired). The mirror is
   a write-diff cache only — loads always read the database;
   every production write flows through the single bound
   LocalService, so the mirror cannot drift in the app, and
   a second store instance starts cold and re-reads first.
   The LocalService interface did not change: deck, Review,
   smart decks, Duplicates and the Stage 1 reminder engine
   keep working unmodified.

3. **Migration, both sources, no-loss by construction.**
   (a) Database v1 -> v2 runs in drift's `onUpgrade`, inside
   the migration transaction: create the two tables, copy
   every session blob's entries VERBATIM (mark-name strings
   are not parsed in transit; the one read-time rule —
   unknown name reads as keep — is unchanged), then rebuild
   `sessions` without the blob columns via `alterTable`. A
   crash mid-upgrade rolls everything back (still v1, retry
   next launch); a committed upgrade never re-runs. A blob
   that fails to decode entirely is never dropped: its raw
   text is preserved in `meta_entries` under
   `quarantine:session:<filterKey>` and the session's
   progress row still migrates. (b) Pre-database installs are
   unchanged in shape: the existing verified JSON -> DB
   import now writes through the v2 stores (sessions land as
   mark rows), and its stamp records schema '2'. The
   downgrade guard is untouched — a database stamped by a
   newer build fails explicitly, never silently. Fixture
   tests prove both paths: a byte-level v1 database (exact
   v1 DDL, real marks/favourites/trash/history) and old-format
   JSON files each arrive with every entry intact, and a
   second launch changes nothing.

4. **The legacy JSON implementation keeps its shape, by
   decision.** `LocalServiceImpl`'s whole-file sessions (with
   their Phase 4 coalescing) remain exactly as they were: it
   is the migration SOURCE, the pre-migration fallback, and
   the settings store. Rebuilding it into per-mark files
   would rewrite the one component every migration reads
   through, to improve a path the app leaves behind on its
   first verified launch. The authoritative marks path —
   the one every migrated install actually swipes on — is
   Decision 2's store.

5. **DEFERRED to Stage 4, as a recorded stuck point: the
   asset-info / membership / duplicate-reference reshape
   and removing the persisted hash.** The brief for this
   stage anticipated exactly this: where today's behaviour
   genuinely depends on a persisted hash, record it — do
   not silently keep the field, and do not break the
   behaviour. The dependence is real, threefold:
   - The Duplicates similarity slider (requirements §7
     Phase 2; photo_analysis.dart: Hamming threshold 0-10,
     default 5) regroups LIVE from persisted hashes.
     Memberships persisted at one threshold cannot serve
     another. (Fix plan Stage 7 removes the slider — its
     stage, not this one; behaviour must not change early.)
   - Keeper suggestion compares members' blur scores
     (grouping.dart), and the Blurry/Dark decks read
     per-asset scores — membership lists carry neither.
   - The scanner's freshness rule (solutions 5.3) stores
     sizeBytes / modifiedDateMs / algorithmVersion WITH the
     hash so a rescan reuses cached analyses instead of
     re-fetching and re-decoding a thumbnail per photo —
     the cost Phases 2/5 eliminated. Cleanup's way out
     (persist memberships; compute fingerprints when a
     comparison needs them) IS Stage 4's build: grouping
     moves into the scan, memberships become the persisted
     product, and only then can the hash column go.
   Until then the `analyses` table remains the scan-result
   store. Its per-page saves are already per-row batch
   upserts in database mode (F-09's whole-file rewrite
   survives only in the legacy JSON fallback of Decision
   4), and its width/height/size/modified columns are the
   asset-info facts Stage 4's split will lift out — kept
   beside the hash deliberately, because the freshness rule
   needs them atomic with it. The hash field is therefore
   kept BY THIS RECORDED DECISION, flagged as Stage 4's
   removal target — not by oversight, and not silently.
