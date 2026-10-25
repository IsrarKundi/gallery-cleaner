// Phase 2.4 regression tests: review opened from the bottom nav
// (no route arguments) must resolve ALL delete-marked ids —
// including marks beyond the newest 50 assets, which the old
// page-0 filter silently dropped (issues file F-19).
//
// The fake media service's page 0 returns only the first 50 of 60
// assets on purpose: under the old code this test would return 50,
// not 60. Its `getAssetsByIds` resolves from the full backing list,
// newest first, like the real implementation.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_session.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';

MediaAsset _asset(String id, DateTime date) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: date,
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class _SessionMedia implements MediaService {
  _SessionMedia(this.assets);

  final List<MediaAsset> assets;
  bool failByIds = false;

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    final int start = page * pageSize;
    if (start >= assets.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize) > assets.length
        ? assets.length
        : start + pageSize;
    return Success<List<MediaAsset>>(assets.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    if (failByIds) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: 'errorMediaLoad'),
      );
    }
    final List<MediaAsset> found =
        assets.where((MediaAsset a) => ids.contains(a.id)).toList()
          ..sort((MediaAsset a, MediaAsset b) {
            final int byDate = b.createDate.compareTo(a.createDate);
            return byDate != 0 ? byDate : a.id.compareTo(b.id);
          });
    return Success<List<MediaAsset>>(found);
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1]));
  }
}

class _SessionLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  _SessionLocal(this.session);

  final DeckSession? session;

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected LocalService call: ${invocation.memberName}',
    );
  }
}

void main() {
  group('loadDeleteMarkedAssets (bottom-nav path)', () {
    test('resolves delete marks beyond the newest 50 assets', () async {
      // 60 assets, newest first: m0 is newest, m59 oldest.
      final List<MediaAsset> assets = List<MediaAsset>.generate(
        60,
        (int i) =>
            _asset('m$i', DateTime(2026, 10, 1).add(Duration(days: 60 - i))),
      );
      final _SessionMedia media = _SessionMedia(assets);
      final _SessionLocal local = _SessionLocal(
        DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{
            for (final MediaAsset a in assets) a.id: DeckMark.delete,
          },
          favouriteIds: <String>{},
        ),
      );
      final List<MediaAsset> loaded = await loadDeleteMarkedAssets(
        local: local,
        media: media,
        filterKey: 'all',
      );
      expect(loaded.length, 60);
      expect(loaded.map((MediaAsset a) => a.id).toSet(), <String>{
        for (int i = 0; i < 60; i++) 'm$i',
      });
      // Newest first, like the route-argument path's queue order.
      expect(loaded.first.id, 'm0');
      expect(loaded.last.id, 'm59');
    });

    test('gone ids are skipped, not failed', () async {
      final _SessionMedia media = _SessionMedia(<MediaAsset>[
        _asset('a', DateTime(2026, 10, 5)),
        _asset('b', DateTime(2026, 10, 4)),
      ]);
      final _SessionLocal local = _SessionLocal(
        DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{
            'a': DeckMark.delete,
            'gone': DeckMark.delete,
            'b': DeckMark.delete,
            'k': DeckMark.keep,
          },
          favouriteIds: <String>{},
        ),
      );
      final List<MediaAsset> loaded = await loadDeleteMarkedAssets(
        local: local,
        media: media,
        filterKey: 'all',
      );
      expect(loaded.map((MediaAsset a) => a.id).toList(), <String>['a', 'b']);
    });

    test('media failure returns an empty list, never throws', () async {
      final _SessionMedia media = _SessionMedia(<MediaAsset>[
        _asset('a', DateTime(2026, 10, 5)),
      ]);
      media.failByIds = true;
      final _SessionLocal local = _SessionLocal(
        DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{'a': DeckMark.delete},
          favouriteIds: <String>{},
        ),
      );
      final List<MediaAsset> loaded = await loadDeleteMarkedAssets(
        local: local,
        media: media,
        filterKey: 'all',
      );
      expect(loaded, isEmpty);
    });

    test('no session or no delete marks returns empty', () async {
      final _SessionMedia media = _SessionMedia(<MediaAsset>[
        _asset('a', DateTime(2026, 10, 5)),
      ]);
      expect(
        await loadDeleteMarkedAssets(
          local: _SessionLocal(null),
          media: media,
          filterKey: 'all',
        ),
        isEmpty,
      );
      expect(
        await loadDeleteMarkedAssets(
          local: _SessionLocal(
            DeckSession(
              filterKey: 'all',
              currentIndex: 0,
              marks: <String, DeckMark>{'a': DeckMark.keep},
              favouriteIds: <String>{},
            ),
          ),
          media: media,
          filterKey: 'all',
        ),
        isEmpty,
      );
    });
  });
}
