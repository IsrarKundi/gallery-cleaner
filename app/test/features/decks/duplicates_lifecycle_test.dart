// Phase 4.4: Duplicates resume — permission re-check and a
// dirty library's fresh scan (groups recomputed from the new
// library, not the memoised one).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/lifecycle/app_lifecycle.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _image(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 1),
    title: id,
    albumName: 'All',
  );
}

Uint8List _solidPng(int r, int g, int b) {
  final img.Image image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
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
  _FakeMedia(this.all, this.bytesById);

  List<MediaAsset> all;
  Map<String, Uint8List> bytesById;
  MediaPermission permission = MediaPermission.grantedFull;

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
  }) async => Success<Uint8List>(bytesById[assetId] ?? Uint8List(0));
}

class _FakeLocal implements LocalService {
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
  test('resume with denied permission shows denied', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(
      <MediaAsset>[_image('d1'), _image('d2')],
      <String, Uint8List>{
        'd1': _solidPng(10, 20, 30),
        'd2': _solidPng(10, 20, 30),
      },
    );
    final DuplicatesController controller = DuplicatesController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.status.value == DecksStatus.ready);
    expect(controller.groups.length, 1);
    media.permission = MediaPermission.denied;
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(() => controller.status.value == DecksStatus.denied);
    expect(controller.errorKey.value, isNotEmpty);
  });

  test('dirty library regroups from a fresh scan on resume', () async {
    final _FakeLifecycle lifecycle = _FakeLifecycle();
    final _FakeMedia media = _FakeMedia(
      <MediaAsset>[_image('d1'), _image('d2')],
      <String, Uint8List>{
        'd1': _solidPng(10, 20, 30),
        'd2': _solidPng(10, 20, 30),
      },
    );
    final DuplicatesController controller = DuplicatesController(
      media: media,
      local: _FakeLocal(),
      lifecycle: lifecycle,
    );
    controller.onInit();
    await _settleUntil(() => controller.status.value == DecksStatus.ready);
    expect(controller.groups.length, 1);
    expect(controller.groups.first.assets.map((a) => a.id).toSet(), <String>{
      'd1',
      'd2',
    });

    lifecycle.changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    media.all = <MediaAsset>[_image('d3'), _image('d4')];
    media.bytesById = <String, Uint8List>{
      'd3': _solidPng(200, 30, 40),
      'd4': _solidPng(200, 30, 40),
    };
    lifecycle.firePause();
    lifecycle.fireResume();
    await _settleUntil(
      () =>
          controller.groups.isNotEmpty &&
          controller.groups.first.assets
              .map((a) => a.id)
              .toSet()
              .contains('d3'),
    );
    expect(controller.groups.length, 1);
    expect(controller.groups.first.assets.map((a) => a.id).toSet(), <String>{
      'd3',
      'd4',
    });
  });
}
