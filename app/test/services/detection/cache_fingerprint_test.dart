// Stage 4 membership freshness + migration tests (requirements
// §7): the persisted memberships are reused only when every
// asset-info fact still matches the live library (the freshness
// rule in scan_memberships_test.dart, exercised end-to-end
// here); an edited photo forces a recompute; a cancelled or
// page-failed scan never overwrites the saved memberships; and
// a legacy pre-Stage 4 analysis cache converts to facts only —
// its groups are discarded, never served as phantom groups,
// and the first Stage 4 scan recomputes.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';

final DateTime _t1 = DateTime(2026, 10, 20, 12);
final DateTime _t2 = DateTime(2026, 10, 21, 12);

MediaAsset _asset(String id, {int size = 1000, DateTime? modified}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
    modifiedDate: modified,
  );
}

/// Solid dark 16x16 PNG (uniform: valid fingerprint, dark).
Uint8List _darkPng() {
  final img.Image image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

/// Half-white / half-black 16x16 PNG (a different fingerprint).
Uint8List _splitPng() {
  final img.Image image = img.Image(width: 16, height: 16);
  for (int y = 0; y < 16; y++) {
    for (int x = 0; x < 16; x++) {
      if (x < 8) {
        image.setPixelRgb(x, y, 250, 250, 250);
      } else {
        image.setPixelRgb(x, y, 5, 5, 5);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

class _Media implements MediaService {
  List<MediaAsset> page0 = <MediaAsset>[];
  bool failAssets = false;
  Uint8List Function(String id) thumbnailFor = (_) => _darkPng();
  int thumbnailCalls = 0;

  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: page0.length),
    ]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (failAssets) {
      return Failure<List<MediaAsset>>(const AppFailure(messageKey: 'x'));
    }
    if (page > 0) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    return Success<List<MediaAsset>>(page0);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    thumbnailCalls++;
    return Success<Uint8List>(thumbnailFor(assetId));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _RealLocal extends LocalServiceImpl {
  _RealLocal({required Directory directory})
    : super(directoryResolver: () async => directory);
}

void main() {
  group('scanner membership freshness (real LocalServiceImpl)', () {
    late Directory temp;
    late _RealLocal local;
    late _Media media;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('klara_fp_test_');
      local = _RealLocal(directory: temp);
      media = _Media();
    });

    tearDown(() async {
      await local.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    Future<ScanMemberships> loadMemberships() async {
      final Result<ScanMemberships> result = await local.loadScanMemberships();
      return result.fold(
        onSuccess: (ScanMemberships value) => value,
        onFailure: (_) => ScanMemberships.empty,
      );
    }

    test('an unchanged library pays NO thumbnail fetch on rescan', () async {
      media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
      media.thumbnailFor = (_) => _darkPng();
      final LibraryScan first = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(first.cancelled, isFalse);
      // Two passes (fingerprint + blur) over one image.
      expect(media.thumbnailCalls, 2);
      expect(
        first.memberships.algorithmVersion,
        scanMembershipAlgorithmVersion,
      );
      // The dark uniform frame lands in the dark membership set.
      expect(first.memberships.memberSetOf(ScanGroupKind.dark), <String>{'a'});

      final LibraryScan second = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      // Facts unchanged: the saved memberships are reused and
      // no photo is read again at all.
      expect(media.thumbnailCalls, 2);
      expect(second.assessments, isEmpty);
      expect(second.memberships.memberSetOf(ScanGroupKind.dark), <String>{'a'});
    });

    test(
      'an edited photo (size + modified + bytes) forces recompute',
      () async {
        media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
        media.thumbnailFor = (_) => _darkPng();
        final LibraryScan first = await LibraryScanner(
          media: media,
          local: local,
        ).scan();
        final int firstHash = first.assessments['a']!.fingerprint!.dHash;
        expect(first.memberships.memberSetOf(ScanGroupKind.dark), <String>{
          'a',
        });

        media.page0 = <MediaAsset>[_asset('a', size: 2000, modified: _t2)];
        media.thumbnailFor = (_) => _splitPng();
        final LibraryScan second = await LibraryScanner(
          media: media,
          local: local,
        ).scan();
        expect(media.thumbnailCalls, 4);
        expect(second.assessments['a']!.fingerprint!.dHash, isNot(firstHash));
        // The split frame is bright on average: no longer dark.
        expect(second.memberships.memberSetOf(ScanGroupKind.dark), isEmpty);
        expect(second.memberships.assetInfos['a']!.sizeBytes, 2000);
        expect(
          second.memberships.assetInfos['a']!.modifiedDateMs,
          _t2.millisecondsSinceEpoch,
        );
      },
    );

    test(
      'deleted assets leave no orphan memberships after a full scan',
      () async {
        media.page0 = <MediaAsset>[_asset('a'), _asset('b')];
        media.thumbnailFor = (_) => _darkPng();
        await LibraryScanner(media: media, local: local).scan();
        expect((await loadMemberships()).assetInfos.keys.toSet(), <String>{
          'a',
          'b',
        });
        media.page0 = <MediaAsset>[_asset('a')];
        await LibraryScanner(media: media, local: local).scan();
        expect((await loadMemberships()).assetInfos.keys.toSet(), <String>{
          'a',
        });
      },
    );

    test('memberships survive a cancelled scan untouched', () async {
      media.page0 = <MediaAsset>[_asset('a')];
      await LibraryScanner(media: media, local: local).scan();
      final ScanMemberships before = await loadMemberships();
      expect(before.algorithmVersion, scanMembershipAlgorithmVersion);
      media.thumbnailFor = (_) => _splitPng();
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan(isCancelled: () => true);
      expect(scan.cancelled, isTrue);
      final ScanMemberships after = await loadMemberships();
      expect(after.algorithmVersion, before.algorithmVersion);
      expect(after.assetInfos.keys.toSet(), before.assetInfos.keys.toSet());
      expect(after.memberSetOf(ScanGroupKind.dark), <String>{'a'});
    });

    test('memberships survive a page-failed scan untouched', () async {
      media.page0 = <MediaAsset>[_asset('a')];
      await LibraryScanner(media: media, local: local).scan();
      media.failAssets = true;
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(scan.pageFailed, isTrue);
      final ScanMemberships after = await loadMemberships();
      expect(after.algorithmVersion, scanMembershipAlgorithmVersion);
      expect(after.assetInfos.keys.toSet(), <String>{'a'});
    });
  });

  group('legacy analysis cache migration (existing installs)', () {
    late Directory temp;
    late _RealLocal local;
    late _Media media;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('klara_legacy_test_');
      local = _RealLocal(directory: temp);
      media = _Media();
    });

    tearDown(() async {
      await local.dispose();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('legacy rows convert to facts only: no phantom groups, '
        'first scan recomputes and restamps', () async {
      // A pre-Stage 4 install: analyses cached by the old
      // engine (hash 7 would have grouped 'a' with anything
      // sharing it under the old rules).
      await local.saveAnalyses(<PhotoAnalysis>[
        PhotoAnalysis(
          assetId: 'a',
          hash: 7,
          width: 10,
          height: 10,
          blurScore: 500,
          meanLuminance: 128,
          sizeBytes: 1000,
          modifiedDateMs: _t1.millisecondsSinceEpoch,
        ),
        PhotoAnalysis(
          assetId: 'ghost',
          hash: 7,
          width: 10,
          height: 10,
          blurScore: 500,
          meanLuminance: 128,
          sizeBytes: 1000,
          modifiedDateMs: _t1.millisecondsSinceEpoch,
        ),
      ]);
      // The membership load converts FACTS only, at version 0,
      // with NO groups — the old engine's groups are discarded.
      final Result<ScanMemberships> converted = await local
          .loadScanMemberships();
      final ScanMemberships snapshot = converted.fold(
        onSuccess: (ScanMemberships v) => v,
        onFailure: (_) => throw StateError('conversion failed'),
      );
      expect(snapshot.algorithmVersion, 0);
      expect(snapshot.assetInfos.keys.toSet(), <String>{'a', 'ghost'});
      expect(snapshot.assetInfos['a']!.width, 10);
      expect(snapshot.groups, isEmpty);
      expect(snapshot.duplicateReferences, isEmpty);

      // The first Stage 4 scan does not trust the conversion:
      // it recomputes (thumbnails fetched) and restamps, and
      // the ghost (not in the live library) leaves no trace.
      media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
      media.thumbnailFor = (_) => _darkPng();
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(media.thumbnailCalls, 2);
      expect(scan.memberships.algorithmVersion, scanMembershipAlgorithmVersion);
      expect(scan.memberships.assetInfos.keys.toSet(), <String>{'a'});
      expect(scan.memberships.groupsOfKind(ScanGroupKind.similar), isEmpty);
    });
  });
}
