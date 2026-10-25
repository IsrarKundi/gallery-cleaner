// Phase 2.5 controller tests: DeckController refuses marks on a
// card whose thumbnail is not visible (still loading or failed),
// and recovers via the explicit retry once bytes arrive.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

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

class _ReadinessMedia implements MediaService {
  _ReadinessMedia({this.assets = const <MediaAsset>[]});

  final List<MediaAsset> assets;

  /// When set, thumbnail fetches wait on this future (loading
  /// state). When [failThumbnails] is true, they fail instead.
  Future<Uint8List>? gatedThumbnails;
  bool failThumbnails = false;

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
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    return Success<List<MediaAsset>>(assets);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return Success<List<MediaAsset>>(
      assets.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    final Future<Uint8List>? gated = gatedThumbnails;
    if (gated != null) {
      return Success<Uint8List>(await gated);
    }
    if (failThumbnails) {
      return const Failure<Uint8List>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

class _ReadinessLocal implements LocalService {
  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(
      DeckSession(
        filterKey: filterKey,
        currentIndex: 0,
        marks: <String, DeckMark>{},
        favouriteIds: <String>{},
      ),
    );
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(false);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected LocalService call: ${invocation.memberName}',
    );
  }
}

class _ReadinessTrash implements TrashService {
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    return const Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    return const Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected TrashService call: ${invocation.memberName}',
    );
  }
}

/// Polls [condition] until true or [timeout] elapses. The thumbnail
/// service publishes bytes/failures asynchronously, so tests must
/// wait for them instead of assuming they land with init.
Future<void> _pollUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('DeckController first-card readiness (Phase 2.5)', () {
    test('mark refused while loading, accepted once visible', () async {
      final _ReadinessMedia media = _ReadinessMedia(
        assets: <MediaAsset>[_asset('a1'), _asset('a2')],
      );
      // Thumbnails stay in flight until this future completes.
      final Completer<Uint8List> gate = Completer<Uint8List>();
      media.gatedThumbnails = gate.future;
      final DeckController controller = DeckController(
        media: media,
        trash: _ReadinessTrash(),
        local: _ReadinessLocal(),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);

      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks, isEmpty);
      expect(controller.currentIndex.value, 0);

      gate.complete(Uint8List.fromList(<int>[1, 2, 3]));
      await _pollUntil(() => controller.thumbnails.containsKey('a1'));
      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks['a1'], DeckMark.delete);
      expect(controller.currentIndex.value, 1);
    });

    test('failed card refused, retry recovers once bytes arrive', () async {
      final _ReadinessMedia media = _ReadinessMedia(
        assets: <MediaAsset>[_asset('a1'), _asset('a2')],
      );
      media.failThumbnails = true;
      final DeckController controller = DeckController(
        media: media,
        trash: _ReadinessTrash(),
        local: _ReadinessLocal(),
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      await _pollUntil(() => controller.failedThumbnails.contains('a1'));

      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks, isEmpty);
      expect(controller.currentIndex.value, 0);

      media.failThumbnails = false;
      controller.retryCurrentThumbnail();
      await _pollUntil(() => controller.thumbnails.containsKey('a1'));
      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks['a1'], DeckMark.delete);
    });
  });
}
