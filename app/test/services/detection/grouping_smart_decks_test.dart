// Grouping + smart-deck predicate tests (requirements §7, Phase 2A).

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(
  String id, {
  int size = 1000,
  DateTime? date,
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date ?? DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
  );
}

PhotoAnalysis _analysis(
  String id, {
  int hash = 0,
  double blur = 500,
  double luminance = 128,
}) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: blur,
    meanLuminance: luminance,
  );
}

void main() {
  group('groupAssets', () {
    test('threshold 0 groups only identical hashes', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
        'a': _analysis('a', hash: 0),
        'b': _analysis('b', hash: 0),
        'c': _analysis('c', hash: 1),
      };
      final List<DuplicateGroup> groups = groupAssets(
        assets: <MediaAsset>[_asset('a'), _asset('b'), _asset('c')],
        analyses: analyses,
        threshold: 0,
      );
      expect(groups.length, 1);
      expect(groups.first.assets.map((MediaAsset a) => a.id).toList(), <String>[
        'a',
        'b',
      ]);
    });

    test('higher threshold pulls in farther hashes', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
        'a': _analysis('a', hash: 0),
        'b': _analysis('b', hash: 63),
      };
      expect(
        groupAssets(
          assets: <MediaAsset>[_asset('a'), _asset('b')],
          analyses: analyses,
          threshold: 5,
        ),
        isEmpty,
      );
      expect(
        groupAssets(
          assets: <MediaAsset>[_asset('a'), _asset('b')],
          analyses: analyses,
          threshold: 6,
        ).length,
        1,
      );
    });

    test('singletons are dropped and unanalysed assets are skipped', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
        'a': _analysis('a', hash: 0),
      };
      expect(
        groupAssets(
          assets: <MediaAsset>[_asset('a'), _asset('ghost')],
          analyses: analyses,
          threshold: 5,
        ),
        isEmpty,
      );
    });

    test('keeper suggestion prefers sharpest, then largest', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
        'sharp-small': _analysis('sharp-small', blur: 900, luminance: 128),
        'blurry-big': _analysis('blurry-big', blur: 10, luminance: 128),
      };
      final List<DuplicateGroup> groups = groupAssets(
        assets: <MediaAsset>[
          _asset('sharp-small', size: 100),
          _asset('blurry-big', size: 999999),
        ],
        analyses: analyses,
        threshold: 5,
      );
      expect(groups.first.keeperId, 'sharp-small');
      expect(
        groups.first.nonKeepers.map((MediaAsset a) => a.id).toList(),
        <String>['blurry-big'],
      );
    });

    test('keeper suggestion falls back to largest when unscored', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};
      // No analyses at all: suggestKeeper still ranks by size.
      expect(
        suggestKeeper(<MediaAsset>[
          _asset('small', size: 10),
          _asset('big', size: 20),
        ], analyses),
        'big',
      );
    });

    test('copyWithKeeper changes the keeper and the non-keeper set', () {
      final DuplicateGroup group = DuplicateGroup(
        assets: <MediaAsset>[_asset('a'), _asset('b')],
        keeperId: 'a',
      );
      final DuplicateGroup changed = group.copyWithKeeper('b');
      expect(changed.keeperId, 'b');
      expect(changed.nonKeepers.map((MediaAsset a) => a.id).toList(), <String>[
        'a',
      ]);
    });
  });

  group('decksForAsset', () {
    final DateTime now = DateTime(2026, 10, 25);

    test('album-name decks match case-insensitively', () {
      final Set<SmartDeckId> decks = decksForAsset(
        _asset('a', album: 'SCREENSHOTS'),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(decks, contains(SmartDeckId.screenshots));
      expect(decks, isNot(contains(SmartDeckId.whatsapp)));
    });

    test('missing or empty album names never match name decks', () {
      final Set<SmartDeckId> decks = decksForAsset(
        _asset('a', album: ''),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(decks, isNot(contains(SmartDeckId.screenshots)));
      expect(decks, isNot(contains(SmartDeckId.whatsapp)));
      expect(decks, isNot(contains(SmartDeckId.downloads)));
    });

    test('whatsapp and downloads match by folder name', () {
      expect(
        decksForAsset(
          _asset('a', album: 'WhatsApp Images'),
          <String, PhotoAnalysis>{},
          now,
        ),
        contains(SmartDeckId.whatsapp),
      );
      expect(
        decksForAsset(
          _asset('a', album: 'Download'),
          <String, PhotoAnalysis>{},
          now,
        ),
        contains(SmartDeckId.downloads),
      );
    });

    test('videos, large and old predicates', () {
      final Set<SmartDeckId> video = decksForAsset(
        _asset('v', type: MediaAssetType.video),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(video, contains(SmartDeckId.videos));
      final Set<SmartDeckId> large = decksForAsset(
        _asset('l', size: 10 * 1024 * 1024),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(large, contains(SmartDeckId.large));
      final Set<SmartDeckId> justUnder = decksForAsset(
        _asset('s', size: 10 * 1024 * 1024 - 1),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(justUnder, isNot(contains(SmartDeckId.large)));
      final Set<SmartDeckId> old = decksForAsset(
        _asset('o', date: DateTime(2026, 7, 1)),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(old, contains(SmartDeckId.old));
      final Set<SmartDeckId> recent = decksForAsset(
        _asset('r', date: DateTime(2026, 10, 20)),
        <String, PhotoAnalysis>{},
        now,
      );
      expect(recent, isNot(contains(SmartDeckId.old)));
    });

    test('blurry and dark decks need an image analysis', () {
      final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{
        'img': _analysis('img', blur: 0, luminance: 10),
        'vid': _analysis('vid', blur: 0, luminance: 10),
      };
      expect(
        decksForAsset(_asset('img'), analyses, now),
        containsAll(<SmartDeckId>[SmartDeckId.blurry, SmartDeckId.dark]),
      );
      // A video with the same scores is never blurry/dark-flagged.
      expect(
        decksForAsset(_asset('vid', type: MediaAssetType.video), analyses, now),
        isNot(contains(SmartDeckId.blurry)),
      );
      // No analysis, no detection decks.
      expect(
        decksForAsset(_asset('none'), analyses, now),
        isNot(contains(SmartDeckId.blurry)),
      );
    });
  });

  group('burstAssetIds', () {
    test('3+ photos within 5s gaps form a burst', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 3)),
        _asset('c', date: DateTime(2026, 10, 20, 12, 0, 5)),
        _asset('d', date: DateTime(2026, 10, 20, 13, 0, 0)),
      ];
      expect(burstAssetIds(assets), <String>{'a', 'b', 'c'});
    });

    test('a 6s gap splits the run and pairs are dropped', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 6)),
        _asset('c', date: DateTime(2026, 10, 20, 12, 0, 7)),
      ];
      expect(burstAssetIds(assets), isEmpty);
    });

    test('videos never join a burst', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset(
          'v',
          date: DateTime(2026, 10, 20, 12, 0, 1),
          type: MediaAssetType.video,
        ),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 2)),
      ];
      // Only two photos remain in the run: below the burst minimum.
      expect(burstAssetIds(assets), isEmpty);
    });
  });
}
