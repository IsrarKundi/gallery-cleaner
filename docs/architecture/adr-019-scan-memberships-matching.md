# ADR-019: Scan Memberships and Cleanup-Rule Matching (fix plan Stage 4)

## Context

Stage 3 (ADR-018, Decision 5) deferred the membership reshape
and the removal of the persisted hash to this stage, because
the persisted aHash was load-bearing in three places: the
Duplicates slider regrouped live from it, the keeper suggestion
compared persisted blur scores, and the scan freshness rule
avoided re-decoding thumbnails. Stage 4 replaces the matching
engine itself with Cleanup's recovered rules (teardown
notes/algorithms.md is the authority), which removes all three
dependencies at once:

- the fingerprint is a two-part value (64-bit difference hash
  + 24-number colour summary) computed during the scan and
  discarded — comparisons happen in the scan, not on a screen;
- similarity follows Cleanup's fixed compare table per class
  (photos / screenshots), so there is no user threshold left
  for a slider to set;
- blur is its own pass with Cleanup's fallback weights, its
  scores likewise transient.

## Decisions

1. **Grouping lives in the scan; the persisted product is
   memberships.** One scan writes one snapshot
   (`ScanMemberships`): asset-info facts, group memberships
   (similar / duplicate / blurry / dark) and the duplicate
   reference (per duplicate set: the main photo + its
   duplicates). No hash and no blur score is stored in any
   form; the serialised shape has no field that could carry
   one, and tests assert the stored keys and the SQL schema.

2. **Freshness replaces the per-asset analysis fingerprint.**
   Saved memberships are reused only when the snapshot's
   algorithm version is current AND every asset-info fact
   matches the live enumeration exactly (type, dimensions,
   size, modified date, edited flag, screenshot marking).
   Any difference recomputes the whole matching phase. This
   mirrors Cleanup (memberships persist, hashes do not) and
   the Stage 2/3 pattern of replacing state wholesale rather
   than patching it per asset. A cancelled or page-failed
   scan never overwrites the saved snapshot.

3. **The compare table is implemented exactly as recovered**
   (algorithms.md §2.2): colour distance is truncated to a
   long before the band checks; the fast-accept band is
   checked first, then the bands in list order, so a shared
   edge belongs to the first band containing the distance —
   photos: fast 0–4, 4–10 → colour ≤7, 10–18 → colour ≤5,
   cap d<18; screenshots: fast 0–2, 2–10 → colour ≤5,
   10–16 → colour ≤2, cap d<16. Validity gate: hash ≠ −1 and
   a non-empty colour matrix. Grouping is seed clustering
   over date order: a photo joins only if it matches the
   seed, never another member.

4. **The dHash bit convention is ours.** The native side's
   bit order/sign is unobservable (teardown: raster 9×8 is
   INFERRED); wipe.'s convention — bit set when the left pixel
   is brighter than its right neighbour — is fixed here and
   only ever compared against itself, so the choice cannot
   drift results between builds of this app.

5. **The edited flag is false until a source exists.** The
   duplicate key includes an edited flag; neither wipe.'s
   enumeration nor Cleanup's Android enumeration carries one
   (algorithms.md §3 constructs it false). `AssetInfo`
   therefore records false. Recorded so a future edited-flag
   source knows the key's last unknown is waiting for it.

6. **Blur measures are our classic implementations; the
   weights and threshold are Cleanup's fallback numbers,
   unchanged.** The three native formulas are UNKNOWN
   (algorithms.md §4), so reblur / edgeWidth / coherence are
   implemented as the classic gradient-domain measures those
   names denote (see blur_detection.dart), combined as
   2.3·reblur + 1.0·edgeWidth + 0.75·coherence, blurry at
   ≥ 2.2; a frame with neither reblur nor edgeWidth has no
   score and is never flagged (Cleanup's null rule). Sample
   validation (stage-4 report) shows these definitions with
   the fallback numbers flag the sharp originals too — the
   fallback numbers were evidently calibrated against
   Cleanup's own (unknown, server-tuned) measure scales.
   The numbers were NOT retuned in this stage; a calibration
   decision is the owner's (see the report's stuck point).
   **Superseded in part by ADR-023 (30 Oct 2026):** the owner
   set the threshold to wipe.'s own 4.2; the weights, the
   measures and the null rule in this decision stand.

7. **The Duplicates slider is removed** (owner decision,
   Stage 7, given early because the engine replacement forces
   it). The Duplicates screen now shows the scan's
   exact-duplicate groups; its layout redesign remains
   Stage 7's. The Similar deck is fed by the seed groups;
   the Blurry deck by the blur pass; the hub's duplicates row
   keeps its meaning ("Identical & similar") as the union of
   exact and similar memberships.

8. **Keeper suggestion is preserved, fed by the new blur
   measure.** Same rule as before — sharpest first, then
   largest size, then group order — with "sharpest" now the
   LOWEST Cleanup blur score (the new score grows with blur,
   the opposite direction of the retired Laplacian variance),
   and an unscored asset ranking below every scored one. The
   duplicate reference's main is this keeper; on a full tie
   the group order makes it the seed (earliest by date). No
   new quality rule was invented.

9. **Storage: schema v3.** The membership split lands as
   Drift tables (asset_infos / scan_groups /
   scan_group_members / duplicate_references /
   duplicate_reference_members) beside Stage 3's stores; the
   JSON store keeps one snapshot document of the same shape.
   The v2 → v3 upgrade (and the JSON → DB import) converts
   legacy analysis rows to FACTS ONLY at membership version 0
   and drops the analyses table: the old engine's groups are
   discarded and rescanned, never converted — converting
   them would mint phantom groups under rules they were
   never computed with. The analyses trio on LocalService
   remains only as that legacy migration surface.

10. **Smart-deck membership for screenshots uses Stage 2's
    marking.** `decksForAsset` reads `MediaAsset.isScreenshot`
    (Cleanup's file-name rules) instead of the old album/title
    guess (Stage 2 deferred this switch to Stage 4). Blurry
    and dark are no longer per-asset predicates at all; the
    hub applies them from the scan's memberships, gated on
    scan completion like bursts and duplicates.

## Consequences

- A scan reads each image twice (128 px fingerprint pass,
  512 px blur pass) when the library changed, and reads
  nothing at all when it did not.
- The Duplicates screen and hub decks change membership
  exactly where the new rules differ from the old engine —
  enumerated in the stage report (screenshots no longer mix
  with photos; flat/uniform frames are no longer flagged
  blurry; the blurry deck's calibration is the open point in
  Decision 6).
- Deleting the analyses table is one-way: a downgrade to a
  pre-Stage 4 build re-derives its cache from scratch (its
  own downgrade guard treats the v3 stamp as newer and fails
  migrated methods explicitly rather than guessing).
