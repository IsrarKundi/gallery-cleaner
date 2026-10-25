// Phase 5.3 cache fingerprint + prune tests (requirements §7):
// a cached analysis is reused only when it still describes the
// exact file (version + dimensions + size + modified date); an
// edited photo is re-analysed, old-version entries are
// re-analysed, and orphan entries are pruned only after a fully
// completed scan — never after a cancelled or page-failed one.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_analysis.dart';
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

PhotoAnalysis _analysis(
  String id, {
  int version = analysisAlgorithmVersion,
  int size = 1000,
  DateTime? modified,
  int width = 10,
  int height = 10,
}) {
  return PhotoAnalysis(
    assetId: id,
    hash: 7,
    width: width,
    height: height,
    blurScore: 500,
    meanLuminance: 128,
    sizeBytes: size,
    modifiedDateMs: modified?.millisecondsSinceEpoch,
    algorithmVersion: version,
  );
}

/// Solid dark 16x16 PNG (uniform → one hash).
Uint8List _darkPng() {
  final img.Image image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

/// Half-white / half-black 16x16 PNG (a different hash).
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
  group('isAnalysisFresh', () {
    test('same fingerprint is fresh', () {
      expect(
        isAnalysisFresh(
          _analysis('a', modified: _t1),
          _asset('a', modified: _t1),
        ),
        isTrue,
      );
    });

    test('changed modified date is stale', () {
      expect(
        isAnalysisFresh(
          _analysis('a', modified: _t1),
          _asset('a', modified: _t2),
        ),
        isFalse,
      );
    });

    test('changed size is stale', () {
      expect(
        isAnalysisFresh(_analysis('a', size: 1000), _asset('a', size: 2000)),
        isFalse,
      );
    });

    test('changed dimensions are stale', () {
      expect(
        isAnalysisFresh(_analysis('a', width: 10, height: 10), _asset('a')),
        isTrue,
      );
      final MediaAsset wider = MediaAsset(
        id: 'a',
        type: MediaAssetType.image,
        width: 20,
        height: 10,
        sizeBytes: 1000,
        createDate: DateTime(2026, 10, 20),
        title: 'a.jpg',
        albumName: 'Camera',
      );
      expect(isAnalysisFresh(_analysis('a'), wider), isFalse);
    });

    test('old algorithm version is stale', () {
      expect(
        isAnalysisFresh(
          _analysis('a', version: 0, modified: _t1),
          _asset('a', modified: _t1),
        ),
        isFalse,
      );
    });

    test('null modified on both sides is fresh', () {
      expect(isAnalysisFresh(_analysis('a'), _asset('a')), isTrue);
    });

    test('one-sided null modified is stale', () {
      expect(
        isAnalysisFresh(_analysis('a', modified: _t1), _asset('a')),
        isFalse,
      );
      expect(
        isAnalysisFresh(_analysis('a'), _asset('a', modified: _t1)),
        isFalse,
      );
    });
  });

  group('PhotoAnalysis JSON back-compat', () {
    test('old entries without new fields load as version 0', () {
      final PhotoAnalysis parsed = PhotoAnalysis.fromJson(<String, dynamic>{
        'assetId': 'a',
        'hash': 7,
        'width': 10,
        'height': 10,
        'blurScore': 500.0,
        'meanLuminance': 128.0,
      });
      expect(parsed.algorithmVersion, 0);
      expect(parsed.sizeBytes, isNull);
      expect(parsed.modifiedDateMs, isNull);
      // …and are therefore stale against any current asset.
      expect(isAnalysisFresh(parsed, _asset('a')), isFalse);
    });

    test('round-trip preserves the fingerprint', () {
      final PhotoAnalysis original = _analysis('a', modified: _t1);
      final PhotoAnalysis parsed = PhotoAnalysis.fromJson(original.toJson());
      expect(parsed.algorithmVersion, analysisAlgorithmVersion);
      expect(parsed.sizeBytes, 1000);
      expect(parsed.modifiedDateMs, _t1.millisecondsSinceEpoch);
      expect(isAnalysisFresh(parsed, _asset('a', modified: _t1)), isTrue);
    });
  });

  group('scanner fingerprint + prune (real LocalServiceImpl)', () {
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

    Future<Map<String, PhotoAnalysis>> loadCache() async {
      final Result<Map<String, PhotoAnalysis>> result = await local
          .loadAnalyses();
      return result.fold(
        onSuccess: (Map<String, PhotoAnalysis> value) => value,
        onFailure: (_) => <String, PhotoAnalysis>{},
      );
    }

    test('edited photo is re-analysed with a new hash', () async {
      media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
      media.thumbnailFor = (_) => _darkPng();
      final LibraryScan first = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(first.cancelled, isFalse);
      expect(media.thumbnailCalls, 1);
      final int firstHash = first.analyses['a']!.hash;

      // Same id, new size + modified date + new bytes: an edit.
      media.page0 = <MediaAsset>[_asset('a', size: 2000, modified: _t2)];
      media.thumbnailFor = (_) => _splitPng();
      final LibraryScan second = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(second.cancelled, isFalse);
      // The stale entry did NOT satisfy the scan: the thumbnail
      // was fetched again and the hash changed.
      expect(media.thumbnailCalls, 2);
      expect(second.analyses['a']!.hash, isNot(firstHash));
      expect(second.analyses['a']!.sizeBytes, 2000);
      expect(second.analyses['a']!.modifiedDateMs, _t2.millisecondsSinceEpoch);
      expect(second.analyses['a']!.algorithmVersion, 1);
    });

    test('unchanged photo pays no thumbnail fetch on rescan', () async {
      media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
      media.thumbnailFor = (_) => _darkPng();
      await LibraryScanner(media: media, local: local).scan();
      expect(media.thumbnailCalls, 1);
      await LibraryScanner(media: media, local: local).scan();
      expect(media.thumbnailCalls, 1);
    });

    test('old-version entry is re-analysed, never mixed', () async {
      await local.saveAnalyses(<PhotoAnalysis>[
        _analysis('a', version: 0, modified: _t1),
      ]);
      media.page0 = <MediaAsset>[_asset('a', size: 1000, modified: _t1)];
      media.thumbnailFor = (_) => _darkPng();
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(media.thumbnailCalls, 1);
      expect(scan.analyses['a']!.algorithmVersion, 1);
    });

    test('deleted assets leave no orphan analyses after a full scan', () async {
      media.page0 = <MediaAsset>[_asset('a'), _asset('b')];
      media.thumbnailFor = (_) => _darkPng();
      await LibraryScanner(media: media, local: local).scan();
      expect((await loadCache()).keys.toSet(), <String>{'a', 'b'});
      media.page0 = <MediaAsset>[_asset('a')];
      await LibraryScanner(media: media, local: local).scan();
      expect((await loadCache()).keys.toSet(), <String>{'a'});
    });

    test('orphans survive a cancelled scan', () async {
      await local.saveAnalyses(<PhotoAnalysis>[
        _analysis('a'),
        _analysis('b'),
        _analysis('orphan'),
      ]);
      media.page0 = <MediaAsset>[_asset('a')];
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan(isCancelled: () => true);
      expect(scan.cancelled, isTrue);
      expect((await loadCache()).keys.toSet(), <String>{'a', 'b', 'orphan'});
    });

    test('orphans survive a page-failed scan', () async {
      await local.saveAnalyses(<PhotoAnalysis>[
        _analysis('a'),
        _analysis('b'),
        _analysis('orphan'),
      ]);
      media.failAssets = true;
      final LibraryScan scan = await LibraryScanner(
        media: media,
        local: local,
      ).scan();
      expect(scan.pageFailed, isTrue);
      expect((await loadCache()).keys.toSet(), <String>{'a', 'b', 'orphan'});
    });
  });
}
