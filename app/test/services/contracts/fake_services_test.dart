// Interface-contract tests plus [TrashServiceImpl] outcome tests.
//
// The fakes below stand in for the platform: real photo_manager
// calls cannot run on this host (no device, no MediaStore), so the
// native sheet, real trash/restore and real media access are
// owner-verified on a phone, not claimed here. What IS tested here
// is the logic that must hold regardless of platform: the
// trashed/denied/failed split, the API 30+ gate, and the rule that
// a denied photo is reported back, never silently dropped.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_gateway_impl.dart';
import 'package:klara/services/trash/trash_service.dart';
import 'package:klara/services/trash/trash_service_impl.dart';
import 'package:photo_manager/photo_manager.dart';

/// In-memory [LocalService] for contract and trash tests.
class FakeLocalService implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final List<TrashEntry> trash = <TrashEntry>[];
  final List<HistoryRecord> history = <HistoryRecord>[];
  bool tutorialSeen = false;

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
    final List<TrashEntry> entries = List<TrashEntry>.of(trash);
    entries.sort(
      (TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt),
    );
    return Success<List<TrashEntry>>(entries);
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
    final List<HistoryRecord> records = List<HistoryRecord>.of(history);
    records.sort(
      (HistoryRecord a, HistoryRecord b) => b.date.compareTo(a.date),
    );
    return Success<List<HistoryRecord>>(records);
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

/// Configurable [TrashGateway] fake: the test decides which ids the
/// "native sheet" confirms, which ids are unresolvable, and the SDK.
class FakeTrashGateway implements TrashGateway {
  FakeTrashGateway({
    this.sdk = 34,
    this.missingIds = const <String>{},
    this.grantedIds,
  });

  final int sdk;
  final Set<String> missingIds;

  /// If null, every presented id is granted; otherwise only these.
  final Set<String>? grantedIds;

  List<String> _confirm(List<AssetEntity> entities) {
    final Set<String> granted =
        grantedIds ?? entities.map((AssetEntity e) => e.id).toSet();
    return entities
        .map((AssetEntity e) => e.id)
        .where(granted.contains)
        .toList();
  }

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<ResolvedAssets> resolveAssets(List<String> ids) async {
    final List<AssetEntity> found = <AssetEntity>[];
    final List<String> missing = <String>[];
    for (final String id in ids) {
      if (missingIds.contains(id)) {
        missing.add(id);
      } else {
        found.add(AssetEntity(id: id, typeInt: 1, width: 10, height: 10));
      }
    }
    return (found: found, missing: missing);
  }

  @override
  Future<int> assetSize(AssetEntity entity) async => 1000;

  @override
  Future<List<String>> moveToTrash(List<AssetEntity> entities) async {
    return _confirm(entities);
  }

  @override
  Future<List<String>> restoreFromTrash(List<AssetEntity> entities) async {
    return _confirm(entities);
  }

  @override
  Future<List<String>> deleteIds(List<AssetEntity> entities) async {
    return _confirm(entities);
  }
}

/// Minimal [MediaService] fake with success and failure modes.
class FakeMediaService implements MediaService {
  FakeMediaService({this.fail = false});

  final bool fail;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    if (fail) {
      return const Failure<MediaPermission>(
        AppFailure(messageKey: AppStrings.errorMediaPermission),
      );
    }
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    if (fail) {
      return const Failure<List<MediaAlbum>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 3),
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
    if (fail) {
      return const Failure<List<MediaAsset>>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return Success<List<MediaAsset>>(<MediaAsset>[
      MediaAsset(
        id: '1',
        type: MediaAssetType.image,
        width: 10,
        height: 10,
        sizeBytes: 100,
        createDate: DateTime(2026, 10, 25),
        title: 'a.jpg',
        albumName: 'Recent',
      ),
    ]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    if (fail) {
      return const Failure<Uint8List>(
        AppFailure(messageKey: AppStrings.errorMediaLoad),
      );
    }
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

void main() {
  group('MediaService contract (fake)', () {
    test('success path returns permission, albums and assets', () async {
      final MediaService service = FakeMediaService();
      expect(
        (await service.requestPermission()).fold(
          onSuccess: (MediaPermission value) => value,
          onFailure: (_) => MediaPermission.denied,
        ),
        MediaPermission.grantedFull,
      );
      expect(
        (await service.getAlbums()).fold(
          onSuccess: (List<MediaAlbum> value) => value.length,
          onFailure: (_) => -1,
        ),
        1,
      );
      expect(
        (await service.getAssets()).fold(
          onSuccess: (List<MediaAsset> value) => value.length,
          onFailure: (_) => -1,
        ),
        1,
      );
    });

    test('failure path carries string keys, never exception text', () async {
      final MediaService service = FakeMediaService(fail: true);
      final Result<MediaPermission> result = await service.requestPermission();
      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => '',
          onFailure: (AppFailure f) => f.messageKey,
        ),
        AppStrings.errorMediaPermission,
      );
    });
  });

  group('TrashServiceImpl outcome partitioning', () {
    test('granted ids trash, ungranted ids are denied, missing fail', () async {
      final FakeLocalService local = FakeLocalService();
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(
          missingIds: <String>{'gone'},
          grantedIds: <String>{'a'},
        ),
        local: local,
      );
      final Result<TrashOutcome> result = await service.trashAssets(<String>[
        'a',
        'b',
        'gone',
      ]);
      expect(result.isSuccess, isTrue);
      final TrashOutcome outcome = result.fold(
        onSuccess: (TrashOutcome value) => value,
        onFailure: (_) => throw StateError('expected success'),
      );
      expect(outcome.trashedIds, <String>['a']);
      // 'b' was denied at the sheet: reported, never dropped.
      expect(outcome.deniedIds, <String>['b']);
      expect(outcome.failedIds, <String>['gone']);
      // Only the trashed id is recorded for the Trash screen.
      expect(local.trash.map((TrashEntry e) => e.assetId).toList(), <String>[
        'a',
      ]);
    });

    test('empty input succeeds with an empty outcome', () async {
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(),
        local: FakeLocalService(),
      );
      final Result<TrashOutcome> result = await service.trashAssets(<String>[]);
      expect(result.isSuccess, isTrue);
      expect(
        result.fold(
          onSuccess: (TrashOutcome value) => value.trashedIds,
          onFailure: (_) => <String>['x'],
        ),
        isEmpty,
      );
    });

    test('below API 30 trash fails as unsupported, never silently', () async {
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(sdk: 29),
        local: FakeLocalService(),
      );
      final Result<TrashOutcome> result = await service.trashAssets(<String>[
        'a',
      ]);
      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => '',
          onFailure: (AppFailure f) => f.messageKey,
        ),
        AppStrings.errorTrashUnsupported,
      );
    });

    test('restore removes restored ids and reports denied ids', () async {
      final FakeLocalService local = FakeLocalService();
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(grantedIds: <String>{'a'}),
        local: local,
      );
      await local.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: 'a',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          trashedAt: DateTime(2026, 10, 25),
        ),
        TrashEntry(
          assetId: 'b',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          trashedAt: DateTime(2026, 10, 25),
        ),
      ]);
      final Result<RestoreOutcome> result = await service.restoreAssets(
        <String>['a', 'b', 'ghost'],
      );
      expect(result.isSuccess, isTrue);
      final RestoreOutcome outcome = result.fold(
        onSuccess: (RestoreOutcome value) => value,
        onFailure: (_) => throw StateError('expected success'),
      );
      expect(outcome.restoredIds, <String>['a']);
      expect(outcome.deniedIds, <String>['b']);
      expect(outcome.failedIds, <String>['ghost']);
      expect(local.trash.map((TrashEntry e) => e.assetId).toList(), <String>[
        'b',
      ]);
    });

    test('emptyTrash removes only confirmed ids; denied stay', () async {
      final FakeLocalService local = FakeLocalService();
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(grantedIds: <String>{'a'}),
        local: local,
      );
      await local.recordTrashed(<TrashEntry>[
        TrashEntry(
          assetId: 'a',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          trashedAt: DateTime(2026, 10, 25),
        ),
        TrashEntry(
          assetId: 'b',
          typeInt: 1,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          trashedAt: DateTime(2026, 10, 25),
        ),
      ]);
      final Result<EmptyTrashOutcome> result = await service.emptyTrash();
      expect(result.isSuccess, isTrue);
      final EmptyTrashOutcome outcome = result.fold(
        onSuccess: (EmptyTrashOutcome value) => value,
        onFailure: (_) => throw StateError('expected success'),
      );
      expect(outcome.removedIds, <String>['a']);
      expect(outcome.deniedIds, <String>['b']);
      expect(local.trash.map((TrashEntry e) => e.assetId).toList(), <String>[
        'b',
      ]);
    });

    test('emptyTrash below API 30 fails as unsupported', () async {
      final TrashService service = TrashServiceImpl(
        gateway: FakeTrashGateway(sdk: 28),
        local: FakeLocalService(),
      );
      final Result<EmptyTrashOutcome> result = await service.emptyTrash();
      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => '',
          onFailure: (AppFailure f) => f.messageKey,
        ),
        AppStrings.errorTrashUnsupported,
      );
    });
  });
}
