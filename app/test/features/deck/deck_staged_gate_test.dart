// Phase 2.2 tests: the staged ready-gate, lazy albums, the
// parallel protection load, and the splash warm-up join.
//
// Fakes record call order so the gate is proven, not assumed: the
// critical path to ready is session + page 0 + restore ONLY —
// albums never load at init, the tutorial flag and protection load
// in parallel, and the meter refreshes after ready.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_filter.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';
import 'package:klara/services/warmup/deck_warm_up.dart';

MediaAsset _asset(String id, {bool systemFavourite = false}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
    isSystemFavourite: systemFavourite,
  );
}

class _RecordingMedia implements MediaService {
  final List<String> log = <String>[];
  List<MediaAsset> assets = <MediaAsset>[_asset('a1'), _asset('a2')];
  MediaPermission permission = MediaPermission.grantedFull;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    log.add('permission');
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    log.add('albums');
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'cam', name: 'Camera', count: 2),
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
    log.add('page:$page:${albumId ?? 'all'}');
    return Success<List<MediaAsset>>(assets);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }
}

class _FakeLocal implements LocalService {
  _FakeLocal({
    this.protectionOn = false,
    this.tutorialSeen = true,
    this.session,
  });

  final bool protectionOn;
  final bool tutorialSeen;
  DeckSession? session;

  final List<String> sessionKeys = <String>[];
  Completer<Result<AppSettings>>? settingsGate;

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    sessionKeys.add(filterKey);
    return Success<DeckSession?>(session);
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    this.session = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return Success<bool>(tutorialSeen);
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    if (settingsGate != null) {
      return settingsGate!.future;
    }
    return Success<AppSettings>(AppSettings(protection: protectionOn));
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return Success<List<DeckSession>>(
      session == null ? <DeckSession>[] : <DeckSession>[session!],
    );
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected LocalService call: ${invocation.memberName}',
    );
  }
}

class _FakeTrash implements TrashService {
  int listTrashedCalls = 0;

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    listTrashedCalls++;
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected TrashService call: ${invocation.memberName}',
    );
  }
}

class _FakeWarmUp implements DeckWarmUp {
  _FakeWarmUp({this.started = true, this.warmPermission, this.warmFirstPage});

  @override
  final bool started;

  final MediaPermission? warmPermission;
  final List<MediaAsset>? warmFirstPage;

  @override
  void start() {}

  @override
  Future<MediaPermission?> get permission async => warmPermission;

  @override
  Future<List<MediaAsset>?> get firstPage async => warmFirstPage;
}

DeckController _controller({
  required _RecordingMedia media,
  required _FakeLocal local,
  required _FakeTrash trash,
  DeckWarmUp? warmUp,
}) {
  return DeckController(
    media: media,
    trash: trash,
    local: local,
    warmUp: warmUp,
  );
}

void main() {
  group('staged ready-gate', () {
    test('init reaches ready without albums; meter refreshes after', () async {
      final _RecordingMedia media = _RecordingMedia();
      final _FakeLocal local = _FakeLocal();
      final _FakeTrash trash = _FakeTrash();
      final DeckController controller = _controller(
        media: media,
        local: local,
        trash: trash,
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(media.log, <String>['permission', 'page:0:all']);
      expect(controller.albums, isEmpty);
      // The meter refresh is post-ready, not gating: it still runs.
      for (int i = 0; i < 100 && trash.listTrashedCalls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(trash.listTrashedCalls, greaterThan(0));
    });

    test('tutorial flag lands without gating ready', () async {
      final _RecordingMedia media = _RecordingMedia();
      final _FakeLocal local = _FakeLocal(tutorialSeen: false);
      final DeckController controller = _controller(
        media: media,
        local: local,
        trash: _FakeTrash(),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      for (int i = 0; i < 100 && !controller.showTutorial.value; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.showTutorial.value, isTrue);
    });

    test(
      'albums load lazily once, and filter change does not reload',
      () async {
        final _RecordingMedia media = _RecordingMedia();
        final DeckController controller = _controller(
          media: media,
          local: _FakeLocal(),
          trash: _FakeTrash(),
        );
        await controller.init();
        expect(media.log.where((String e) => e == 'albums'), isEmpty);
        await controller.ensureAlbums();
        await controller.ensureAlbums();
        expect(media.log.where((String e) => e == 'albums').length, 1);
        expect(controller.albums.map((a) => a.name).toList(), <String>[
          'Camera',
        ]);
        await controller.setFilter(const DeckFilter.album('cam'));
        expect(controller.status.value, DeckStatus.ready);
        expect(media.log.where((String e) => e == 'albums').length, 1);
      },
    );
  });

  group('protection gate', () {
    test('a delete mark waits for the protection load', () async {
      final _FakeLocal local = _FakeLocal(
        protectionOn: true,
        session: DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{},
          favouriteIds: <String>{'a1'},
        ),
      );
      local.settingsGate = Completer<Result<AppSettings>>();
      final DeckController controller = _controller(
        media: _RecordingMedia(),
        local: local,
        trash: _FakeTrash(),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);

      // The delete waits: nothing recorded while the load is pending.
      final Future<void> pendingDelete = controller.markCurrent(
        DeckMark.delete,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.marks.containsKey('a1'), isFalse);

      // Releasing the load lets it decide: blocked, still on a1.
      local.settingsGate!.complete(
        Success<AppSettings>(const AppSettings(protection: true)),
      );
      await pendingDelete;
      expect(controller.marks.containsKey('a1'), isFalse);
      expect(controller.protection.blockedKey.value, isNotEmpty);
      expect(controller.currentAsset?.id, 'a1');
    });

    test('a non-delete mark does not wait for the protection load', () async {
      final _FakeLocal local = _FakeLocal(protectionOn: true);
      local.settingsGate = Completer<Result<AppSettings>>();
      final DeckController controller = _controller(
        media: _RecordingMedia(),
        local: local,
        trash: _FakeTrash(),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);

      // The keep returns while the protection load is still pending:
      // if it waited, this await would hang on the uncompleted gate.
      await controller.markCurrent(DeckMark.keep);
      expect(controller.marks['a1'], DeckMark.keep);
      expect(local.settingsGate!.isCompleted, isFalse);
      local.settingsGate!.complete(
        Success<AppSettings>(const AppSettings(protection: true)),
      );
    });

    test('delete on a protected photo is blocked once loaded', () async {
      final _FakeLocal local = _FakeLocal(
        protectionOn: true,
        session: DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{},
          favouriteIds: <String>{'a1'},
        ),
      );
      final DeckController controller = _controller(
        media: _RecordingMedia(),
        local: local,
        trash: _FakeTrash(),
      );
      await controller.init();
      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks.containsKey('a1'), isFalse);
      expect(controller.protection.blockedKey.value, isNotEmpty);
      expect(controller.currentAsset?.id, 'a1');
    });
  });

  group('splash warm-up join', () {
    test('warmed permission + page skip media calls entirely', () async {
      final _RecordingMedia media = _RecordingMedia();
      final DeckController controller = _controller(
        media: media,
        local: _FakeLocal(),
        trash: _FakeTrash(),
        warmUp: _FakeWarmUp(
          warmPermission: MediaPermission.grantedFull,
          warmFirstPage: <MediaAsset>[_asset('w1'), _asset('w2')],
        ),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.queue.map((a) => a.id).toList(), <String>['w1', 'w2']);
      expect(media.log, isEmpty);
    });

    test('warmed denial reaches denied without re-prompting', () async {
      final _RecordingMedia media = _RecordingMedia();
      final DeckController controller = _controller(
        media: media,
        local: _FakeLocal(),
        trash: _FakeTrash(),
        warmUp: _FakeWarmUp(warmPermission: MediaPermission.denied),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.denied);
      expect(media.log, isEmpty);
    });

    test('warmed page failure falls back to a fresh fetch', () async {
      final _RecordingMedia media = _RecordingMedia();
      final DeckController controller = _controller(
        media: media,
        local: _FakeLocal(),
        trash: _FakeTrash(),
        warmUp: _FakeWarmUp(
          warmPermission: MediaPermission.grantedFull,
          warmFirstPage: null,
        ),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.queue.map((a) => a.id).toList(), <String>['a1', 'a2']);
      expect(media.log, <String>['page:0:all']);
    });

    test('warm-up never started means the normal path', () async {
      final _RecordingMedia media = _RecordingMedia();
      final DeckController controller = _controller(
        media: media,
        local: _FakeLocal(),
        trash: _FakeTrash(),
        warmUp: _FakeWarmUp(
          started: false,
          warmPermission: MediaPermission.grantedFull,
          warmFirstPage: <MediaAsset>[_asset('w1')],
        ),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.queue.map((a) => a.id).toList(), <String>['a1', 'a2']);
      expect(media.log, <String>['permission', 'page:0:all']);
    });
  });
}
