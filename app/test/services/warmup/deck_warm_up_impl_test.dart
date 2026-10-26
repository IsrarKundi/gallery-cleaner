// Warm-up consumption tests (ADR-011): the warmed page is handed
// out on the first read only. A later deck — e.g. after a shell
// rebuild — must fetch page 0 fresh instead of reusing a page
// warmed before a trash run (trashed photos sit in the warmed
// page with cleared marks and would reappear as undecided).

import 'package:flutter_test/flutter_test.dart';

import 'package:klara/core/utils/result.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/warmup/deck_warm_up_impl.dart';

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

class _Media implements MediaService {
  _Media({this.permission = MediaPermission.grantedFull});

  final MediaPermission permission;
  int getAssetsCalls = 0;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    getAssetsCalls++;
    return Success<List<MediaAsset>>(<MediaAsset>[_asset('a'), _asset('b')]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by warm-up tests: ${invocation.memberName}',
  );
}

void main() {
  test('first read returns the warmed page, second read is null', () async {
    final DeckWarmUpImpl warmUp = DeckWarmUpImpl(media: _Media());
    warmUp.start();

    final List<MediaAsset>? first = await warmUp.firstPage;
    expect(first?.map((MediaAsset a) => a.id), <String>['a', 'b']);

    final List<MediaAsset>? second = await warmUp.firstPage;
    expect(second, isNull);
  });

  test('permission is not consumed with the page', () async {
    final DeckWarmUpImpl warmUp = DeckWarmUpImpl(media: _Media());
    warmUp.start();

    await warmUp.firstPage;
    await warmUp.firstPage;
    expect(await warmUp.permission, MediaPermission.grantedFull);
  });

  test('never started reads null', () async {
    final DeckWarmUpImpl warmUp = DeckWarmUpImpl(media: _Media());
    expect(await warmUp.firstPage, isNull);
    expect(await warmUp.permission, isNull);
  });

  test('denied permission warms no page', () async {
    final DeckWarmUpImpl warmUp = DeckWarmUpImpl(
      media: _Media(permission: MediaPermission.denied),
    );
    warmUp.start();
    expect(await warmUp.firstPage, isNull);
    expect(await warmUp.permission, MediaPermission.denied);
  });
}
