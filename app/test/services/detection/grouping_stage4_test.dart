// Stage 4 grouping tests (requirements §7): Cleanup's seed rule
// (a photo joins only if it matches THE SEED), the exact-
// duplicate key (flip any field -> not a duplicate), the keeper
// rule fed by the new blur score, and the membership product.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/blur_detection.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(
  String id, {
  DateTime? date,
  int size = 1000,
  int width = 100,
  int height = 100,
  bool screenshot = false,
  MediaAssetType type = MediaAssetType.image,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: width,
    height: height,
    sizeBytes: size,
    createDate: date ?? DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
    isScreenshot: screenshot,
  );
}

PhotoAssessment _assessment(
  String id, {
  int dHash = 0,
  double? blurScore,
  double? luminance = 128,
}) {
  return PhotoAssessment(
    assetId: id,
    fingerprint: PhotoFingerprint(
      dHash: dHash,
      colorHistogram: List<double>.filled(24, 0),
    ),
    blur: blurScore == null ? null : BlurAssessment(edgeWidth: blurScore),
    meanLuminance: luminance,
  );
}

Map<String, PhotoAssessment> _map(List<PhotoAssessment> list) {
  return <String, PhotoAssessment>{
    for (final PhotoAssessment a in list) a.assetId: a,
  };
}

void main() {
  group('seed grouping (groupSimilarCleanup)', () {
    test('matching a member but not the seed does NOT join', () {
      // A=0; B is 3 bits away (joins A); C is 3 bits from B but
      // 6+ bits from A with colour pushed out of A's bands — C
      // must not join A's group through B.
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('c', date: DateTime(2026, 10, 22)),
        _asset('a', date: DateTime(2026, 10, 20)),
        _asset('b', date: DateTime(2026, 10, 21)),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('a', dHash: 0),
        _assessment('b', dHash: 0x7), // d=3 from A
        PhotoAssessment(
          assetId: 'c',
          fingerprint: PhotoFingerprint(
            dHash: 0x3F, // d=6 from A, d=3 from B
            colorHistogram: <double>[99, ...List<double>.filled(23, 0)],
          ),
        ),
      ]);
      final List<DuplicateGroup> groups = groupSimilarCleanup(
        assets: assets,
        assessments: assessments,
      );
      expect(groups.length, 1);
      expect(
        groups.single.assets.map((MediaAsset a) => a.id).toList(),
        <String>['a', 'b'],
      );
    });

    test('groups of 1 are dropped; the next ungrouped asset seeds', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20)),
        _asset('b', date: DateTime(2026, 10, 21)),
        _asset('c', date: DateTime(2026, 10, 22)),
        _asset('d', date: DateTime(2026, 10, 23)),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('a', dHash: 0),
        _assessment('b', dHash: 0x3FFFF), // d=18 from A: no match
        _assessment('c', dHash: 0x3FFFF),
        _assessment('d', dHash: 0x7FFFF), // d=19 from A, d=1 from B/C
      ]);
      final List<DuplicateGroup> groups = groupSimilarCleanup(
        assets: assets,
        assessments: assessments,
      );
      // A alone (dropped); B seeds, C matches B exactly and D
      // is d=1 from B — both join B's group, seed first, date
      // order kept.
      expect(groups.length, 1);
      expect(groups.single.assets.first.id, 'b');
      expect(
        groups.single.assets.map((MediaAsset a) => a.id).toList(),
        <String>['b', 'c', 'd'],
      );
    });

    test('photos and screenshots group separately, same hash or not', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('p1', date: DateTime(2026, 10, 20)),
        _asset('p2', date: DateTime(2026, 10, 21)),
        _asset('s1', date: DateTime(2026, 10, 20), screenshot: true),
        _asset('s2', date: DateTime(2026, 10, 21), screenshot: true),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('p1'),
        _assessment('p2'),
        _assessment('s1'),
        _assessment('s2'),
      ]);
      final List<DuplicateGroup> groups = groupSimilarCleanup(
        assets: assets,
        assessments: assessments,
      );
      expect(groups.length, 2);
      final Set<Set<String>> memberSets = <Set<String>>{
        for (final DuplicateGroup g in groups)
          g.assets.map((MediaAsset a) => a.id).toSet(),
      };
      expect(
        memberSets,
        containsAll(<Set<String>>[
          <String>{'p1', 'p2'},
          <String>{'s1', 's2'},
        ]),
      );
    });

    test('assets without a valid fingerprint never group', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20)),
        _asset('b', date: DateTime(2026, 10, 21)),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('a'),
        const PhotoAssessment(assetId: 'b'),
      ]);
      expect(
        groupSimilarCleanup(assets: assets, assessments: assessments),
        isEmpty,
      );
    });
  });

  group('exact duplicates (groupExactDuplicates)', () {
    List<MediaAsset> pair() => <MediaAsset>[
      _asset('a', date: DateTime(2026, 10, 20)),
      _asset('b', date: DateTime(2026, 10, 21)),
    ];

    Map<String, AssetInfo> infos(List<MediaAsset> assets) {
      return <String, AssetInfo>{
        for (final MediaAsset a in assets) a.id: AssetInfo.fromAsset(a),
      };
    }

    test('identical key fields group; reference main is the keeper', () {
      final List<MediaAsset> assets = pair();
      final ({List<DuplicateGroup> groups, List<DuplicateReference> references})
      result = groupExactDuplicates(
        assets: assets,
        assessments: _map(<PhotoAssessment>[
          _assessment('a'),
          _assessment('b'),
        ]),
        assetInfos: infos(assets),
      );
      expect(result.groups.length, 1);
      expect(result.references.length, 1);
      expect(result.references.single.mainId, result.groups.single.keeperId);
      expect(result.references.single.memberIds.length, 2);
    });

    test('flipping any ONE key field breaks the duplicate', () {
      final List<MediaAsset> base = pair();
      final Map<String, PhotoAssessment> baseAssessments = _map(
        <PhotoAssessment>[_assessment('a'), _assessment('b')],
      );

      void expectNoGroup(
        List<MediaAsset> assets,
        Map<String, PhotoAssessment> assessments,
        Map<String, AssetInfo> assetInfos,
      ) {
        final ({
          List<DuplicateGroup> groups,
          List<DuplicateReference> references,
        })
        result = groupExactDuplicates(
          assets: assets,
          assessments: assessments,
          assetInfos: assetInfos,
        );
        expect(result.groups, isEmpty);
        expect(result.references, isEmpty);
      }

      // type (screenshot class)
      expectNoGroup(
        <MediaAsset>[base[0], _asset('b', screenshot: true)],
        baseAssessments,
        infos(<MediaAsset>[base[0], _asset('b', screenshot: true)]),
      );
      // width
      expectNoGroup(
        <MediaAsset>[base[0], _asset('b', width: 101)],
        baseAssessments,
        infos(<MediaAsset>[base[0], _asset('b', width: 101)]),
      );
      // height
      expectNoGroup(
        <MediaAsset>[base[0], _asset('b', height: 101)],
        baseAssessments,
        infos(<MediaAsset>[base[0], _asset('b', height: 101)]),
      );
      // shape fingerprint
      expectNoGroup(
        base,
        _map(<PhotoAssessment>[_assessment('a'), _assessment('b', dHash: 1)]),
        infos(base),
      );
      // file size
      expectNoGroup(
        <MediaAsset>[base[0], _asset('b', size: 1001)],
        baseAssessments,
        infos(<MediaAsset>[base[0], _asset('b', size: 1001)]),
      );
      // edited flag (facts-level: only the info differs)
      final Map<String, AssetInfo> editedInfos = infos(base);
      editedInfos['b'] = const AssetInfo(
        assetId: 'b',
        type: MediaAssetType.image,
        width: 100,
        height: 100,
        sizeBytes: 1000,
        modifiedDateMs: null,
        isEdited: true,
        isScreenshot: false,
      );
      expectNoGroup(base, baseAssessments, editedInfos);
    });

    test('videos never enter duplicates', () {
      final List<MediaAsset> videos = <MediaAsset>[
        _asset('a', type: MediaAssetType.video),
        _asset('b', type: MediaAssetType.video),
      ];
      final ({List<DuplicateGroup> groups, List<DuplicateReference> references})
      result = groupExactDuplicates(
        assets: videos,
        assessments: _map(<PhotoAssessment>[
          _assessment('a'),
          _assessment('b'),
        ]),
        assetInfos: infos(videos),
      );
      expect(result.groups, isEmpty);
    });
  });

  group('keeper suggestion with the new blur score', () {
    test('sharpest (LOWEST score) wins, even when smaller', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('blurry-big', size: 999999),
        _asset('sharp-small', size: 100),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('blurry-big', blurScore: 4),
        _assessment('sharp-small', blurScore: 0.5),
      ]);
      expect(suggestKeeper(assets, assessments), 'sharp-small');
    });

    test('unscored never beats scored; ties fall to size, then order', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('unscored', size: 999999),
        _asset('scored', size: 10),
      ];
      expect(
        suggestKeeper(
          assets,
          _map(<PhotoAssessment>[
            _assessment('unscored'),
            _assessment('scored', blurScore: 9),
          ]),
        ),
        'scored',
      );
      final List<MediaAsset> tied = <MediaAsset>[
        _asset('first', size: 10),
        _asset('bigger', size: 20),
        _asset('also-bigger', size: 20),
      ];
      expect(
        suggestKeeper(
          tied,
          _map(<PhotoAssessment>[
            _assessment('first', blurScore: 1),
            _assessment('bigger', blurScore: 1),
            _assessment('also-bigger', blurScore: 1),
          ]),
        ),
        'bigger',
      );
      expect(
        suggestKeeper(
          <MediaAsset>[_asset('x', size: 5), _asset('y', size: 5)],
          _map(<PhotoAssessment>[
            _assessment('x', blurScore: 1),
            _assessment('y', blurScore: 1),
          ]),
        ),
        'x',
      );
    });

    test('copyWithKeeper changes keeper and non-keepers', () {
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

  group('buildScanMemberships', () {
    test('collects infos, groups, reference, blurry and dark sets', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20)),
        _asset('b', date: DateTime(2026, 10, 21)),
        _asset('dark', date: DateTime(2026, 10, 22)),
        _asset('vid', type: MediaAssetType.video),
      ];
      final Map<String, PhotoAssessment> assessments = _map(<PhotoAssessment>[
        _assessment('a'),
        // 5.0: clearly over the blur line (4.2 since ADR-023;
        // this fixture was 3.5 under the old 2.2 line).
        _assessment('b', blurScore: 5.0),
        _assessment('dark', dHash: 0xFFFFFFFF, luminance: 10),
      ]);
      final ScanMemberships m = buildScanMemberships(
        assets: assets,
        assessments: assessments,
      );
      expect(m.algorithmVersion, scanMembershipAlgorithmVersion);
      expect(m.assetInfos.keys.toSet(), <String>{'a', 'b', 'dark', 'vid'});
      // a+b: identical fingerprints AND identical duplicate key.
      expect(m.groupsOfKind(ScanGroupKind.similar).length, 1);
      expect(m.groupsOfKind(ScanGroupKind.duplicate).length, 1);
      expect(m.duplicateReferences.single.memberIds.toSet(), <String>{
        'a',
        'b',
      });
      expect(m.memberSetOf(ScanGroupKind.blurry), <String>{'b'});
      expect(m.memberSetOf(ScanGroupKind.dark), <String>{'dark'});
      // The similar group records its seed (earliest by date).
      expect(m.groupsOfKind(ScanGroupKind.similar).single.seedId, 'a');
    });

    test('groupsFromMemberships drops unresolvable members and '
        'groups that fall below 2', () {
      const ScanMemberships m = ScanMemberships(
        algorithmVersion: 1,
        assetInfos: <String, AssetInfo>{},
        groups: <ScanGroup>[
          ScanGroup(
            kind: ScanGroupKind.duplicate,
            memberIds: <String>['a', 'gone', 'b'],
            keeperId: 'gone',
          ),
          ScanGroup(
            kind: ScanGroupKind.duplicate,
            memberIds: <String>['gone1', 'gone2'],
            keeperId: 'gone1',
          ),
        ],
        duplicateReferences: <DuplicateReference>[],
      );
      final Map<String, MediaAsset> byId = <String, MediaAsset>{
        'a': _asset('a'),
        'b': _asset('b'),
      };
      final List<DuplicateGroup> groups = groupsFromMemberships(
        byId,
        m,
        ScanGroupKind.duplicate,
      );
      expect(groups.length, 1);
      expect(
        groups.single.assets.map((MediaAsset a) => a.id).toList(),
        <String>['a', 'b'],
      );
      // Keeper unresolvable: falls back to the first member.
      expect(groups.single.keeperId, 'a');
    });
  });
}
