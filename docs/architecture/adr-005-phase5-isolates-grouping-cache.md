# ADR-005 — Phase 5 isolate, grouping, and cache decisions

## 1. Isolate shape: `Isolate.run` per batch, no long-lived worker (5.1, 5.2)

Analysis runs as one `Isolate.run` per scanner page-batch (never
per photo), and grouping as one `Isolate.run` per grouping call
(hub list-decks, Duplicates regroup). A long-lived worker was
considered and rejected: it would need a port protocol, a
lifecycle (spawn, restart on death, shutdown on dispose), and
back-pressure for page batches — all for no measured benefit,
since batch granularity already amortizes spawn cost (a page is
50 small thumbnails; a grouping call is one pure function over
in-memory data) and bounds memory (at most one page of analysis
thumbnails in flight). If a future profile shows spawn cost
dominating on small libraries, a worker can replace `Isolate.run`
behind the same runner typedefs without touching callers.

Isolates cannot touch platform plugins: photo_manager and every
other platform channel lives on the main isolate. So the split is
strict — the main isolate fetches thumbnails and enumerates the
library; the worker receives only bytes + asset facts and returns
only hashes and scores. No photo content leaves the device, and
no decoded pixels leave the worker file.

## 2. Single resize NOT adopted (5.1)

The solutions doc suggested a single resize for both grid sizes.
It was NOT adopted: the 8x8 hash grid and the 64x64 blur/dark
grid are computed by independent resizes today, and deriving the
hash grid from the blur grid (or any single-resize change) would
change hash values for existing libraries, change grouping
suggestions, and force a version bump plus full re-analysis —
with no user-visible benefit. The isolate move itself removes the
UI-thread cost, which is the actual F-20 complaint. The
version-bump mechanism built in 5.3 exists for any future
algorithm change that genuinely needs one.

## 3. Threshold-0 reconciliation (5.2)

`groupExactHashes` now buckets by (hash, width, height) instead
of hash alone, so threshold 0 implements `isExactDuplicateOf`
exactly (hash AND dimensions). Before, two photos sharing a hash
but not dimensions grouped as "exact" at slider 0 — they no
longer do. They can still group at threshold > 0 as similar
(similarity is distance alone, by definition). This is the one
intentional behaviour change in Phase 5, and it is the
conservative direction: fewer photos are offered for deletion
together at slider 0, never more. Proven by the threshold-0
trust-flow test (same hash, different dimensions, must NOT
group at 0, MUST group at > 0).

## 4. Progressive hub landing + stale-result guards (5.2)

The hub sets `ready` as soon as the scan completes; bursts and
duplicates resolve off-isolate afterwards and land when done
(the view already hides empty decks, so the tiles simply
appear). Duplicates-screen regroups run off-isolate with the
previous groups staying visible until the new ones land (no
flicker to an empty list). Both controllers guard results with
a generation counter (`AsyncGuard`): a result from an older
scan, an older slider value, or a disposed controller is
dropped, never applied. Duplicates additionally tracks the
in-flight threshold, so dragging back to the already-applied
value and releasing supersedes a still-running regroup for
another value instead of letting it land under the wrong slider
position. Runners are constructor-injectable, so tests prove
ready-before-grouping and stale drops with gated runners
instead of timing assumptions.

## 5. Degraded fallback semantics (5.1)

If the worker isolate fails to spawn, the scanner runs the
identical batch synchronously on the UI thread (same function,
same outputs) and reports the degraded state exactly once per
scan, on the first fallback page. The hub shows a "Scanning is
slower than usual." line while scanning degraded; the flag
resets on the next scan so it never lingers. Memoised replays
never report degraded: a replay re-analyses nothing, so a
historical degraded flag must not show a "slower" state for an
instant replay. The Duplicates screen has no degraded UI by
design (its loading state is transient); the flag is on the
scan result for any consumer.

## 6. Cache fingerprint + prune rules (5.3)

A cached analysis is fresh only when ALL of these match the
asset: algorithm version (`analysisAlgorithmVersion`, currently
1), width, height, sizeBytes, and modified date (from the
platform entity's `modifiedDateTime`, mapped at both media
construction sites). A modified-date component matches when
BOTH sides lack it and mismatches when exactly one side lacks
it — an unknown is never silently treated as unchanged.
Old-version entries (including pre-versioning entries, which
read back as version 0) are re-analysed, never mixed.

Prune runs only after a FULLY completed scan: the live id set
comes from full enumeration, so a cancelled or page-failed scan
must not prune — unseen assets are not deleted assets. Prune
failure is ignored by the scan (the next full scan retries).
Prune writes only when something was actually removed, so a
scan with no deletions pays no rewrite. All analyses writes
(including prune) go through the Phase 4 atomic tmp+rename
store, so a kill mid-prune never leaves a torn cache file.

## 7. Phase 6 gate evidence (carried forward, not decided here)

Phase 4 already resolved write amplification (one write per
1.5 s coalescing window, atomic writes) and 5.3 bounds cache
growth (fingerprint re-analysis + full-scan-only prune).
Residual JSON costs that remain O(library) are full-file decode
on load (`loadAnalyses` decodes the whole `klara_analyses.json`
per scan start plus hub seed) and full-file rewrite on
checkpoint saves. At 50k entries the file is roughly 5–10 MB;
that cost is measurable on host with a synthetic 50k fixture
but was not measured on device in this program. The solutions
doc's Phase 6 gate says to enter only if Phase 0/4 evidence
confirms the 50k need, while the project's own requirement
expects yes (requirements §7 Phase 3: large-library
performance, 50,000+ photos). Both sides are recorded; the
enter/skip decision belongs to the parent/owner, not to this
phase.
