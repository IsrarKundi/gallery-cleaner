// Phase 3.4 (brief 3.4): cold start replays window 0 from the
// persisted session — loadSession + page 0 only, never a full
// scan; filter changes fetch only the new filter's page 0; an
// empty page 0 is an empty deck, not an error. No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_filter.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1×1 PNG, so thumbnails settle for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

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

/// Media fake recording every page fetch (never a full scan: only
/// page 0, then on-demand pages) plus instant thumbnails.
class _RecordingMedia implements MediaService {
  _RecordingMedia({required this.assets});

  final List<MediaAsset> assets;
  final List<String> log = <String>[];

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    log.add('permission');
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    final String scope = albumId != null
        ? 'album:$albumId'
        : monthKey != null
        ? 'month:$monthKey'
        : 'all';
    log.add('page:$page:$scope');
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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(_png);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    log.add('albums');
    return const Success<List<MediaAlbum>>(<MediaAlbum>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the session test: ${invocation.memberName}',
  );
}

/// Local fake: session map + settings + snoozes + sessions list
/// (the protection/snooze loads the deck performs at init).
class _Local implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  // Phase 4.4: setFilter flushes pending writes; the fake must
  // implement it (noSuchMethod would throw).
  @override
  Future<void> flushPendingWrites() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the session test: ${invocation.memberName}',
  );
}

/// Trash fake: only the meter refresh's list call runs here.
class _Trash implements TrashService {
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the session test: ${invocation.memberName}',
  );
}

/// Waits for the current card's thumbnail (marks refuse cards
/// whose thumbnail has not arrived yet, Phase 2.5).
Future<void> _settleThumbnails(DeckController controller) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (true) {
    final String? id = controller.currentAsset?.id;
    if (id == null || controller.thumbnails.containsKey(id)) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the current thumbnail');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('cold start touches only window 0', () async {
    final _RecordingMedia media = _RecordingMedia(
      assets: <MediaAsset>[for (int i = 0; i < 60; i++) _asset('p$i')],
    );
    final DeckController controller = DeckController(
      media: media,
      trash: _Trash(),
      local: _Local(),
    );
    await controller.init();
    expect(controller.status.value, DeckStatus.ready);
    expect(media.log, <String>['permission', 'page:0:all']);
    expect(controller.queue.length, 50);
  });

  test('marks persist and cold start replays window 0', () async {
    final _RecordingMedia media = _RecordingMedia(
      assets: <MediaAsset>[for (int i = 0; i < 60; i++) _asset('p$i')],
    );
    final _Local local = _Local();
    final DeckController first = DeckController(
      media: media,
      trash: _Trash(),
      local: local,
    );
    await first.init();
    for (int i = 0; i < 3; i++) {
      await _settleThumbnails(first);
      await first.markCurrent(DeckMark.keep);
    }
    expect(local.sessions['all']?.currentIndex, 3);
    expect(local.sessions['all']?.marks.length, 3);

    final _RecordingMedia media2 = _RecordingMedia(
      assets: <MediaAsset>[for (int i = 0; i < 60; i++) _asset('p$i')],
    );
    final DeckController second = DeckController(
      media: media2,
      trash: _Trash(),
      local: local,
    );
    await second.init();
    expect(second.status.value, DeckStatus.ready);
    expect(second.marks.length, 3);
    expect(second.currentIndex.value, 3);
    // Replay fetched page 0 only — no page 1, no albums.
    expect(media2.log, <String>['permission', 'page:0:all']);
    expect(second.queue.length, 50);
  });

  test('filter change fetches only the new filter page 0', () async {
    final _RecordingMedia media = _RecordingMedia(
      assets: <MediaAsset>[for (int i = 0; i < 60; i++) _asset('p$i')],
    );
    final DeckController controller = DeckController(
      media: media,
      trash: _Trash(),
      local: _Local(),
    );
    await controller.init();
    await controller.setFilter(const DeckFilter.month('2026-10'));
    expect(controller.status.value, DeckStatus.ready);
    expect(media.log, <String>[
      'permission',
      'page:0:all',
      'page:0:month:2026-10',
    ]);
    expect(media.log.where((String e) => e.startsWith('page:1')), isEmpty);
    expect(media.log.where((String e) => e == 'albums'), isEmpty);
  });

  test('empty page 0 is an empty deck, not an error', () async {
    final DeckController controller = DeckController(
      media: _RecordingMedia(assets: <MediaAsset>[]),
      trash: _Trash(),
      local: _Local(),
    );
    await controller.init();
    expect(controller.status.value, DeckStatus.ready);
    expect(controller.queue, isEmpty);
    expect(controller.currentAsset, isNull);
  });
}
