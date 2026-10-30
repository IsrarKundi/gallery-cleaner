// Phase 3B denied-confirmation tests (requirements §5): mixed
// native-sheet outcomes must explain every part of the run, not
// just the winning outcome, and no photo may be silently lost.
// Review: trashed + denied + failed splits. Trash: restore and
// empty splits. Navigation is not asserted (same convention as the
// existing controller tests); outcome state + session/record
// state is.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _asset(String id, int size) {
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

class _Media implements MediaService {
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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  // Stage 4: memberships default to "none stored" in this fake.
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<HistoryRecord> history = <HistoryRecord>[];

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
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    for (final String id in ids) {
      await setSnooze(id, null);
    }
    return const Success<void>(null);
  }

  @override
  Future<void> flushPendingWrites() async {}

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

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
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

class _ReviewTrash implements TrashService {
  _ReviewTrash({
    this.deniedIds = const <String>{},
    this.failedIds = const <String>{},
  });

  final Set<String> deniedIds;
  final Set<String> failedIds;

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    final List<String> deleted = <String>[];
    final List<String> denied = <String>[];
    final List<String> failed = <String>[];
    for (final String id in ids) {
      if (failedIds.contains(id)) {
        failed.add(id);
      } else if (deniedIds.contains(id)) {
        denied.add(id);
      } else {
        deleted.add(id);
      }
    }
    return Success<DeleteOutcome>(
      DeleteOutcome(deletedIds: deleted, deniedIds: denied, failedIds: failed),
    );
  }

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    final List<String> trashed = <String>[];
    final List<String> denied = <String>[];
    final List<String> failed = <String>[];
    for (final String id in ids) {
      if (failedIds.contains(id)) {
        failed.add(id);
      } else if (deniedIds.contains(id)) {
        denied.add(id);
      } else {
        trashed.add(id);
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

ReviewController _review(
  _Local local,
  _ReviewTrash trash,
  List<MediaAsset> items,
) {
  final ReviewController controller = ReviewController(
    media: _Media(),
    trash: trash,
    local: local,
    initialAssets: items,
    filterKeyOverride: 'all',
  );
  controller.onInit();
  return controller;
}

void _seedDeletes(_Local local, List<String> ids) {
  local.sessions['all'] = DeckSession(
    filterKey: 'all',
    currentIndex: 0,
    marks: <String, DeckMark>{for (final String id in ids) id: DeckMark.delete},
    favouriteIds: <String>{},
  );
}

class _TrashFake implements TrashService {
  _TrashFake({this.grantedIds});

  final Set<String>? grantedIds;
  final List<TrashEntry> records = <TrashEntry>[];

  List<String> _confirm(List<String> ids) {
    if (grantedIds == null) {
      return ids;
    }
    return ids.where(grantedIds!.contains).toList();
  }

  TrashEntry _entry(String id, int size) {
    return TrashEntry(
      assetId: id,
      typeInt: 1,
      width: 10,
      height: 10,
      sizeBytes: size,
      trashedAt: DateTime(2026, 10, 20),
    );
  }

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    final List<String> deleted = _confirm(ids);
    final List<String> denied = ids
        .where((String id) => !deleted.contains(id))
        .toList();
    return Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: deleted,
        deniedIds: denied,
        failedIds: const <String>[],
      ),
    );
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
    final Set<String> known = records.map((TrashEntry e) => e.assetId).toSet();
    final List<String> matched = ids.where(known.contains).toList();
    final List<String> failed = ids.where((id) => !known.contains(id)).toList();
    final List<String> restored = _confirm(matched);
    final List<String> denied = matched
        .where((String id) => !restored.contains(id))
        .toList();
    records.removeWhere((TrashEntry e) => restored.contains(e.assetId));
    return Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: restored,
        deniedIds: denied,
        failedIds: failed,
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    final List<TrashEntry> sorted = List<TrashEntry>.of(
      records,
    )..sort((TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt));
    return Success<List<TrashEntry>>(sorted);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    final List<String> ids = records.map((TrashEntry e) => e.assetId).toList();
    final List<String> removed = _confirm(ids);
    final List<String> denied = ids
        .where((String id) => !removed.contains(id))
        .toList();
    records.removeWhere((TrashEntry e) => removed.contains(e.assetId));
    return Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: removed,
        deniedIds: denied,
        failedIds: <String>[],
      ),
    );
  }
}

TrashController _trash(_TrashFake trash, _Local local) {
  final TrashController controller = TrashController(
    trash: trash,
    local: local,
  );
  // init() is public (the retry entry point); calling it directly
  // avoids racing onInit's fire-and-forget load in tests.
  return controller;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  test('review trashed + denied + failed: counts explain the split', () async {
    final _Local local = _Local();
    _seedDeletes(local, <String>['a', 'b', 'c']);
    final ReviewController controller = _review(
      local,
      _ReviewTrash(deniedIds: <String>{'b'}, failedIds: <String>{'c'}),
      <MediaAsset>[_asset('a', 1000), _asset('b', 2000), _asset('c', 3000)],
    );
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.denied);
    expect(controller.lastTrashedCount.value, 1);
    expect(controller.lastFailedCount.value, 1);
    expect(controller.deniedIds.toList(), <String>['b']);
    // Failed item stays in the grid and trashed leaves it. The
    // denied item stays in this controller's grid (its session
    // mark is cleared, so the deck re-shows it undecided — the
    // view navigates there after the dialog, it does not stay
    // on this screen).
    expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
      'b',
      'c',
    ]);
    final DeckSession? session = local.sessions['all'];
    expect(session?.marks.containsKey('a'), isFalse);
    expect(session?.marks.containsKey('b'), isFalse);
    expect(session?.marks['c'], DeckMark.delete);
    // One history record for the deleted part, freed immediately.
    expect(local.history.length, 1);
    expect(local.history.first.count, 1);
    expect(local.history.first.mbFreed, greaterThan(0));
    expect(local.history.first.mbTrashed, 0);
  });

  test('review trashed + failed (no denial): failed outcome + count', () async {
    final _Local local = _Local();
    _seedDeletes(local, <String>['a', 'b']);
    final ReviewController controller = _review(
      local,
      _ReviewTrash(failedIds: <String>{'b'}),
      <MediaAsset>[_asset('a', 1000), _asset('b', 2000)],
    );
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.failed);
    expect(controller.lastTrashedCount.value, 1);
    expect(controller.lastFailedCount.value, 1);
    expect(controller.errorKey.value, AppStrings.errorTrash);
    expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
      'b',
    ]);
  });

  test('review pure denial: counts stay zero', () async {
    final _Local local = _Local();
    _seedDeletes(local, <String>['a']);
    final ReviewController controller = _review(
      local,
      _ReviewTrash(deniedIds: <String>{'a'}),
      <MediaAsset>[_asset('a', 1000)],
    );
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.denied);
    expect(controller.lastTrashedCount.value, 0);
    expect(controller.lastFailedCount.value, 0);
    expect(local.sessions['all']?.marks.containsKey('a'), isFalse);
  });

  test('trash restore mixed: restored counted, denied stays', () async {
    final _Local local = _Local();
    final _TrashFake trash = _TrashFake(grantedIds: <String>{'r1'});
    trash.records.addAll(<TrashEntry>[
      trash._entry('r1', 1000),
      trash._entry('r2', 2000),
    ]);
    final TrashController controller = _trash(trash, local);
    await controller.init();
    final TrashActionOutcome? outcome = await controller.restore(<String>[
      'r1',
      'r2',
    ]);
    expect(outcome, TrashActionOutcome.denied);
    expect(controller.lastRestoredCount.value, 1);
    expect(
      controller.entries.map((TrashEntry e) => e.assetId).toList(),
      <String>['r2'],
    );
  });

  test('trash restore denied + failed: failure is not hidden', () async {
    final _Local local = _Local();
    final _TrashFake trash = _TrashFake(grantedIds: <String>{});
    trash.records.add(trash._entry('r1', 1000));
    final TrashController controller = _trash(trash, local);
    await controller.init();
    final TrashActionOutcome? outcome = await controller.restore(<String>[
      'r1',
      'missing',
    ]);
    expect(outcome, TrashActionOutcome.denied);
    expect(controller.lastFailedCount.value, 1);
    expect(controller.errorKey.value, AppStrings.errorTrash);
    expect(
      controller.entries.map((TrashEntry e) => e.assetId).toList(),
      <String>['r1'],
    );
  });

  test('trash empty mixed: freed bytes counted, denied stays', () async {
    final _Local local = _Local();
    final _TrashFake trash = _TrashFake(grantedIds: <String>{'e1'});
    trash.records.addAll(<TrashEntry>[
      trash._entry('e1', 1000),
      trash._entry('e2', 2000),
    ]);
    final TrashController controller = _trash(trash, local);
    await controller.init();
    final TrashActionOutcome? outcome = await controller.emptyTrash();
    expect(outcome, TrashActionOutcome.denied);
    expect(controller.lastFreedBytes.value, 1000);
    expect(
      controller.entries.map((TrashEntry e) => e.assetId).toList(),
      <String>['e2'],
    );
    expect(local.history.length, 1);
    expect(local.history.first.mbFreed, greaterThan(0));
  });
}
