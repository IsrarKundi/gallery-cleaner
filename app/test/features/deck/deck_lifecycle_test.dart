// Phase 4.4: deck pause/resume — preloader pauses, resume
// re-checks permission (never a persisted value), refreshes
// page 0 cheaply with marks and position preserved, applies
// snooze expiry once, and flushes at go-to-review, filter
// change, and dispose. A mark during a resume reload waits for
// the reload instead of being overwritten by it.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_filter.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/lifecycle/app_lifecycle.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _video(String id, [DateTime? date]) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: date ?? DateTime(2026, 10, 1),
    title: id,
    albumName: 'All',
  );
}

/// Distinct newest-first dates for a 50-asset page 0, so the
/// page-0 merge can tell a deleted member (newer than the fresh
/// window end) from a displaced one (older than it).
List<MediaAsset> _datedPage0(String prefix, int count) {
  return <MediaAsset>[
    for (int i = 0; i < count; i++)
      _video('$prefix$i', DateTime(2026, 10, 1).subtract(Duration(days: i))),
  ];
}

Uint8List _png() {
  return Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
}

class _FakeLifecycle implements AppLifecycle {
  bool backgrounded = false;
  final List<void Function()> _pause = <void Function()>[];
  final List<void Function()> _resume = <void Function()>[];
  final StreamController<void> changes = StreamController<void>.broadcast();

  @override
  bool get isBackgrounded => backgrounded;

  @override
  Stream<void> get libraryChanged => changes.stream;

  @override
  void addPauseListener(void Function() listener) => _pause.add(listener);

  @override
  void removePauseListener(void Function() listener) => _pause.remove(listener);

  @override
  void addResumeListener(void Function() listener) => _resume.add(listener);

  @override
  void removeResumeListener(void Function() listener) =>
      _resume.remove(listener);

  void firePause() {
    backgrounded = true;
    for (final void Function() l in List<void Function()>.of(_pause)) {
      l();
    }
  }

  void fireResume() {
    backgrounded = false;
    for (final void Function() l in List<void Function()>.of(_resume)) {
      l();
    }
  }
}

class _FakeMedia implements MediaService {
  _FakeMedia(this.all);

  List<MediaAsset> all;
  MediaPermission permission = MediaPermission.grantedFull;
  Completer<MediaPermission>? permissionGate;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    final Completer<MediaPermission>? gate = permissionGate;
    if (gate != null) {
      return Success<MediaPermission>(await gate.future);
    }
    return Success<MediaPermission>(permission);
  }

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async =>
      const Success<List<MediaAlbum>>(<MediaAlbum>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    final int start = page * pageSize;
    if (start >= all.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, all.length);
    return Success<List<MediaAsset>>(all.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      Success<List<MediaAsset>>(
        all.where((MediaAsset a) => ids.contains(a.id)).toList(),
      );

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(_png());
}

class _FakeLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  Map<String, DateTime> snoozes = <String, DateTime>{};
  int flushCalls = 0;
  int clearSnoozesCalls = 0;

  @override
  Future<void> flushPendingWrites() async {
    flushCalls++;
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      const Success<DeckSession?>(null);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      const Success<List<DeckSession>>(<DeckSession>[]);

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      Success<Map<String, DateTime>>(Map<String, DateTime>.of(snoozes));

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    clearSnoozesCalls++;
    for (final String id in ids) {
      snoozes.remove(id);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async => const Success<double>(0);

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
      const Success<void>(null);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      const Success<List<DateTime>>(<DateTime>[]);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
}

class _FakeTrash implements TrashService {
  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async =>
      throw UnimplementedError();

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async =>
      throw UnimplementedError();

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async =>
      throw UnimplementedError();
}

Future<void> _settleUntil(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('condition not met before timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.testMode = false;
  });

  Future<DeckController> readyDeck({
    required _FakeMedia media,
    required _FakeLocal local,
    required _FakeLifecycle lifecycle,
  }) async {
    final DeckController controller = DeckController(
      media: media,
      trash: _FakeTrash(),
      local: local,
      lifecycle: lifecycle,
    );
    controller.onInit();
    await controller.init();
    expect(controller.status.value, DeckStatus.ready);
    return controller;
  }

  test(
    'resume with unchanged permission refreshes page 0, keeps marks',
    () async {
      final _FakeLifecycle lifecycle = _FakeLifecycle();
      final _FakeLocal local = _FakeLocal();
      final List<MediaAsset> initial = _datedPage0('a', 50);
      final _FakeMedia media = _FakeMedia(initial);
      final DeckController controller = await readyDeck(
        media: media,
        local: local,
        lifecycle: lifecycle,
      );
      controller.currentIndex.value = 5; // 'a5'
      controller.marks['a2'] = DeckMark.keep;

      // Library change: two new photos, one page-0 deletion (a3).
      // a49 is pushed past the fresh window, not deleted: it must
      // be kept (older than the fresh window end).
      media.all = <MediaAsset>[
        _video('n1', DateTime(2026, 10, 3)),
        _video('n2', DateTime(2026, 10, 2)),
        for (final MediaAsset asset in initial)
          if (asset.id != 'a3') asset,
      ];
      lifecycle.firePause();
      lifecycle.fireResume();
      await _settleUntil(
        () => controller.queue.isNotEmpty && controller.queue.first.id == 'n1',
      );
      expect(
        controller.queue.map((MediaAsset a) => a.id).take(5).toList(),
        <String>['n1', 'n2', 'a0', 'a1', 'a2'],
      );
      expect(controller.queue.any((MediaAsset a) => a.id == 'a3'), isFalse);
      // 50 - 1 deleted + 2 new; a49 kept (displaced, not deleted).
      expect(controller.queue.length, 51);
      expect(controller.queue.last.id, 'a49');
      expect(controller.currentAsset?.id, 'a5');
      expect(controller.marks['a2'], DeckMark.keep);
    },
  );

  test('foreground library change refreshes immediately', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 50; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    media.all = <MediaAsset>[
      _video('n1'),
      for (int i = 0; i < 50; i++) _video('a$i'),
    ];
    lifecycle.changes.add(null);
    await _settleUntil(() => controller.queue.first.id == 'n1');
    expect(controller.queue.length, 51);
  });

  test('background change does not refresh until resume', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 50; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    lifecycle.firePause();
    media.all = <MediaAsset>[
      _video('n1'),
      for (int i = 0; i < 50; i++) _video('a$i'),
    ];
    lifecycle.changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.queue.first.id, 'a0');
    lifecycle.fireResume();
    await _settleUntil(() => controller.queue.first.id == 'n1');
  });

  test('resume with denied permission shows denied + explanation', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    media.permission = MediaPermission.denied;
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.status.value == DeckStatus.denied);
    expect(controller.errorKey.value, isNotEmpty);
  });

  test('deny then grant in Settings reloads with no manual tap', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[])
      ..permission = MediaPermission.denied;
    final DeckController controller = DeckController(
      media: media,
      trash: _FakeTrash(),
      local: local,
      lifecycle: lifecycle,
    );
    controller.onInit();
    await controller.init();
    expect(controller.status.value, DeckStatus.denied);

    media.permission = MediaPermission.grantedFull;
    media.all = <MediaAsset>[for (int i = 0; i < 10; i++) _video('a$i')];
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.status.value == DeckStatus.ready);
    expect(controller.queue.length, 10);
  });

  test('limited to full grant reloads instead of merging', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('L$i'),
    ])..permission = MediaPermission.grantedLimited;
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    expect(controller.queue.length, 10);

    media.permission = MediaPermission.grantedFull;
    media.all = <MediaAsset>[for (int i = 0; i < 50; i++) _video('F$i')];
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.queue.length == 50);
    expect(
      controller.queue.any((MediaAsset a) => a.id.startsWith('L')),
      isFalse,
    );
    expect(controller.queue.first.id, 'F0');
  });

  test('snooze expiry applies once on resume, in one write', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    local.snoozes = <String, DateTime>{
      'a1': DateTime.now().subtract(const Duration(days: 1)),
    };
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    controller.marks['a1'] = DeckMark.maybe;
    final int writesBefore = local.clearSnoozesCalls;
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => local.clearSnoozesCalls > writesBefore);
    expect(controller.marks.containsKey('a1'), isFalse);
    expect(local.clearSnoozesCalls - writesBefore, 1);
  });

  test('go-to-review, filter change, and dispose all flush', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    final int before = local.flushCalls;
    controller.goToReview();
    expect(local.flushCalls, greaterThan(before));

    final int beforeFilter = local.flushCalls;
    await controller.setFilter(const DeckFilter.album('other'));
    expect(local.flushCalls, greaterThan(beforeFilter));

    final int beforeClose = local.flushCalls;
    controller.onClose();
    expect(local.flushCalls, greaterThan(beforeClose));
  });

  test('a mark during a resume reload waits and is not lost', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeLocal local = _FakeLocal();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DeckController controller = await readyDeck(
      media: media,
      local: local,
      lifecycle: lifecycle,
    );
    // Thumbnails must be visible for markCurrent's 2.5 gate.
    await _settleUntil(
      () => controller.thumbnails.containsKey(controller.currentAsset!.id),
    );
    final String currentId = controller.currentAsset!.id;

    media.permissionGate = Completer<MediaPermission>();
    lifecycle.firePause();
    lifecycle.fireResume();
    // Resume is stalled on the permission gate; the mark must
    // wait for it instead of racing the reload.
    final Future<void> mark = controller.markCurrent(DeckMark.keep);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.marks.containsKey(currentId), isFalse);
    media.permissionGate!.complete(MediaPermission.grantedFull);
    await mark;
    expect(controller.marks[currentId], DeckMark.keep);
    expect(controller.currentIndex.value, 1);
  });
}
