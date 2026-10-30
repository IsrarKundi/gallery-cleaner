// Stage 4 membership value tests: the serialised form must
// round-trip AND must contain no hash/score field anywhere
// (the persisted hash is removed, ADR-019); the freshness rule
// must accept only an exact fact match at the current version.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';

AssetInfo _info(
  String id, {
  MediaAssetType type = MediaAssetType.image,
  int width = 100,
  int height = 100,
  int? size = 1000,
  int? modified = 1700000000000,
  bool edited = false,
  bool screenshot = false,
}) {
  return AssetInfo(
    assetId: id,
    type: type,
    width: width,
    height: height,
    sizeBytes: size,
    modifiedDateMs: modified,
    isEdited: edited,
    isScreenshot: screenshot,
  );
}

ScanMemberships _snapshot() {
  return ScanMemberships(
    algorithmVersion: scanMembershipAlgorithmVersion,
    assetInfos: <String, AssetInfo>{'a': _info('a'), 'b': _info('b')},
    groups: const <ScanGroup>[
      ScanGroup(
        kind: ScanGroupKind.similar,
        memberIds: <String>['a', 'b'],
        seedId: 'a',
        keeperId: 'a',
      ),
      ScanGroup(kind: ScanGroupKind.blurry, memberIds: <String>['b']),
    ],
    duplicateReferences: const <DuplicateReference>[
      DuplicateReference(mainId: 'a', duplicateIds: <String>['b']),
    ],
  );
}

void main() {
  group('serialised form', () {
    test('round-trips exactly', () {
      final ScanMemberships original = _snapshot();
      final ScanMemberships back = ScanMemberships.fromJson(original.toJson());
      expect(back.algorithmVersion, original.algorithmVersion);
      expect(back.assetInfos.length, 2);
      expect(
        back.assetInfos['a']!.sameFacts(original.assetInfos['a']!),
        isTrue,
      );
      expect(back.groups.length, 2);
      expect(back.groups.first.seedId, 'a');
      expect(back.groups.first.memberIds, <String>['a', 'b']);
      expect(back.duplicateReferences.single.mainId, 'a');
      expect(back.duplicateReferences.single.duplicateIds, <String>['b']);
    });

    test('contains NO hash or score keys at any depth', () {
      final Map<String, dynamic> json = _snapshot().toJson();
      final Set<String> keys = <String>{};
      void collect(Object? node) {
        if (node is Map) {
          for (final MapEntry<dynamic, dynamic> e in node.entries) {
            keys.add('${e.key}'.toLowerCase());
            collect(e.value);
          }
        } else if (node is List) {
          for (final Object? item in node) {
            collect(item);
          }
        }
      }

      collect(json);
      for (final String banned in <String>[
        'hash',
        'dhash',
        'blur',
        'blurScore',
        'score',
        'luminance',
        'meanLuminance',
      ]) {
        expect(keys.contains(banned), isFalse, reason: banned);
      }
    });
  });

  group('freshness (isFreshFor)', () {
    Map<String, AssetInfo> facts() => <String, AssetInfo>{
      'a': _info('a'),
      'b': _info('b'),
    };

    test('exact facts at the current version are fresh', () {
      expect(_snapshot().isFreshFor(facts()), isTrue);
    });

    test('version 0 (legacy-converted facts) is never fresh', () {
      final ScanMemberships legacy = ScanMemberships(
        algorithmVersion: 0,
        assetInfos: facts(),
        groups: const <ScanGroup>[],
        duplicateReferences: const <DuplicateReference>[],
      );
      expect(legacy.isFreshFor(facts()), isFalse);
      expect(ScanMemberships.empty.isFreshFor(facts()), isFalse);
    });

    test('any single fact difference is stale', () {
      final ScanMemberships snapshot = _snapshot();
      final Map<String, AssetInfo> changedSize = facts()
        ..['a'] = _info('a', size: 1001);
      expect(snapshot.isFreshFor(changedSize), isFalse);
      final Map<String, AssetInfo> changedModified = facts()
        ..['a'] = _info('a', modified: 1700000000001);
      expect(snapshot.isFreshFor(changedModified), isFalse);
      final Map<String, AssetInfo> changedDims = facts()
        ..['a'] = _info('a', width: 101);
      expect(snapshot.isFreshFor(changedDims), isFalse);
      final Map<String, AssetInfo> changedShot = facts()
        ..['a'] = _info('a', screenshot: true);
      expect(snapshot.isFreshFor(changedShot), isFalse);
      final Map<String, AssetInfo> changedEdited = facts()
        ..['a'] = _info('a', edited: true);
      expect(snapshot.isFreshFor(changedEdited), isFalse);
    });

    test('an added or removed asset is stale', () {
      final ScanMemberships snapshot = _snapshot();
      final Map<String, AssetInfo> added = facts()..['c'] = _info('c');
      expect(snapshot.isFreshFor(added), isFalse);
      final Map<String, AssetInfo> removed = facts()..remove('b');
      expect(snapshot.isFreshFor(removed), isFalse);
    });
  });

  group('AssetInfo.fromAsset', () {
    test('carries the enumeration facts; edited is false (no '
        'edited signal exists in the enumeration)', () {
      final MediaAsset asset = MediaAsset(
        id: 'x',
        type: MediaAssetType.image,
        width: 10,
        height: 20,
        sizeBytes: 42,
        createDate: DateTime(2026, 1, 1),
        title: 'x.jpg',
        albumName: 'Camera',
        modifiedDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        isScreenshot: true,
      );
      final AssetInfo info = AssetInfo.fromAsset(asset);
      expect(info.type, MediaAssetType.image);
      expect(info.width, 10);
      expect(info.sizeBytes, 42);
      expect(info.modifiedDateMs, 1700000000000);
      expect(info.isEdited, isFalse);
      expect(info.isScreenshot, isTrue);
    });
  });
}
