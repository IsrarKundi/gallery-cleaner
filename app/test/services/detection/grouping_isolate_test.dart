// Phase 5.2 grouping-isolate tests (requirements §7):
// off-isolate grouping must be byte-identical to the direct
// algorithm (determinism guard), and threshold 0 must implement
// the exact-duplicate rule (hash AND dimensions) after the 5.2
// reconciliation — same hash with different dimensions groups at
// threshold > 0 as similar, but never at 0 as exact.
//
// Plain unit tests (real async), so Isolate.run completes here;
// widget tests driving the same runners need the real-async
// wait loop documented in decks_view_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(
  String id, {
  int width = 10,
  int height = 10,
  DateTime? createDate,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: width,
    height: height,
    sizeBytes: 1000,
    createDate: createDate ?? DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

PhotoAnalysis _analysis(String id, int hash, double blur) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: blur,
    meanLuminance: 128,
  );
}

/// Canonical form for exact comparison: member ids in order plus
/// keeper id, per group, in group order, as plain strings —
///
/// NOTE: not Dart records: record equality compares a List field
/// by identity, so two separately built but identical group lists
/// would compare unequal. Strings compare by value.
List<String> _canonical(List<DuplicateGroup> groups) {
  return <String>[
    for (final DuplicateGroup group in groups)
      '${group.assets.map((MediaAsset a) => a.id).join(',')}|'
          '${group.keeperId}',
  ];
}

/// 5,000-asset fixture: 400 exact clusters of 10, 200 similar
/// pairs (1-bit hash distance), 600 singletons. The determinism
/// tests compare isolate output against the direct algorithm on
/// this exact fixture — they do not assert absolute counts, so
/// they hold whatever the greedy scan does with it.
({List<MediaAsset> assets, Map<String, PhotoAnalysis> analyses})
_build5kFixture() {
  final List<MediaAsset> assets = <MediaAsset>[];
  final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
  void add(String id, int hash, double blur) {
    assets.add(_asset(id));
    analyses[id] = _analysis(id, hash, blur);
  }

  for (int cluster = 0; cluster < 400; cluster++) {
    final int hash = (cluster + 1) * 7919;
    for (int member = 0; member < 10; member++) {
      // Varying blur so the keeper pick is exercised too.
      add('c${cluster}_$member', hash, 100.0 + member * 10);
    }
  }
  for (int pair = 0; pair < 200; pair++) {
    final int base = 500000 + pair * 2;
    add('p${pair}_a', base, 500);
    add('p${pair}_b', base + 1, 100);
  }
  for (int single = 0; single < 600; single++) {
    add('s$single', 900000 + single * 7919, 300);
  }
  return (assets: assets, analyses: analyses);
}

void main() {
  test('isolate grouping equals direct grouping at threshold 5 (5k)', () async {
    final fixture = _build5kFixture();
    final List<DuplicateGroup> direct = groupAssets(
      assets: fixture.assets,
      analyses: fixture.analyses,
      threshold: 5,
    );
    final List<DuplicateGroup> viaIsolate = await groupAssetsOnIsolate(
      fixture.assets,
      fixture.analyses,
      5,
    );
    expect(_canonical(viaIsolate), _canonical(direct));
    // Sanity: the fixture really does group (not a vacuous pass):
    // every cluster member lands in some group.
    final int grouped = direct.fold<int>(
      0,
      (int sum, DuplicateGroup group) => sum + group.assets.length,
    );
    expect(grouped, greaterThan(4000));
  });

  test('isolate grouping equals direct grouping at threshold 0 (5k)', () async {
    final fixture = _build5kFixture();
    final List<DuplicateGroup> direct = groupAssets(
      assets: fixture.assets,
      analyses: fixture.analyses,
      threshold: 0,
    );
    final List<DuplicateGroup> viaIsolate = await groupAssetsOnIsolate(
      fixture.assets,
      fixture.analyses,
      0,
    );
    expect(_canonical(viaIsolate), _canonical(direct));
    expect(direct.length, 400);
  });

  test('threshold 0 groups only true exact duplicates', () {
    final List<MediaAsset> assets = <MediaAsset>[
      _asset('a', width: 10, height: 10),
      _asset('b', width: 20, height: 20),
      _asset('c', width: 30, height: 30),
      _asset('d', width: 30, height: 30),
    ];
    // Same hash for all four; dimensions split them at 0.
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
      'a': const PhotoAnalysis(
        assetId: 'a',
        hash: 42,
        width: 10,
        height: 10,
        blurScore: 100,
        meanLuminance: 128,
      ),
      'b': const PhotoAnalysis(
        assetId: 'b',
        hash: 42,
        width: 20,
        height: 20,
        blurScore: 100,
        meanLuminance: 128,
      ),
      'c': const PhotoAnalysis(
        assetId: 'c',
        hash: 42,
        width: 30,
        height: 30,
        blurScore: 100,
        meanLuminance: 128,
      ),
      'd': const PhotoAnalysis(
        assetId: 'd',
        hash: 42,
        width: 30,
        height: 30,
        blurScore: 200,
        meanLuminance: 128,
      ),
    };
    final List<DuplicateGroup> exact = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: 0,
    );
    // Only c+d share hash AND dimensions. a and b are NOT
    // offered for deletion together at slider 0 — that is the
    // trust-flow property the 5.2 reconciliation protects.
    expect(exact.length, 1);
    expect(exact.first.assets.map((MediaAsset a) => a.id).toList(), <String>[
      'c',
      'd',
    ]);
    expect(exact.first.keeperId, 'd');
    // At threshold > 0 the same pairs are similar (distance 0),
    // so a and b DO group there — the change is slider-0 only.
    final List<DuplicateGroup> similar = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: 5,
    );
    expect(
      similar.any(
        (DuplicateGroup g) =>
            g.assets.any((MediaAsset a) => a.id == 'a') &&
            g.assets.any((MediaAsset a) => a.id == 'b'),
      ),
      isTrue,
    );
  });

  test('list decks isolate equals direct (groups + bursts)', () async {
    final DateTime base = DateTime(2026, 10, 20, 12);
    final List<MediaAsset> assets = <MediaAsset>[
      _asset('burst1', createDate: base),
      _asset('burst2', createDate: base.add(const Duration(seconds: 2))),
      _asset('burst3', createDate: base.add(const Duration(seconds: 4))),
      _asset('dup_a', createDate: base.add(const Duration(days: 1))),
      _asset('dup_b', createDate: base.add(const Duration(days: 2))),
      _asset('solo', createDate: base.add(const Duration(days: 3))),
    ];
    // Hashes pairwise more than 5 bits apart (except the dup
    // pair), so the only group is [dup_a, dup_b] and the only
    // burst run is the three burst assets.
    final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
      'burst1': _analysis('burst1', 0, 100),
      'burst2': _analysis('burst2', 0xFFFF, 100),
      'burst3': _analysis('burst3', 0xFFFF0000, 100),
      'dup_a': _analysis('dup_a', 0x12345678, 900),
      'dup_b': _analysis('dup_b', 0x12345678, 100),
      'solo': _analysis('solo', 0x0F0F0F0F, 100),
    };
    final List<DuplicateGroup> directGroups = groupAssets(
      assets: assets,
      analyses: analyses,
      threshold: 5,
    );
    final Set<String> directBursts = burstAssetIds(assets);
    final ({List<DuplicateGroup> groups, Set<String> burstIds}) viaIsolate =
        await computeListDecksOnIsolate(assets, analyses, 5);
    expect(_canonical(viaIsolate.groups), _canonical(directGroups));
    expect(viaIsolate.burstIds, directBursts);
    expect(directBursts, <String>{'burst1', 'burst2', 'burst3'});
    expect(directGroups.length, 1);
  });
}
