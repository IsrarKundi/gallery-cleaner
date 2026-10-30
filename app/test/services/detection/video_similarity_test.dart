// Stage 6 pure-rule tests (fix plan Stage 6, ADR-021): the
// size gate, the frame-sampling rule derived from Cleanup's
// settings (7 normally, at most 13, gaps inside 2 s..10 s,
// both ends included), the pair predicate (photo compare rule,
// distinct pairs, teardown's required-count formula) and the
// seed grouping. No device, no platform channels: fabricated
// durations, sizes and fingerprints only.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/video_similarity.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _video(
  String id, {
  int sizeBytes = 10 * 1024 * 1024,
  DateTime? createDate,
  MediaAssetType type = MediaAssetType.video,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 1920,
    height: 1080,
    sizeBytes: sizeBytes,
    createDate: createDate ?? DateTime.utc(2026, 1, 1),
    title: id,
    albumName: 'all',
  );
}

/// A fingerprint whose dHash and flat colour put it at Hamming
/// distance 0 from an identical twin and far from [farPrint].
PhotoFingerprint _print(int hash, double band) {
  return PhotoFingerprint(
    dHash: hash,
    colorHistogram: List<double>.filled(24, band),
  );
}

final PhotoFingerprint _a = _print(0x0000000000000000, 1.0);
final PhotoFingerprint _aTwin = _print(0x0000000000000001, 1.0);
final PhotoFingerprint _far = _print(0x5555555555555555, 9.0);
final PhotoFingerprint _invalid = _print(-1, 1.0);

void main() {
  group('size gate (400 MB)', () {
    test('a video at exactly 400 MB is a candidate', () {
      expect(
        isSimilarVideoCandidate(_video('v', sizeBytes: maxSimilarVideoBytes)),
        isTrue,
      );
    });

    test('a video one byte over 400 MB is skipped entirely', () {
      expect(
        isSimilarVideoCandidate(
          _video('v', sizeBytes: maxSimilarVideoBytes + 1),
        ),
        isFalse,
      );
    });

    test('an image is never a candidate, whatever its size', () {
      expect(
        isSimilarVideoCandidate(_video('v', type: MediaAssetType.image)),
        isFalse,
      );
    });
  });

  group('videoFrameTimestamps', () {
    test('zero or negative duration samples nothing', () {
      expect(videoFrameTimestamps(Duration.zero), isEmpty);
      expect(videoFrameTimestamps(const Duration(seconds: -5)), isEmpty);
    });

    test('includes both ends, always', () {
      for (final int seconds in <int>[1, 5, 30, 90, 600]) {
        final List<Duration> stamps = videoFrameTimestamps(
          Duration(seconds: seconds),
        );
        expect(stamps.first, Duration.zero, reason: '$seconds');
        expect(stamps.last, Duration(seconds: seconds), reason: '$seconds');
      }
    });

    test('a mid-length video gets the normal 7 frames', () {
      // 30 s: gap 5 s. 60 s: gap exactly 10 s — still in bounds.
      expect(videoFrameTimestamps(const Duration(seconds: 30)).length, 7);
      expect(videoFrameTimestamps(const Duration(seconds: 60)).length, 7);
      expect(videoFrameTimestamps(const Duration(seconds: 12)).length, 7);
    });

    test('a long video grows toward the 13 cap to hold the 10 s gap', () {
      // 61 s: 7 frames would gap 10.17 s -> 8 frames.
      expect(videoFrameTimestamps(const Duration(seconds: 61)).length, 8);
      // 100 s: 11 frames at a 10 s gap.
      expect(videoFrameTimestamps(const Duration(seconds: 100)).length, 11);
      // 120 s: exactly the cap, 13 frames at a 10 s gap.
      expect(videoFrameTimestamps(const Duration(seconds: 120)).length, 13);
      // 10 minutes: still 13 (the cap binds; gap exceeds 10 s).
      expect(videoFrameTimestamps(const Duration(minutes: 10)).length, 13);
    });

    test('a short video drops frames to hold the 2 s floor', () {
      // 10 s: 6 frames at a 2 s gap.
      expect(videoFrameTimestamps(const Duration(seconds: 10)).length, 6);
      // 4 s: 3 frames at a 2 s gap.
      expect(videoFrameTimestamps(const Duration(seconds: 4)).length, 3);
      // 2 s: the two ends, gap exactly 2 s.
      expect(videoFrameTimestamps(const Duration(seconds: 2)).length, 2);
      // Under 2 s the floor is unreachable: still both ends.
      expect(videoFrameTimestamps(const Duration(seconds: 1)).length, 2);
    });

    test('gaps stay inside 2 s..10 s whenever the count allows', () {
      for (int seconds = 2; seconds <= 120; seconds++) {
        final List<Duration> stamps = videoFrameTimestamps(
          Duration(seconds: seconds),
        );
        for (int i = 1; i < stamps.length; i++) {
          final Duration gap = stamps[i] - stamps[i - 1];
          expect(gap >= videoMinFrameInterval, isTrue, reason: '$seconds');
          expect(gap <= videoMaxFrameInterval, isTrue, reason: '$seconds');
        }
      }
    });

    test('timestamps are strictly increasing and within the duration', () {
      final List<Duration> stamps = videoFrameTimestamps(
        const Duration(seconds: 47),
      );
      for (int i = 0; i < stamps.length; i++) {
        expect(stamps[i] >= Duration.zero, isTrue);
        expect(stamps[i] <= const Duration(seconds: 47), isTrue);
        if (i > 0) {
          expect(stamps[i] > stamps[i - 1], isTrue);
        }
      }
    });
  });

  group('requiredMatchedFrames (teardown formula)', () {
    test('two full lists require 2', () {
      expect(requiredMatchedFrames(7, 7), 2);
      expect(requiredMatchedFrames(13, 7), 2);
    });

    test('the smaller list caps the requirement', () {
      expect(requiredMatchedFrames(1, 7), 1);
      expect(requiredMatchedFrames(7, 1), 1);
    });

    test('the floor is 1 even for empty lists', () {
      expect(requiredMatchedFrames(0, 0), 1);
      expect(requiredMatchedFrames(0, 5), 1);
    });
  });

  group('videosAreSimilar', () {
    test('identical frame lists are similar', () {
      expect(
        videosAreSimilar(
          <PhotoFingerprint>[_a, _far],
          <PhotoFingerprint>[_a, _far],
        ),
        isTrue,
      );
    });

    test('one matching frame is not enough for full lists', () {
      expect(
        videosAreSimilar(
          <PhotoFingerprint>[_a, _far],
          <PhotoFingerprint>[_a, _print(0x2AAAAAAAAAAAAAAA, 4.0)],
        ),
        isFalse,
      );
    });

    test('two matching frames are enough, in any order', () {
      expect(
        videosAreSimilar(
          <PhotoFingerprint>[_a, _far],
          <PhotoFingerprint>[_far, _aTwin],
        ),
        isTrue,
      );
    });

    test('one counterpart cannot satisfy two frames (distinct pairs)', () {
      // Both of A's frames match B's single matching frame; the
      // second has nothing left to pair with.
      expect(
        countMatchingFrames(
          <PhotoFingerprint>[_a, _aTwin],
          <PhotoFingerprint>[_a, _print(0x2AAAAAAAAAAAAAAA, 4.0)],
        ),
        1,
      );
      expect(
        videosAreSimilar(
          <PhotoFingerprint>[_a, _aTwin],
          <PhotoFingerprint>[_a, _print(0x2AAAAAAAAAAAAAAA, 4.0)],
        ),
        isFalse,
      );
    });

    test('an empty list never matches (unreadable video)', () {
      expect(
        videosAreSimilar(const <PhotoFingerprint>[], <PhotoFingerprint>[
          _a,
          _a,
        ]),
        isFalse,
      );
      expect(
        videosAreSimilar(<PhotoFingerprint>[
          _a,
          _a,
        ], const <PhotoFingerprint>[]),
        isFalse,
      );
    });

    test('invalid fingerprints never match (hash -1 sentinel)', () {
      expect(
        videosAreSimilar(
          <PhotoFingerprint>[_invalid, _invalid],
          <PhotoFingerprint>[_invalid, _invalid],
        ),
        isFalse,
      );
    });

    test('a one-frame list needs only its one match (formula floor)', () {
      expect(
        videosAreSimilar(<PhotoFingerprint>[_a], <PhotoFingerprint>[_a, _far]),
        isTrue,
      );
    });
  });

  group('groupSimilarVideos', () {
    test('seed rule: matching a member is not enough (no transitivity)', () {
      // Frame prints: p/q/r families, near-twins 1 bit apart,
      // families mutually far (Hamming >= 18 and colour apart).
      final PhotoFingerprint p = _print(0x0000000000000000, 1.0);
      final PhotoFingerprint p1 = _print(0x0000000000000001, 1.0);
      final PhotoFingerprint p2 = _print(0x0000000000000003, 1.0);
      final PhotoFingerprint q = _print(0x5555555555555555, 9.0);
      final PhotoFingerprint q1 = _print(0x5555555555555554, 9.0);
      final PhotoFingerprint r = _print(0x2AAAAAAAAAAAAAAA, 4.0);
      final PhotoFingerprint r1 = _print(0x2AAAAAAAAAAAAAAB, 4.0);
      // v1 ~ v2 (p and q pair up), v2 ~ v3 (p and r pair up),
      // but v1 !~ v3 (only p pairs up) — a chain exists, yet v3
      // must stay out of v1's group: membership is decided
      // against the seed alone.
      final List<PhotoFingerprint> f1 = <PhotoFingerprint>[p, q];
      final List<PhotoFingerprint> f2 = <PhotoFingerprint>[p1, q1, r1];
      final List<PhotoFingerprint> f3 = <PhotoFingerprint>[p2, r];
      // Preconditions of the scenario, checked against the pair
      // predicate itself so the grouping assertion means something.
      expect(videosAreSimilar(f1, f2), isTrue);
      expect(videosAreSimilar(f2, f3), isTrue);
      expect(videosAreSimilar(f1, f3), isFalse);
      final List<List<MediaAsset>> groups = groupSimilarVideos(
        assets: <MediaAsset>[
          _video('v1', createDate: DateTime.utc(2026, 1, 1)),
          _video('v2', createDate: DateTime.utc(2026, 1, 2)),
          _video('v3', createDate: DateTime.utc(2026, 1, 3)),
        ],
        framesById: <String, List<PhotoFingerprint>>{
          'v1': f1,
          'v2': f2,
          'v3': f3,
        },
      );
      expect(groups.length, 1);
      expect(groups.single.map((MediaAsset a) => a.id).toList(), <String>[
        'v1',
        'v2',
      ]);
    });

    test('groups of 1 are dropped; date order picks the seed', () {
      final List<List<MediaAsset>> groups = groupSimilarVideos(
        assets: <MediaAsset>[
          _video('late', createDate: DateTime.utc(2026, 2, 1)),
          _video('early', createDate: DateTime.utc(2026, 1, 1)),
          _video('lonely', createDate: DateTime.utc(2026, 3, 1)),
        ],
        framesById: <String, List<PhotoFingerprint>>{
          'late': <PhotoFingerprint>[_a, _far],
          'early': <PhotoFingerprint>[_aTwin, _far],
          'lonely': <PhotoFingerprint>[
            _print(0x3333333333333333, 6.0),
            _print(0x3333333333333334, 6.0),
          ],
        },
      );
      expect(groups.length, 1);
      expect(groups.single.map((MediaAsset a) => a.id).toList(), <String>[
        'early',
        'late',
      ]);
    });

    test('over-cap and frameless videos never group', () {
      final List<List<MediaAsset>> groups = groupSimilarVideos(
        assets: <MediaAsset>[
          _video('big', sizeBytes: maxSimilarVideoBytes + 1),
          _video('bigTwin', sizeBytes: maxSimilarVideoBytes + 1),
          _video('noFrames'),
          _video('noFramesTwin'),
        ],
        framesById: <String, List<PhotoFingerprint>>{
          'big': <PhotoFingerprint>[_a, _far],
          'bigTwin': <PhotoFingerprint>[_a, _far],
          'noFrames': const <PhotoFingerprint>[],
          'noFramesTwin': const <PhotoFingerprint>[],
        },
      );
      expect(groups, isEmpty);
    });
  });
}
