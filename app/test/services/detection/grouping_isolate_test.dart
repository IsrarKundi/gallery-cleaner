// Stage 4 off-isolate determinism: the membership builder and
// the burst runner must produce exactly the direct computation's
// output when they run on a worker isolate (the values cross
// the isolate boundary, so equality is on the canonical string
// form, not object identity).
//
// Plain unit tests (real async), so Isolate.run completes here.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/blur_detection.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(String id, {DateTime? date}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: date ?? DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

PhotoAssessment _assessment(String id, int dHash) {
  return PhotoAssessment(
    assetId: id,
    fingerprint: PhotoFingerprint(
      dHash: dHash,
      colorHistogram: List<double>.filled(24, 0),
    ),
    blur: const BlurAssessment(edgeWidth: 1),
    meanLuminance: 128,
  );
}

String _canonical(ScanMemberships m) {
  final List<String> parts = <String>['v=${m.algorithmVersion}'];
  final List<String> ids = m.assetInfos.keys.toList()..sort();
  parts.add('infos=${ids.join(',')}');
  for (final ScanGroup g in m.groups) {
    parts.add(
      '${g.kind.name}:${g.memberIds.join(',')}:${g.seedId}:${g.keeperId}',
    );
  }
  for (final DuplicateReference r in m.duplicateReferences) {
    parts.add('ref:${r.mainId}>${r.duplicateIds.join(',')}');
  }
  return parts.join('|');
}

void main() {
  test('membership builder on the isolate equals the direct build', () async {
    final List<MediaAsset> assets = <MediaAsset>[
      _asset('a', date: DateTime(2026, 10, 20)),
      _asset('b', date: DateTime(2026, 10, 21)),
      _asset('c', date: DateTime(2026, 10, 22)),
    ];
    final Map<String, PhotoAssessment> assessments = <String, PhotoAssessment>{
      'a': _assessment('a', 0),
      'b': _assessment('b', 0),
      'c': _assessment('c', 0xFFFFFFFF),
    };
    final ScanMemberships direct = buildScanMemberships(
      assets: assets,
      assessments: assessments,
    );
    final ScanMemberships isolated = await buildScanMembershipsOnIsolate(
      assets,
      assessments,
    );
    expect(_canonical(isolated), _canonical(direct));
    // …and the content is the expected shape: a+b grouped
    // (similar + exact), c alone.
    expect(direct.groupsOfKind(ScanGroupKind.similar).length, 1);
    expect(direct.duplicateReferences.length, 1);
  });

  test('burst runner on the isolate equals the direct computation', () async {
    final List<MediaAsset> assets = <MediaAsset>[
      _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
      _asset('b', date: DateTime(2026, 10, 20, 12, 0, 2)),
      _asset('c', date: DateTime(2026, 10, 20, 12, 0, 4)),
      _asset('d', date: DateTime(2026, 10, 20, 13, 0, 0)),
    ];
    expect(await burstAssetIdsOnIsolate(assets), burstAssetIds(assets));
    expect(await burstAssetIdsOnIsolate(assets), <String>{'a', 'b', 'c'});
  });
}
