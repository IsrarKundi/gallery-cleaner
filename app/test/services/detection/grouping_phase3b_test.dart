// Phase 3B grouping performance tests (requirements §7, 50,000+
// photos): hash-bucket equivalence at threshold 0, the capped
// greedy scan at threshold > 0, and host benchmarks for 5k/10k
// synthetic libraries. Timings are HOST numbers (this VM, no
// device): they prove the algorithm scales, not that a phone does.
// Real 50k on-device verification remains the owner's job.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

PhotoAnalysis _analysis(String id, int hash) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: 100,
    meanLuminance: 100,
  );
}

/// The pre-Phase-3B greedy scan, re-implemented here (not imported)
/// so the threshold-0 equivalence test compares against an
/// independent implementation, not against itself.
List<DuplicateGroup> _oldGreedy(
  List<MediaAsset> assets,
  Map<String, PhotoAnalysis> analyses,
  int threshold,
) {
  final List<List<MediaAsset>> clusters = <List<MediaAsset>>[];
  final List<String> reps = <String>[];
  for (final MediaAsset asset in assets) {
    final PhotoAnalysis? analysis = analyses[asset.id];
    if (analysis == null) {
      continue;
    }
    int? match;
    for (int i = 0; i < clusters.length; i++) {
      if (hammingDistance(analysis.hash, analyses[reps[i]]!.hash) <=
          threshold) {
        match = i;
        break;
      }
    }
    if (match == null) {
      reps.add(asset.id);
      clusters.add(<MediaAsset>[asset]);
    } else {
      clusters[match].add(asset);
    }
  }
  final List<DuplicateGroup> groups = <DuplicateGroup>[];
  for (final List<MediaAsset> members in clusters) {
    if (members.length < 2) {
      continue;
    }
    groups.add(
      DuplicateGroup(
        assets: members,
        keeperId: suggestKeeper(members, analyses),
      ),
    );
  }
  return groups;
}

String _groupKey(DuplicateGroup group) {
  final List<String> ids = group.assets.map((MediaAsset a) => a.id).toList()
    ..sort();
  return '${ids.join(',')}:${group.keeperId}';
}

void main() {
  test('threshold 0 bucket grouping matches the old greedy scan', () {
    // 200 assets: 40 hashes repeated 5x, plus distinct singles.
    final List<MediaAsset> assets = <MediaAsset>[];
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
    for (int h = 0; h < 40; h++) {
      for (int k = 0; k < 5; k++) {
        final String id = 'h${h}_$k';
        assets.add(_asset(id));
        analyses[id] = _analysis(id, h * 7919);
      }
    }
    for (int i = 0; i < 30; i++) {
      final String id = 'single_$i';
      assets.add(_asset(id));
      analyses[id] = _analysis(id, 1000000 + i * 131);
    }
    final List<String> expected = _oldGreedy(
      assets,
      analyses,
      0,
    ).map(_groupKey).toList()..sort();
    final List<String> actual = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: 0,
    ).map(_groupKey).toList()..sort();
    expect(actual, expected);
    expect(actual.length, 40);
  });

  test('capped similar scan splits (never wrongly merges) past the cap', () {
    // 600 pairs, one shared hash each. The hashes are seeded
    // random 64-bit values: two random hashes are ~32 bits
    // apart, so (with the premise assertions below proving it
    // for this seed) no two pairs are within threshold 5 of
    // each other. NOTE: spaced multiples (e.g. pair * 104729)
    // do NOT work here — they merge with each other.
    final math.Random random = math.Random(42);
    int randomHash() {
      return (random.nextInt(1 << 32) << 32) | random.nextInt(1 << 32);
    }

    final List<int> pairHashes = <int>[
      for (int p = 0; p < 600; p++) randomHash(),
    ];
    final List<MediaAsset> assets = <MediaAsset>[];
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
    for (int p = 0; p < 600; p++) {
      for (int k = 0; k < 2; k++) {
        final String id = 'p${p}_$k';
        assets.add(_asset(id));
        analyses[id] = _analysis(id, pairHashes[p]);
      }
    }
    // Late asset: within distance 1 of pair 599's hash (flip 1
    // bit). Premise assertions (fail loudly at setup if the
    // seed ever stops satisfying them — never a silent pass).
    final int lateHash = pairHashes[599] ^ 1;
    assets.add(_asset('late'));
    analyses['late'] = _analysis('late', lateHash);
    expect(hammingDistance(lateHash, pairHashes[599]), 1);
    for (int p = 0; p < 599; p++) {
      expect(hammingDistance(pairHashes[p], pairHashes[599]), greaterThan(5));
      expect(hammingDistance(lateHash, pairHashes[p]), greaterThan(5));
    }
    final List<DuplicateGroup> groups = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: 5,
    );
    // Cap behaviour, exactly as the implementation specifies:
    // pairs 0..511 group (512 groups). Pairs 512..599 vanish as
    // groups — not because they merged, but because the second
    // member also cannot see its own representative beyond the
    // cap, so both members stay singletons and are dropped. The
    // late asset likewise stays a singleton. Nothing merges
    // wrongly and nothing is deleted: those photos simply stay
    // ungrouped in the library.
    expect(groups.length, 512);
    expect(
      groups.any((DuplicateGroup g) => g.assets.any((a) => a.id == 'late')),
      isFalse,
    );
    for (int p = 512; p < 600; p++) {
      expect(
        groups.any(
          (DuplicateGroup g) =>
              g.assets.any((MediaAsset a) => a.id == 'p${p}_0'),
        ),
        isFalse,
      );
    }
    expect(groups.every((DuplicateGroup g) => g.assets.length == 2), isTrue);
    expect(maxRepresentativeComparisons, 512);
  });

  test('benchmark: 5k and 10k synthetic libraries group in bounds', () {
    List<MediaAsset> assets(int n, {bool duplicates = false}) {
      final List<MediaAsset> list = <MediaAsset>[];
      for (int i = 0; i < n; i++) {
        list.add(_asset('a$i'));
      }
      return list;
    }

    Map<String, PhotoAnalysis> analysesFor(int n, {bool duplicates = false}) {
      final Map<String, PhotoAnalysis> map = <String, PhotoAnalysis>{};
      for (int i = 0; i < n; i++) {
        // Distinct hashes spaced far apart (worst case for the
        // greedy scan: every asset scans many representatives),
        // or, for the bucket path, hashes repeated 5x.
        final int hash = duplicates ? (i ~/ 5) * 7919 : i * 104729;
        map['a$i'] = _analysis('a$i', hash);
      }
      return map;
    }

    final Stopwatch watch = Stopwatch();
    watch.start();
    final List<DuplicateGroup> fiveK = groupAssets(
      assets: assets(5000),
      analyses: analysesFor(5000),
      threshold: 5,
    );
    watch.stop();
    // ignore: avoid_print
    print(
      'grouping 5k distinct (threshold 5, capped): '
      '${watch.elapsedMilliseconds}ms, ${fiveK.length} groups',
    );
    // No exact group count is asserted here: spaced multiples of
    // 104729 can still fall within Hamming 5 of each other, so
    // some merge. The bound that matters is time, not the count.
    expect(watch.elapsedMilliseconds, lessThan(5000));

    watch
      ..reset()
      ..start();
    final List<DuplicateGroup> tenK = groupAssets(
      assets: assets(10000),
      analyses: analysesFor(10000),
      threshold: 5,
    );
    watch.stop();
    // ignore: avoid_print
    print(
      'grouping 10k distinct (threshold 5, capped): '
      '${watch.elapsedMilliseconds}ms, ${tenK.length} groups',
    );
    expect(watch.elapsedMilliseconds, lessThan(10000));

    watch
      ..reset()
      ..start();
    final List<DuplicateGroup> tenKBucket = groupAssets(
      assets: assets(10000, duplicates: true),
      analyses: analysesFor(10000, duplicates: true),
      threshold: 0,
    );
    watch.stop();
    // ignore: avoid_print
    print(
      'grouping 10k with duplicates (threshold 0, bucket): '
      '${watch.elapsedMilliseconds}ms, ${tenKBucket.length} groups',
    );
    expect(tenKBucket.length, 2000);
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });
}
