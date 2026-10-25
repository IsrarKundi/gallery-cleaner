// ReviewController tests with in-memory fakes (no device, no
// MediaStore).
//
// Covers: unmark removes from the grid and the session; keep-all sets
// keep marks; trash success partitions (trashed clears marks +
// appends one history record with trashed MB and freed 0; denied
// clears marks + explanation state; failed keeps marks + error
// state); mixed runs; service failure. Navigation is deliberately
// not asserted — Get.offAllNamed is a no-op without a navigator, and
// the spec asks for outcome state + service calls instead.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset asset(String id, int size) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class FakeMedia implements MediaService {
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
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size, {int quality = 85}) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

class FakeLocal implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<HistoryRecord> history = <HistoryRecord>[];
  bool failSave = false;

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    if (failSave) {
      return const Failure<void>(AppFailure(messageKey: AppStrings.errorLocal));
    }
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
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
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    trash.addAll(entries);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return Success<List<TrashEntry>>(List<TrashEntry>.of(trash));
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    trash.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    trash.clear();
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

  final Map<String, PhotoAnalysis> _analyses = <String, PhotoAnalysis>{};
  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    for (final PhotoAnalysis a in analyses) {
      _analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(_analyses),
    );
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
}

/// Trash fake: the test decides which ids the "native sheet"
/// confirms, which it denies, and which are unreachable — or fails
/// the whole call.
class FakeTrash implements TrashService {
  FakeTrash({
    this.grantedIds,
    this.deniedIds = const <String>{},
    this.failedIds = const <String>{},
    this.failCall = false,
  });

  final Set<String>? grantedIds;
  final Set<String> deniedIds;
  final Set<String> failedIds;
  final bool failCall;

  List<String> trashCalls = <String>[];

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    trashCalls = ids;
    if (failCall) {
      return const Failure<TrashOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
    final List<String> trashed = <String>[];
    final List<String> denied = <String>[];
    final List<String> failed = <String>[];
    for (final String id in ids) {
      if (failedIds.contains(id)) {
        failed.add(id);
      } else if (deniedIds.contains(id)) {
        denied.add(id);
      } else if (grantedIds == null || grantedIds!.contains(id)) {
        trashed.add(id);
      } else {
        denied.add(id);
      }
    }
    return Success<TrashOutcome>(
      TrashOutcome(trashedIds: trashed, deniedIds: denied, failedIds: failed),
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

ReviewController makeController({
  required FakeLocal local,
  required FakeTrash trash,
  List<MediaAsset>? items,
  String filterKey = 'all',
}) {
  final ReviewController controller = ReviewController(
    media: FakeMedia(),
    trash: trash,
    local: local,
    initialAssets:
        items ?? <MediaAsset>[asset('a', 1000000), asset('b', 2000000)],
    filterKeyOverride: filterKey,
  );
  controller.onInit();
  return controller;
}

void seedSession(FakeLocal local, String filterKey, List<String> deleteIds) {
  local.sessions[filterKey] = DeckSession(
    filterKey: filterKey,
    currentIndex: 0,
    marks: <String, DeckMark>{
      for (final String id in deleteIds) id: DeckMark.delete,
    },
    favouriteIds: <String>{},
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('ReviewController', () {
    test('unmark removes from grid and clears the session mark', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(),
      );
      await controller.unmark(asset('a', 1000000));
      expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
        'b',
      ]);
      expect(local.sessions['all']!.marks.containsKey('a'), isFalse);
      expect(local.sessions['all']!.marks['b'], DeckMark.delete);
    });

    test('unmark keeps the photo in the grid when the save fails', () async {
      final FakeLocal local = FakeLocal()..failSave = true;
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(),
      );
      await controller.unmark(asset('a', 1000000));
      expect(controller.items.length, 2);
      expect(controller.errorKey.value, AppStrings.errorLocal);
    });

    test('keep-all sets keep marks and clears the grid', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(),
      );
      await controller.keepAll();
      expect(controller.items, isEmpty);
      expect(local.sessions['all']!.marks, <String, DeckMark>{
        'a': DeckMark.keep,
        'b': DeckMark.keep,
      });
    });

    test('trash success clears marks, appends history, sets outcome', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(),
      );
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.trashed);
      expect(controller.items, isEmpty);
      expect(local.sessions['all']!.marks, isEmpty);
      expect(local.history.length, 1);
      expect(local.history.single.count, 2);
      expect(local.history.single.mbTrashed, closeTo(2.86, 0.01));
      expect(local.history.single.mbFreed, 0);
      expect(controller.trashedUntil.value, isNotNull);
    });

    test('denied clears marks and reports the denied ids', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(deniedIds: <String>{'a', 'b'}),
      );
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.denied);
      expect(controller.deniedIds, <String>['a', 'b']);
      expect(local.sessions['all']!.marks, isEmpty);
      expect(local.history, isEmpty);
    });

    test('failed keeps marks and sets the error state', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(failedIds: <String>{'a', 'b'}),
      );
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.failed);
      expect(controller.items.length, 2);
      expect(local.sessions['all']!.marks.length, 2);
      expect(controller.errorKey.value, AppStrings.errorTrash);
    });

    test('service failure keeps marks and reports serviceError', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(failCall: true),
      );
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.serviceError);
      expect(controller.items.length, 2);
      expect(controller.errorKey.value, AppStrings.errorTrash);
    });

    test(
      'mixed trashed + denied: denied wins, trashed still recorded',
      () async {
        final FakeLocal local = FakeLocal();
        seedSession(local, 'all', <String>['a', 'b']);
        final ReviewController controller = makeController(
          local: local,
          trash: FakeTrash(deniedIds: <String>{'b'}),
        );
        final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
        expect(outcome, ReviewDeleteOutcome.denied);
        expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
          'b',
        ]);
        expect(local.history.length, 1);
        expect(local.history.single.count, 1);
        expect(local.sessions['all']!.marks, isEmpty);
      },
    );

    test('mixed trashed + failed: failed stays with error state', () async {
      final FakeLocal local = FakeLocal();
      seedSession(local, 'all', <String>['a', 'b']);
      final ReviewController controller = makeController(
        local: local,
        trash: FakeTrash(failedIds: <String>{'b'}),
      );
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.failed);
      expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
        'b',
      ]);
      expect(local.history.length, 1);
      expect(controller.errorKey.value, AppStrings.errorTrash);
    });

    test('header totals track the live set', () {
      final ReviewController controller = makeController(
        local: FakeLocal(),
        trash: FakeTrash(),
      );
      expect(controller.totalBytes, 3000000);
    });
  });
}
