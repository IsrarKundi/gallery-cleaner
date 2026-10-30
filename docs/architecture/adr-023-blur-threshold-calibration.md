# ADR-023: Blur Threshold Calibration — wipe.'s Own Line at 4.2

## Context

Stage 4 (ADR-019, decision 6) shipped the blur decision rule
with Cleanup's built-in fallback numbers unchanged: score =
2.3·reblur + 1.0·edgeWidth + 0.75·coherence over the three
classic gradient-domain measures, blurry at score ≥ 2.2. The
numbers were deliberately NOT retuned in that stage: Cleanup's
fallback weights/threshold were calibrated against its own
native measure scales, which are UNKNOWN, and wipe.'s measures
are the classic definitions those names denote — a different
scale. The stage's sample validation (stage-4 report §3) made
the mismatch concrete: on the four sharp free-license sample
photos the originals scored 2.62–3.78, so ALL of them were
flagged blurry at the 2.2 line, while genuinely blurred
variants scored higher in clean monotonic order. The
calibration choice was parked as the owner's decision.

On 30 Oct 2026 the owner ruled: set wipe.'s own line — about
4.2, the value the stage-4 evidence pointed to — over keeping
Cleanup's 2.2.

## Decisions

1. **The blur line is 4.2, wipe.'s own.** `blurScoreThreshold`
   in blur_detection.dart moves from 2.2 to 4.2. The score
   FORMULA does not change: the weights stay Cleanup's fallback
   2.3 / 1.0 / 0.75, the measures stay the classic definitions,
   the null rule (no reblur and no edgeWidth → no score → never
   flagged) is untouched. Only the threshold constant moves.

2. **The evidence for 4.2.** Re-validation with the shipped
   code on the same four samples (dog, food, lake, woman —
   free-license store photos at 1200×800) plus PIL GaussianBlur
   variants at radii 1/2/4/8, variants saved losslessly:

   | photo | orig | radius 1 | radius 2 | radius 4 | radius 8 |
   |---|---|---|---|---|---|
   | dog | 3.151 | 3.955 | 5.713 | 8.663 | 11.094 |
   | food | 3.538 | 4.461 | 5.999 | 9.125 | 11.505 |
   | lake | 2.619 | 3.065 | 4.571 | 7.433 | 9.965 |
   | woman | 3.781 | 4.519 | 6.016 | 7.862 | 9.645 |

   At 4.2: no sharp original is flagged (max 3.781); every
   radius ≥ 2 variant is flagged (min 4.571); scores rise
   monotonically with radius in every series, as they did
   under the old line.

3. **The accepted trade-off: radius-1 blur straddles the
   line.** The radius-1 variants score 3.065–4.519: dog and
   lake fall under 4.2 (missed), food and woman clear it
   (caught). No single threshold separates radius-1 blur from
   sharp originals on these samples — their ranges overlap —
   so very light blur is knowingly under-detected rather than
   sharp photos being flagged. This is the owner's call,
   recorded so a future retune starts from the real numbers,
   not from a fresh surprise.

4. **Existing installs rescan: membership algorithm version
   2 → 3.** The persisted Blurry set is a snapshot built under
   whatever line was current when its scan ran; freshness is
   gated by `scanMembershipAlgorithmVersion`
   (`ScanMemberships.isFreshFor`), whose own rule is "bump
   whenever … blur … changes". Bumping only that constant is
   sufficient and is the whole migration: a version-2 snapshot
   loads, fails the freshness check, and the first scan under
   this build recomputes the matching phase and restamps at
   version 3 — the same mechanism Stage 6 used (1 → 2). No
   database schema change is needed or made (the Stage 6
   schema-v4 restamp was belt-and-braces for a new group kind;
   here no stored shape changes, and the stale stamp already
   forces the rescan on its own). A fresh install behaves
   exactly as before apart from the line.
