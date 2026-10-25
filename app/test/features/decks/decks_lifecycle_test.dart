// Phase 4.4: hub pause/resume — background pauses the shared
// scan, resume re-checks permission, and a dirty library gets a
// fresh scan on resume (no rescan when clean). A scan is never
// left paused by a disposed controller.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/lifecycle/app_lifecycle.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _video(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 1),
    title: id,
    albumName: 'All',
  );
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
  Completer<void>? page1Gate;
  int getAssetsCalls = 0;

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      Success<MediaPermission>(permission);

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
    getAssetsCalls++;
    if (page == 1 && page1Gate != null) {
      await page1Gate!.future;
    }
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
  }) async => Success<Uint8List>(Uint8List(0));
}

class _FakeLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
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
      const Success<Map<String, DateTime>>(<String, DateTime>{});

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<void> flushPendingWrites() async {}

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

Future<void> _settleUntil(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
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
  test(
    'pause stalls the scan at the page boundary; resume continues',
    () async {
      // The pause gate sits BEFORE each page fetch, so the stall
      // is observable only at a boundary after the in-flight page
      // lands: 110 assets = pages 50/50/10, page 1 gated.
      final _FakeLifecycle lifecycle = _FakeLifecycle();
      final _FakeMedia media = _FakeMedia(<MediaAsset>[
        for (int i = 0; i < 110; i++) _video('a$i'),
      ]);
      media.page1Gate = Completer<void>();
      final DecksController controller = DecksController(
        media: media,
        local: _FakeLocal(),
        lifecycle: lifecycle,
      );
      controller.onInit();
      await _settleUntil(() => controller.scanned.value == 50);
      lifecycle.firePause();
      media.page1Gate!.complete();
      // Page 1 lands, then the page-2 fetch must block on pause.
      await _settleUntil(() => controller.scanned.value == 100);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.scanComplete.value, isFalse);
      lifecycle.fireResume();
      await _settleUntil(() => controller.scanComplete.value);
      expect(controller.allAssets.length, 110);
    },
  );

  test('resume with denied permission shows denied', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DecksController controller = DecksController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.scanComplete.value);
    media.permission = MediaPermission.denied;
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.status.value == DecksStatus.denied);
    expect(controller.errorKey.value, isNotEmpty);
  });

  test('dirty library gets a fresh scan on resume', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 60; i++) _video('a$i'),
    ]);
    final DecksController controller = DecksController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.scanComplete.value);
    expect(controller.allAssets.length, 60);

    lifecycle.changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    media.all = <MediaAsset>[
      _video('new1'),
      for (int i = 0; i < 60; i++) _video('a$i'),
    ];
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(
      () => controller.allAssets.any((MediaAsset a) => a.id == 'new1'),
    );
    expect(controller.allAssets.length, 61);
  });

  test('clean resume performs no rescan', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 10; i++) _video('a$i'),
    ]);
    final DecksController controller = DecksController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.scanComplete.value);
    final int calls = media.getAssetsCalls;
    lifecycle.firePause();
    lifecycle.fireResume();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(media.getAssetsCalls, calls);
    expect(controller.status.value, DecksStatus.ready);
  });

  test('revoke mid-scan denies cleanly; re-grant resumes the scan', () async {
    // Edge case from the solutions doc: permission revoked
    // while a scan runs must stop with an error state, never a
    // crash — and the paused scan must complete once the grant
    // returns (the resume path resumes before any reload).
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[
      for (int i = 0; i < 110; i++) _video('a$i'),
    ]);
    media.page1Gate = Completer<void>();
    final DecksController controller = DecksController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.scanned.value == 50);
    // Background mid-scan, revoke in Settings, foreground.
    lifecycle.firePause();
    media.permission = MediaPermission.denied;
    media.page1Gate!.complete();
    lifecycle.fireResume();
    await _settleUntil(() => controller.status.value == DecksStatus.denied);
    expect(controller.errorKey.value, isNotEmpty);
    expect(controller.scanComplete.value, isFalse);
    // Re-grant: the paused scan resumes and completes.
    media.permission = MediaPermission.grantedFull;
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.scanComplete.value);
    expect(controller.allAssets.length, 110);
  });

  test('deny then grant reloads with no manual tap', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(<MediaAsset>[])
      ..permission = MediaPermission.denied;
    final DecksController controller = DecksController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.status.value == DecksStatus.denied);
    media.permission = MediaPermission.grantedFull;
    media.all = <MediaAsset>[for (int i = 0; i < 10; i++) _video('a$i')];
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.scanComplete.value);
    expect(controller.allAssets.length, 10);
  });
}
