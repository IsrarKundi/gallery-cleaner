// Golden-path widget test (requirements §4, §7 / AGENTS.md tests):
// splash -> deck -> mark delete (button path) -> review -> trash
// (fake native-confirmation success) -> restore -> trash empty ->
// history shows the trashed record.
//
// This is the host-runnable twin of integration_test/
// golden_path_test.dart, which drives the same flow on a real
// device. Real platform channels cannot run here (no device, no
// MediaStore), so both files run against the same fake services:
// the fake TrashService simulates native-confirmation success, the
// way the contract tests simulate denial. What this proves is the
// full app wiring (routes, bindings, controllers, views, session
// and history writes); the real native sheet, real trash/restore
// and back-gesture behaviour are the owner's on-device checks.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/constants/app_icons.dart';
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/widgets/swipe_card.dart';
import 'package:klara/features/splash/view/splash_view.dart';
import 'package:klara/main.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// A valid 1x1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id, int sizeBytes) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: sizeBytes,
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

  final List<MediaAsset> assets = <MediaAsset>[
    _asset('a1', 1000000),
    _asset('a2', 2000000),
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
    return Success<List<MediaAsset>>(assets);
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
    return Success<List<MediaAsset>>(
      assets.where((MediaAsset a) => ids.contains(a.id)).toList(),
    );
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<HistoryRecord> history = <HistoryRecord>[];

  /// Seen, so the first-run tutorial never overlays this flow.
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
    return Success<bool>(tutorialSeen);
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
    tutorialSeen = seen;
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

/// Fake TrashService simulating native-confirmation SUCCESS for
/// every id (the denied split is covered by the contract tests).
/// It mirrors the real service's record keeping via [_Local].
class _Trash implements TrashService {
  _Trash(this.local, this.sizes);

  final _Local local;
  final Map<String, int> sizes;
  final List<TrashEntry> entries = <TrashEntry>[];

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    final DateTime now = DateTime.now();
    final List<TrashEntry> made = <TrashEntry>[
      for (final String id in ids)
        TrashEntry(
          assetId: id,
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: sizes[id] ?? 0,
          trashedAt: now,
        ),
    ];
    entries.addAll(made);
    await local.recordTrashed(made);
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
    entries.removeWhere((TrashEntry e) => ids.contains(e.assetId));
    await local.removeTrashEntries(ids);
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
    final List<TrashEntry> sorted = List<TrashEntry>.of(
      entries,
    )..sort((TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt));
    return Success<List<TrashEntry>>(sorted);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    final List<String> removed = entries
        .map((TrashEntry e) => e.assetId)
        .toList();
    entries.clear();
    await local.clearTrashEntries();
    return Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: removed,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }
}

class _FakeBinding extends Bindings {
  _FakeBinding(this.local, this.trash);

  final _Local local;
  final _Trash trash;

  @override
  void dependencies() {
    Get.put<LocalService>(local, permanent: true);
    Get.put<MediaService>(_Media(), permanent: true);
    Get.put<TrashService>(trash, permanent: true);
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets('golden path: mark -> review -> trash -> restore', (
    WidgetTester tester,
  ) async {
    final _Local local = _Local();
    final _Trash trash = _Trash(local, <String, int>{
      'a1': 1000000,
      'a2': 2000000,
    });

    // Reduced motion so splash renders the static logo, not Lottie.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: KlaraApp(initialBinding: _FakeBinding(local, trash)),
      ),
    );
    await tester.pumpAndSettle();

    // Splash completes on tap (hold timer is the fallback only).
    await tester.tap(find.byType(SplashView));
    await tester.pumpAndSettle();

    // Deck loads the fake assets; SwipeCard and actions are present.
    expect(find.byType(SwipeCard), findsOneWidget);
    expect(find.byIcon(AppIcons.undo), findsOneWidget);

    // Mark one asset delete via swipe right (gesture path).
    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pumpAndSettle();

    // Review tab (Trash) in bottom nav opens the review screen.
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 photos'), findsOneWidget);

    // Confirm trash (fake native-confirmation success).
    await tester.tap(find.text('Delete 1 photos'));
    await tester.pumpAndSettle();

    // Trash lists the entry with its recoverable-until date.
    expect(find.textContaining('Recoverable until'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);

    // Restore it: the list empties and the restored snackbar shows.
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.tr(AppStrings.trashEmptyTitle)),
      findsOneWidget,
    );
    expect(trash.entries, isEmpty);

    // History shows the trashed record — trashed MB, freed 0
    // (never counted as freed while the photo sat in Trash).
    Get.offAllNamed<dynamic>(AppRoutes.history);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 photos'), findsOneWidget);
    expect(local.history.length, 1);
    expect(local.history.single.count, 1);
    expect(local.history.single.mbFreed, 0);
  });
}
