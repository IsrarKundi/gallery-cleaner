// Document guard at Review (requirements §7, Phase 4): a delete
// run containing document-like items stops BEFORE the native
// sheet, with the guarded items pending; the user's explicit
// override (delete anyway) or keep choice then stands. A run
// with no document-like items proceeds straight to the sheet.
// The guard never deletes: keeping only unmarks.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset shot(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Screenshots',
  );
}

MediaAsset plain(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 2000000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

class FakeMedia implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);
  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);
  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);
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
  }) async => const Success<List<MediaAsset>>(<MediaAsset>[]);
  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class FakeLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<HistoryRecord> history = <HistoryRecord>[];

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      Success<DeckSession?>(sessions[filterKey]);
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
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    for (final String id in ids) {
      await setSnooze(id, null);
    }
    return const Success<void>(null);
  }

  @override
  Future<void> flushPendingWrites() async {}
  @override
  Future<Result<double>> loadGoalTargetMb() async =>
      const Success<double>(1024);
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
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);
  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);
  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);
  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);
  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    history.add(record);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      Success<List<HistoryRecord>>(List<HistoryRecord>.of(history));
  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);
  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);
  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);
  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());
  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);
}

class FakeTrash implements TrashService {
  List<String> trashCalls = <String>[];

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    trashCalls = ids;
    return Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: ids,
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async =>
      const Success<RestoreOutcome>(
        RestoreOutcome(
          restoredIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );
  @override
  Future<Result<List<TrashEntry>>> listTrashed() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);
  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async =>
      const Success<EmptyTrashOutcome>(
        EmptyTrashOutcome(
          removedIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );
}

ReviewController makeController(
  FakeLocal local,
  FakeTrash trash,
  List<MediaAsset> items,
) {
  final ReviewController controller = ReviewController(
    media: FakeMedia(),
    trash: trash,
    local: local,
    initialAssets: items,
    filterKeyOverride: 'all',
  );
  controller.onInit();
  return controller;
}

void main() {
  test('guarded run stops before the native sheet', () async {
    final FakeLocal local = FakeLocal();
    local.sessions['all'] = const DeckSession(
      filterKey: 'all',
      currentIndex: 0,
      marks: <String, DeckMark>{'s1': DeckMark.delete, 'p1': DeckMark.delete},
      favouriteIds: <String>{},
    );
    final FakeTrash trash = FakeTrash();
    final ReviewController controller = makeController(
      local,
      trash,
      <MediaAsset>[shot('s1'), plain('p1')],
    );
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.documentGuard);
    // The native sheet never appeared: no trash call at all.
    expect(trash.trashCalls, isEmpty);
    expect(
      controller.documentGuardPending.map((MediaAsset a) => a.id).toList(),
      <String>['s1'],
    );
    expect(controller.items.length, 2);
  });

  test('explicit override proceeds to the native sheet', () async {
    final FakeLocal local = FakeLocal();
    local.sessions['all'] = const DeckSession(
      filterKey: 'all',
      currentIndex: 0,
      marks: <String, DeckMark>{'s1': DeckMark.delete, 'p1': DeckMark.delete},
      favouriteIds: <String>{},
    );
    final FakeTrash trash = FakeTrash();
    final ReviewController controller = makeController(
      local,
      trash,
      <MediaAsset>[shot('s1'), plain('p1')],
    );
    await controller.deleteSelected();
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected(
      overrideDocumentGuard: true,
    );
    expect(outcome, ReviewDeleteOutcome.trashed);
    expect(trash.trashCalls, <String>['s1', 'p1']);
    expect(controller.items, isEmpty);
  });

  test('keeping guarded items unmarks only them', () async {
    final FakeLocal local = FakeLocal();
    local.sessions['all'] = const DeckSession(
      filterKey: 'all',
      currentIndex: 0,
      marks: <String, DeckMark>{'s1': DeckMark.delete, 'p1': DeckMark.delete},
      favouriteIds: <String>{},
    );
    final FakeTrash trash = FakeTrash();
    final ReviewController controller = makeController(
      local,
      trash,
      <MediaAsset>[shot('s1'), plain('p1')],
    );
    await controller.deleteSelected();
    await controller.keepDocumentGuarded();
    expect(controller.documentGuardKeptCount.value, 1);
    expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
      'p1',
    ]);
    expect(local.sessions['all']!.marks.containsKey('s1'), isFalse);
    expect(local.sessions['all']!.marks['p1'], DeckMark.delete);
    expect(trash.trashCalls, isEmpty);
  });

  test('unguarded run goes straight to the sheet', () async {
    final FakeLocal local = FakeLocal();
    local.sessions['all'] = const DeckSession(
      filterKey: 'all',
      currentIndex: 0,
      marks: <String, DeckMark>{'p1': DeckMark.delete},
      favouriteIds: <String>{},
    );
    final FakeTrash trash = FakeTrash();
    final ReviewController controller = makeController(
      local,
      trash,
      <MediaAsset>[plain('p1')],
    );
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.trashed);
    expect(trash.trashCalls, <String>['p1']);
  });
}
