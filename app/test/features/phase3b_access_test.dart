// Phase 3B partial-access + denied-state tests (requirements §5):
// DeckAccess logic (expand / settings / rewind / undo) and the
// deck view's partial banner actions + denied secondary action.
// photo_manager cannot run on this host, so the fake stands in for
// the system picker / Settings page: the test proves the app-side
// flow (call -> re-check -> reload), not the platform sheet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_access.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/deck/view/deck_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

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

class _Media implements MediaService {
  _Media({
    this.permission = MediaPermission.grantedLimited,
    this.flipToFullOnPresent = false,
  });

  MediaPermission permission;
  final bool flipToFullOnPresent;
  bool presentCalled = false;
  bool settingsCalled = false;

  @override
  Future<Result<void>> presentLimitedSelection() async {
    presentCalled = true;
    if (flipToFullOnPresent) {
      permission = MediaPermission.grantedFull;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    settingsCalled = true;
    return const Success<void>(null);
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return Success<MediaPermission>(permission);
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
    return Success<List<MediaAsset>>(<MediaAsset>[_asset('a1'), _asset('a2')]);
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
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Trash implements TrashService {
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

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    return const Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
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
  bool tutorialSeen = true;

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
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return Success<bool>(tutorialSeen);
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

Future<DeckController> _pumpDeck(
  WidgetTester tester, {
  required _Media media,
}) async {
  final DeckController controller = DeckController(
    media: media,
    trash: _Trash(),
    local: _Local(),
  );
  Get.put<DeckController>(controller);
  await tester.pumpWidget(
    GetMaterialApp(theme: AppTheme.light, home: const DeckView()),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  tearDown(Get.reset);

  group('DeckAccess', () {
    test('expand returns the post-picker permission state', () async {
      final _Media media = _Media();
      final DeckAccess access = DeckAccess(media: media);
      final MediaPermission? after = await access.expandPartialAccess();
      expect(media.presentCalled, isTrue);
      expect(after, MediaPermission.grantedLimited);
    });

    test('expand reports full when the picker grant flips to full', () async {
      final _Media media = _Media(flipToFullOnPresent: true);
      final DeckAccess access = DeckAccess(media: media);
      expect(await access.expandPartialAccess(), MediaPermission.grantedFull);
    });

    test('openPermissionSettings calls the media service', () async {
      final _Media media = _Media();
      await DeckAccess(media: media).openPermissionSettings();
      expect(media.settingsCalled, isTrue);
    });

    test('rewindDenied clears only delete marks', () {
      final RxMap<String, DeckMark> marks = <String, DeckMark>{
        'a': DeckMark.delete,
        'b': DeckMark.keep,
        'c': DeckMark.delete,
      }.obs;
      final RxList<String> undoStack = <String>['a', 'b', 'c'].obs;
      final bool changed = DeckAccess(media: _Media())
          .rewindDenied(marks, undoStack, <String>['a', 'b', 'missing']);
      expect(changed, isTrue);
      expect(marks.containsKey('a'), isFalse);
      expect(marks['b'], DeckMark.keep);
      expect(marks['c'], DeckMark.delete);
      expect(undoStack.toList(), <String>['b', 'c']);
    });

    test('undo returns the queue index, -1 when gone, null when empty', () {
      final DeckAccess access = DeckAccess(media: _Media());
      final RxMap<String, DeckMark> marks = <String, DeckMark>{
        'a': DeckMark.favourite,
      }.obs;
      final RxSet<String> favourites = <String>{'a'}.obs;
      final RxList<String> stack = <String>['a'].obs;
      expect(
        access.undo(marks, favourites, stack, <MediaAsset>[_asset('a')]),
        0,
      );
      expect(marks.containsKey('a'), isFalse);
      expect(favourites.contains('a'), isFalse);
      expect(access.undo(marks, favourites, stack, <MediaAsset>[]), null);
      final RxList<String> stack2 = <String>['gone'].obs;
      final RxMap<String, DeckMark> marks2 = <String, DeckMark>{
        'gone': DeckMark.keep,
      }.obs;
      expect(
        access.undo(marks2, favourites, stack2, <MediaAsset>[_asset('a')]),
        -1,
      );
    });
  });

  group('deck view partial + denied actions', () {
    testWidgets('Add more photos reloads and clears the banner on full', (
      WidgetTester tester,
    ) async {
      final _Media media = _Media(flipToFullOnPresent: true);
      final DeckController controller = await _pumpDeck(tester, media: media);
      expect(controller.isPartialAccess, isTrue);
      expect(
        find.text(AppStrings.tr(AppStrings.permissionPartialTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionPartialAddMore)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionOpenSettings)),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.permissionPartialAddMore)),
      );
      await tester.pumpAndSettle();
      expect(media.presentCalled, isTrue);
      expect(controller.isPartialAccess, isFalse);
      expect(
        find.text(AppStrings.tr(AppStrings.permissionPartialTitle)),
        findsNothing,
      );
    });

    testWidgets('denied state offers Open settings as a second action', (
      WidgetTester tester,
    ) async {
      final _Media media = _Media(permission: MediaPermission.denied);
      await _pumpDeck(tester, media: media);
      expect(
        find.text(AppStrings.tr(AppStrings.permissionDeniedTitle)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionAllowAccess)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.tr(AppStrings.permissionOpenSettings)),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppStrings.tr(AppStrings.permissionOpenSettings)),
      );
      await tester.pumpAndSettle();
      expect(media.settingsCalled, isTrue);
    });
  });
}
