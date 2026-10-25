# ADR-006 — Phase 6 gate decision: BUILD with Drift

## 1. Gate measurement (host, real code paths, 3 runs)

Method: a temporary benchmark test (run, recorded here, then
deleted — timing tests do not belong in the deterministic suite)
drove the real `LocalServiceImpl` against temp directories:

- Fixture: 50,000 `PhotoAnalysis` entries through the real
  `toJson` shape (assetId, 63-bit hash, 4032×3024, blur score,
  luminance, sizeBytes, modifiedDateMs, algorithmVersion 1).
  Hashes used positive 63-bit values (Dart ints are signed
  64-bit, so full 64-bit literals are invalid); the resulting
  file size is within ~10% of a production file.
- Decode: a FRESH `LocalServiceImpl` instance per round called
  `loadAnalyses`, so nothing was served from the Phase 4
  in-memory snapshot — this is a cold full-file decode, exactly
  what scan start and hub seed pay today.
- Rewrite: a checkpoint-style `saveAnalyses` of one 50-entry
  page merged into the 50k file, which rewrites the whole file
  (the Phase 4 scanner checkpoints every 20 pages).

Results (medians of 3 runs):

| Measurement | Runs (ms) | Median |
|---|---|---|
| File size at 50k | — | 10,040,912 bytes (9.58 MiB) |
| Full-file decode (`loadAnalyses`, cold) | 236, 318, 328 | **318 ms** |
| Checkpoint rewrite (50-entry page into 50k) | 177, 189, 217 | 189 ms |
| Bulk write (full 50k save, context only) | 280, 296, 405 | 296 ms |

Memory (ESTIMATE, not measured — labelled as such): decode
materializes the full `Map<String, dynamic>` from `jsonDecode`
AND the full `Map<String, PhotoAnalysis>` simultaneously, so
transient heap is several times the 9.58 MiB file (roughly
30–50 MB by object-overhead reasoning). No RSS measurement was
taken; do not quote this as measured.

## 2. Decision: gate CONFIRMS — build Phase 6

The brief's gate is an OR: decode > ~250 ms OR rewrite >
~500 ms at 50k on host. Decode median 318 ms clears its bar
(2 of 3 runs above it, median above it). Rewrite alone
(189 ms) does not clear its bar, but the gate does not require
both. Supporting evidence, all recorded rather than assumed:

- Host hardware is faster than a mid-range phone, so host
  hundreds-of-ms understate device cost.
- Decode is paid per scan start AND hub seed (ADR-005 §7), not
  once per install.
- The file grows unboundedly with library size: O(library)
  decode and rewrite, forever, with no per-row path.
- Requirements §7 demands 50,000+ library performance.
- Arithmetic from the measured median (not a separate
  measurement): a 50k scan at 50-entry pages checkpoints every
  20 pages, i.e. ~50 full-file rewrites × ~189 ms ≈ 9.5 s of
  cumulative rewrite work spread across one scan.

## 3. Wrapper: Drift (doc default + recorded owner default)

Drift is the solutions doc's default wrapper. It is also the
only wrapper testable on this host VM: sqflite is a platform
plugin (Android/iOS only, untestable here), while Drift over
`package:sqlite3` runs against the system `libsqlite3.so.0`
present on this VM. Codegen via `drift_dev` + `build_runner`
is accepted (the doc's sqflite escape hatch exists for an
owner who rejects codegen; the owner default on record is
Drift, so no new question is asked).

## 4. Migration scope: 6 files migrate, settings stays JSON

Solutions 6.1 excludes settings ("Settings stays a tiny JSON
file — it is not migrated") and 6.2 requires fixtures for
"all 7 files". 7 minus the settings exclusion = 6 migrated
stores: analyses, sessions, trash, history, snoozes,
completions. Fixtures cover all 7 files: 6 migration fixtures
plus 1 settings-retention fixture proving migration leaves
the settings file byte-identical. Snoozes/completions are
tiny, but migrating them is mechanical and leaves exactly
one JSON store (settings) behind, so 6.3's "no migrated store
reads JSON" is complete and checkable.

## 5. Backup retention: files stay on disk

After the verification pass, the JSON files are retained on
disk as dormant backups. Only the JSON *read paths* for
migrated stores are removed (6.3); the files themselves are
never deleted by this phase — deleting user data files without
the owner's word is out of scope, and a 10 MB dormant file is
negligible next to a photo library. The owner may delete them
later, or a future cleanup phase may, with his word.

## 6. Session durability improves (recorded behaviour change)

With per-row SQLite upserts, a session save commits
immediately in its transaction — the Phase 4 1.5 s coalescing
crash window disappears for migrated stores (an improvement,
not a regression: strictly more durable). `flushPendingWrites`
stays in the interface and keeps working at every mandatory
flush call site; for SQLite paths it awaits init/migration
and is otherwise immediate. Consequence for tests, documented
not hidden: Phase 4's JSON-store-level coalescing assertions
("1,000 marks cost one disk write") move to `JsonFileStore`
unit tests, where that store still exists (settings); new
session-level tests assert immediate durability against the
DB impl. Old assertions are re-scoped to the store that still
has the semantics, not deleted to make a gate pass.

## 7. Migration mechanics (implemented in 6.2)

- Read through the existing JSON `LocalServiceImpl`, so the
  Phase 4 per-entry salvage semantics carry over for free.
- Write through the DB impl with primary-key upserts, so a
  re-run after an interrupted import converges instead of
  duplicating ("re-runnable, never half-migrated").
- Verification pass (row counts + spot-check values) runs
  before the migration marker is set in the DB meta table;
  only then is the DB authoritative.
- DB file missing on launch: recreated, then re-imported
  from the JSON backup if one exists, else fresh empty.
- Downgrade (DB schema version above the app's): explicit
  `Result` failure, never a silent loss or a crash.
- Corrupt JSON entry: salvaged per entry, reported via the
  migration report, migration continues.
- The `LocalService` interface is UNCHANGED: no new methods,
  so the 35 test fakes and the golden-path fake keep working.
  Migration lives inside the DB impl plus a separate runner
  class, never in the interface.
