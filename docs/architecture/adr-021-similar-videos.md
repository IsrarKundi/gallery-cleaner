# ADR-021: Similar Videos — Frame Sampling, Native Extraction, Memberships (fix plan Stage 6)

## Context

Stage 6 adds the Similar Videos deck. Cleanup's recovered
settings (teardown notes/algorithms.md §6) fix the shape:
videos of 400 MB or smaller; frames spread 2–10 s apart,
normally 7, at most 13; each frame scaled to exactly 9×8 and
run through the same CombinedHash pipeline as photos, under
the normal-photo compare rule; `minMatchedFrameCount = 2`;
plus a 100 MB "big file" mark whose gating role the teardown
could NOT recover (UNKNOWN). wipe. had no similar-videos
feature, no video duration anywhere in its model (the Stage 2
enumeration carries none), and no way to obtain frames at
chosen timestamps (photo_manager returns a poster frame).

## Decisions

1. **The sampling rule is derived, and the derivation is
   recorded.** The settings carry three numbers — frameCount
   7, maxFrameCount 13, interval [2 s, 10 s] — not a formula,
   and the teardown's extraction note (`ih/b.a()` = N evenly
   spaced timestamps including both ends) fixes the shape but
   not how N is chosen. wipe.'s reading, implemented as the
   pure function `videoFrameTimestamps`: timestamps are
   evenly spaced including both ends; the count is 7 while
   7 frames keep the gap inside [2 s, 10 s]; it grows toward
   13 (smallest count whose gap fits) when the gap would
   exceed 10 s, and shrinks (largest count whose gap fits)
   when the gap would fall under 2 s. A video shorter than
   2 s cannot honour the floor and still gets both ends.
   When the 13 cap binds (videos over ~2 minutes), the gap
   stays above 10 s — that is what "at most 13" means. All
   arithmetic is integer microseconds, so the rule is exact
   and unit-tested at the boundaries.

2. **Frame fingerprints are Stage 4's, computed from the
   9×8 raster itself.** The native side returns each sampled
   frame as a PNG of an exactly 9×8 bitmap; the Dart side
   feeds those bytes through the unchanged photo fingerprint
   code (`computeFingerprint`), whose colour summary then
   runs over the 9×8 raster and whose dHash consumes the
   same raster — the construction the teardown recovered for
   Cleanup's video path (`a.a.P()` on the 9×8 frame).
   Comparisons use `areSimilar` with the photo class, never
   the screenshot class.

3. **Matching pairs are distinct pairs; the required count
   is the teardown's formula.** `ch/d`'s exact counting
   semantics were not readable (JADX-mangled), so wipe.
   counts greedily in timestamp order: each frame takes the
   first still-unmatched counterpart it is similar to, and a
   counterpart is consumed once — one static frame cannot
   satisfy the count against many. The requirement is
   `max(min(2, sizeA, sizeB), 1)` from the teardown; with two
   readable videos (each sampling ≥ 2 timestamps) it is
   simply 2. A video with no readable frames never matches
   (Cleanup's invalid-sentinel outcome).

4. **Grouping is the stills seed rule with the video
   predicate.** Date order (createDate, id tie-break), a
   video joins only if similar to the seed itself, groups of
   1 dropped — the same `cc/a2` shape Stage 4 implemented
   for photos. Similar-video groups persist with their seed
   and NO keeper: a swipe deck has no keeper concept, and
   the keeper machinery belongs to the photo-only Duplicates
   screen.

5. **Frame extraction is our own native channel, like
   Stage 2's enumeration.** `VideoFrameChannel`
   (`mobile.wipe.app/video_frames`, MediaMetadataRetriever
   over the video's content URI): `getDuration` (metadata
   key 9 — the enumeration carries no duration, so it is
   read here, from the same retriever as the frames) and
   `extractFrames` (one 9×8 PNG or null per requested
   timestamp, OPTION_CLOSEST_SYNC_FRAME). The scaled-frame
   platform call exists only from API 30; below it the full
   frame is fetched and bitmap-scaled (minSdk is 24). The
   two downscales can differ slightly by API level, which is
   harmless under ADR-019's self-consistency rule
   (fingerprints are only compared within one device build).
   All channel work runs on one background executor —
   extraction is sequential by design. Like Stage 2's
   channel, this Kotlin has not been compiled or run on a
   device in this environment; on-device verification is
   outstanding and is the owner's human check.

6. **The video pass is phase B4 of the shared scan.** After
   the photo phases, before the single membership save:
   candidates pass the 400 MB gate, extraction runs one
   video at a time with cancellation honoured between
   videos, fingerprints are computed with the scanner's own
   batch runner (worker isolate, same degraded fallback),
   and the resulting groups merge into the same snapshot —
   so a cancelled pass persists nothing, and the freshness
   rule covers videos exactly as it covers photos: an
   unchanged library reuses the snapshot and extracts no
   frames at all; any fact change recomputes the video pass
   along with everything else (ADR-019 Decision 2).

7. **Persistence: memberships algorithm v2, DB schema v4 —
   and no frame fingerprints, ever.** `ScanGroupKind`
   gains `similarVideos`; kinds are text in both stores, so
   no table changes were needed. The schema bump to v4
   exists so the version chain and downgrade guard
   recognise Stage 6 builds; its upgrade restamps the
   membership version 0 (a v3 snapshot predates video
   groups and must never read as fresh), mirroring the
   2 → 3 upgrade. The JSON→DB import stamp follows
   (`kDbSchemaVersion` 4). Frame fingerprints join photo
   fingerprints in the never-persisted class (ADR-019
   Decision 1): only memberships and asset facts are stored.

8. **The deck is an ordinary smart deck.** `SmartDeckId.
   similarVideos`: hub row fed from the scan's memberships
   (flattened groups, stored order), scan-gated readiness
   like blurry/dark, title/icon/subtitle through the shared
   meta, opening as a marks-only swipe deck whose delete
   marks surface in the Trash-tab union under ADR-015 —
   the option most consistent with the existing membership
   decks, and the only one that reuses the smart-deck
   machinery whole. No parallel flow was built.

9. **Observed, not built: the 100 MB big-file mark.**
   Cleanup's settings carry `bigFileThresholdMB = 100`, but
   the teardown marks its gating role UNKNOWN and the plan's
   exact change contains no UI for it. wipe. builds nothing
   for it; the constant lives in video_similarity.dart so
   the number has exactly one home if its role is ever
   established.

10. **Screen recordings are plain videos.** Cleanup
    separates recordings by file name only behind a flag
    that defaults off (recordings then treated as videos).
    wipe. has no recording marking and builds none: every
    video is a video for this check.

## Consequences

- A changed library costs one sequential native pass over
  its ≤ 400 MB videos (duration + up to 13 tiny frames each)
  on top of the photo phases; an unchanged library costs
  nothing. No timing claim is made — nothing was measured
  on a device.
- The Similar Videos deck appears only when a scan completes
  with at least one similar pair; the Videos (metadata) deck
  is unchanged.
- Sample-video validation (stage report) exercised the
  shipped sampling/fingerprint/compare/grouping code over
  generated videos: a re-encode, a brightness shift and a
  trim of one base video all grouped with it (6, 6 and 5
  matched frame pairs), an unrelated video matched nothing.
  The harness used ffmpeg's scaler as the frame source; the
  on-device scaler is the platform's (Decision 5).
- Downgrade note (the established pattern): a pre-Stage 6
  build opening a v4-stamped database treats it as newer
  and fails migrated methods explicitly rather than
  guessing; a Stage 6 build rescans memberships once after
  upgrading from any earlier version.
