// Phase 2B main-deck retention tests (requirements §7):
// expired-snooze clearing on load (asset returns undecided),
// live-snooze keeping the Maybe mark, completion-day recording
// when the final mark lands, the finished summary counts, and
// the share path (image + text fallback + failure key). The
// platform share sheet itself is not unit-testable on this host;
// the fake records what the controller asked to share.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/model/deck_status.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/share/share_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _asset(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class _Media implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  final List<MediaAsset> assets = <MediaAsset>[
    _asset('a', 1000),
    _asset('b', 2000),
  ];

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 2),
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
    if (page > 0) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    return Success<List<MediaAsset>>(assets);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

class _Trash implements TrashService {
  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    return Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    return Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    return const Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final Map<String, DateTime> snoozes = <String, DateTime>{};
  final List<HistoryRecord> history = <HistoryRecord>[];
  final List<DateTime> completions = <DateTime>[];
  final Map<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{};

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
  Future<Result<List<DeckSession>>> listSessions() async {
    return Success<List<DeckSession>>(sessions.values.toList());
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return Success<Map<String, DateTime>>(Map<String, DateTime>.of(snoozes));
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    if (until == null) {
      snoozes.remove(assetId);
    } else {
      snoozes[assetId] = until;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return Success<List<DateTime>>(List<DateTime>.of(completions));
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    completions.add(day);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return Success<List<HistoryRecord>>(List<HistoryRecord>.of(history));
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> list) async {
    for (final PhotoAnalysis a in list) {
      analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(analyses),
    );
  }
}

class _Share implements ShareService {
  _Share({this.fail = false});

  final bool fail;
  String? lastText;
  Uint8List? lastImage;

  @override
  Future<Result<void>> shareSummary({
    required String text,
    Uint8List? imagePng,
  }) async {
    lastText = text;
    lastImage = imagePng;
    if (fail) {
      return const Failure<void>(AppFailure(messageKey: AppStrings.errorShare));
    }
    return const Success<void>(null);
  }
}

void main() {
  tearDown(Get.reset);

  group('DeckController retention', () {
    test('expired snoozed Maybe mark clears on load; asset returns', () async {
      final _Local local = _Local();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 1,
        marks: <String, DeckMark>{'a': DeckMark.maybe},
        favouriteIds: <String>{},
      );
      local.snoozes['a'] = DateTime.now().subtract(const Duration(days: 1));
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      expect(controller.status.value, DeckStatus.ready);
      expect(controller.marks.containsKey('a'), isFalse);
      expect(controller.currentAsset?.id, 'a');
      expect(local.snoozes.containsKey('a'), isFalse);
    });

    test('live snooze keeps the Maybe mark; deck skips the asset', () async {
      final _Local local = _Local();
      local.sessions['all'] = const DeckSession(
        filterKey: 'all',
        currentIndex: 1,
        marks: <String, DeckMark>{'a': DeckMark.maybe},
        favouriteIds: <String>{},
      );
      local.snoozes['a'] = DateTime.now().add(const Duration(days: 7));
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      expect(controller.marks['a'], DeckMark.maybe);
      expect(controller.currentAsset?.id, 'b');
    });

    test('finishing the deck records a completion day and summary', () async {
      final _Local local = _Local();
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      controller.markCurrent(DeckMark.delete);
      expect(controller.isFinished, isTrue);
      expect(local.completions.length, 1);
      final DateTime today = DateTime.now();
      expect(local.completions.first.year, today.year);
      expect(local.completions.first.month, today.month);
      expect(local.completions.first.day, today.day);
      expect(controller.summary.reviewed, 2);
      expect(controller.summary.kept, 1);
      expect(controller.summary.deleteMarked, 1);
      expect(controller.summary.deleteMarkedBytes, 2000);
    });

    test('share sends image when captured, text alone on fallback', () async {
      final _Local local = _Local();
      final _Share share = _Share();
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: local,
        share: share,
      );
      await controller.init();
      controller.markCurrent(DeckMark.keep);
      controller.markCurrent(DeckMark.delete);
      await controller.retention.shareSummary(
        controller.summary,
        Uint8List.fromList(<int>[9, 9, 9]),
      );
      expect(share.lastImage, isNotNull);
      expect(share.lastText, contains('to be freed'));
      await controller.retention.shareSummary(controller.summary, null);
      expect(share.lastImage, isNull);
      expect(share.lastText, contains('2 photos reviewed'));
      expect(controller.retention.shareErrorKey.value, isEmpty);
    });

    test('share failure surfaces an error key, never a crash', () async {
      final _Local local = _Local();
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: local,
        share: _Share(fail: true),
      );
      await controller.init();
      await controller.retention.shareSummary(controller.summary, null);
      expect(controller.retention.shareErrorKey.value, AppStrings.errorShare);
    });

    test('no share backend means no share button (canShare false)', () async {
      final DeckController controller = DeckController(
        media: _Media(),
        trash: _Trash(),
        local: _Local(),
      );
      expect(controller.retention.canShare, isFalse);
    });
  });
}
