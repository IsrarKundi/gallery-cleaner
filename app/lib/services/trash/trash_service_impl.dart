// [TrashService] implementation over [TrashGateway] + [LocalService].
//
// Every destructive step goes through the platform gateway, which
// routes through MediaStore's native confirmation sheet (see
// trash_gateway_impl.dart for the package-source proof). Denial is
// never silent: ids the sheet did not confirm come back as
// [TrashOutcome.deniedIds] so the caller returns them to the deck
// with an explanation (requirements §5).
//
// Trash record: trashed ids are recorded in [LocalService] at trash
// time, because Android hides trashed assets from MediaStore queries
// and the Trash screen could not list them otherwise. An in-session
// mirror ([_known]) is merged into [listTrashed] so a failed local
// write never loses a record while the app runs; the local file is
// the cross-restart record. No auto-delete, no purge job: expiry is
// the system's 30-day job (requirements §4).

import 'package:photo_manager/photo_manager.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../local/local_service.dart';
import 'trash_entry.dart';
import 'trash_gateway_impl.dart';
import 'trash_service.dart';

class TrashServiceImpl implements TrashService {
  TrashServiceImpl({required this._gateway, required this._local});

  final TrashGateway _gateway;
  final LocalService _local;

  /// Entries trashed during this run, merged into [listTrashed].
  final List<TrashEntry> _known = <TrashEntry>[];

  /// Fails when the device cannot show the native sheet path:
  /// trash, restore and sheet-gated emptying all need API 30+.
  /// Failing here is what keeps emptying from ever falling back
  /// to a silent delete on older Android versions.
  Future<Result<void>> _requireApi30() async {
    try {
      final int sdk = await _gateway.sdkInt();
      if (sdk < 30) {
        return const Failure<void>(
          AppFailure(messageKey: AppStrings.errorTrashUnsupported),
        );
      }
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(AppFailure(messageKey: AppStrings.errorTrash));
    }
  }

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    if (ids.isEmpty) {
      return const Success<TrashOutcome>(
        TrashOutcome(
          trashedIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );
    }
    final Result<void> gate = await _requireApi30();
    if (gate.isFailure) {
      return Failure<TrashOutcome>((gate as Failure<void>).failure);
    }
    try {
      final ResolvedAssets resolved = await _gateway.resolveAssets(ids);
      final List<String> failed = resolved.missing;
      final Map<String, int> sizes = <String, int>{};
      for (final AssetEntity entity in resolved.found) {
        try {
          sizes[entity.id] = await _gateway.assetSize(entity);
        } catch (_) {
          sizes[entity.id] = 0;
        }
      }
      // The native sheet: returned ids were confirmed, the rest
      // were denied by the user (cancel counts as denial, not error).
      final List<String> granted = await _gateway.moveToTrash(resolved.found);
      final Set<String> grantedSet = granted.toSet();
      final List<String> trashed = <String>[];
      final List<String> denied = <String>[];
      for (final AssetEntity entity in resolved.found) {
        if (grantedSet.contains(entity.id)) {
          trashed.add(entity.id);
        } else {
          denied.add(entity.id);
        }
      }
      final DateTime now = DateTime.now();
      final List<TrashEntry> entries = <TrashEntry>[];
      for (final AssetEntity entity in resolved.found) {
        if (!grantedSet.contains(entity.id)) {
          continue;
        }
        entries.add(
          TrashEntry(
            assetId: entity.id,
            typeInt: entity.typeInt,
            width: entity.width,
            height: entity.height,
            sizeBytes: sizes[entity.id] ?? 0,
            trashedAt: now,
          ),
        );
      }
      _known.addAll(entries);
      // Best effort: the in-session mirror above keeps the record
      // even if this write fails; the file is the restart record.
      await _local.recordTrashed(entries);
      return Success<TrashOutcome>(
        TrashOutcome(trashedIds: trashed, deniedIds: denied, failedIds: failed),
      );
    } catch (_) {
      return const Failure<TrashOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    if (ids.isEmpty) {
      return const Success<RestoreOutcome>(
        RestoreOutcome(
          restoredIds: <String>[],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      );
    }
    final Result<void> gate = await _requireApi30();
    if (gate.isFailure) {
      return Failure<RestoreOutcome>((gate as Failure<void>).failure);
    }
    try {
      final Result<List<TrashEntry>> listed = await listTrashed();
      if (listed.isFailure) {
        return Failure<RestoreOutcome>(
          (listed as Failure<List<TrashEntry>>).failure,
        );
      }
      final List<TrashEntry> entries = listed.fold(
        onSuccess: (List<TrashEntry> value) => value,
        onFailure: (_) => <TrashEntry>[],
      );
      final Map<String, TrashEntry> byId = <String, TrashEntry>{
        for (final TrashEntry entry in entries) entry.assetId: entry,
      };
      final List<TrashEntry> matched = <TrashEntry>[];
      final List<String> failed = <String>[];
      for (final String id in ids) {
        final TrashEntry? entry = byId[id];
        if (entry == null) {
          failed.add(id);
        } else {
          matched.add(entry);
        }
      }
      final List<AssetEntity> entities = <AssetEntity>[
        for (final TrashEntry entry in matched)
          AssetEntity(
            id: entry.assetId,
            typeInt: entry.typeInt,
            width: entry.width,
            height: entry.height,
          ),
      ];
      final List<String> granted = await _gateway.restoreFromTrash(entities);
      final Set<String> grantedSet = granted.toSet();
      final List<String> restored = <String>[];
      final List<String> denied = <String>[];
      for (final TrashEntry entry in matched) {
        if (grantedSet.contains(entry.assetId)) {
          restored.add(entry.assetId);
        } else {
          denied.add(entry.assetId);
        }
      }
      _known.removeWhere((TrashEntry e) => restored.contains(e.assetId));
      await _local.removeTrashEntries(restored);
      return Success<RestoreOutcome>(
        RestoreOutcome(
          restoredIds: restored,
          deniedIds: denied,
          failedIds: failed,
        ),
      );
    } catch (_) {
      return const Failure<RestoreOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    try {
      final Result<List<TrashEntry>> stored = await _local.loadTrashEntries();
      if (stored.isFailure) {
        return stored;
      }
      final List<TrashEntry> entries = stored.fold(
        onSuccess: (List<TrashEntry> value) => value,
        onFailure: (_) => <TrashEntry>[],
      );
      final Set<String> seen = <String>{
        for (final TrashEntry entry in entries) entry.assetId,
      };
      for (final TrashEntry entry in _known) {
        if (!seen.contains(entry.assetId)) {
          entries.add(entry);
          seen.add(entry.assetId);
        }
      }
      entries.sort(
        (TrashEntry a, TrashEntry b) => b.trashedAt.compareTo(a.trashedAt),
      );
      return Success<List<TrashEntry>>(entries);
    } catch (_) {
      return const Failure<List<TrashEntry>>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    final Result<void> gate = await _requireApi30();
    if (gate.isFailure) {
      return Failure<EmptyTrashOutcome>((gate as Failure<void>).failure);
    }
    try {
      final Result<List<TrashEntry>> listed = await listTrashed();
      if (listed.isFailure) {
        return Failure<EmptyTrashOutcome>(
          (listed as Failure<List<TrashEntry>>).failure,
        );
      }
      final List<TrashEntry> entries = listed.fold(
        onSuccess: (List<TrashEntry> value) => value,
        onFailure: (_) => <TrashEntry>[],
      );
      if (entries.isEmpty) {
        return const Success<EmptyTrashOutcome>(
          EmptyTrashOutcome(
            removedIds: <String>[],
            deniedIds: <String>[],
            failedIds: <String>[],
          ),
        );
      }
      final List<AssetEntity> entities = <AssetEntity>[
        for (final TrashEntry entry in entries)
          AssetEntity(
            id: entry.assetId,
            typeInt: entry.typeInt,
            width: entry.width,
            height: entry.height,
          ),
      ];
      // Native sheet on API 30+ (createDeleteRequest): returned ids
      // were confirmed for removal, the rest stay in Trash.
      final List<String> granted = await _gateway.deleteIds(entities);
      final Set<String> grantedSet = granted.toSet();
      final List<String> removed = <String>[];
      final List<String> denied = <String>[];
      for (final TrashEntry entry in entries) {
        if (grantedSet.contains(entry.assetId)) {
          removed.add(entry.assetId);
        } else {
          denied.add(entry.assetId);
        }
      }
      _known.removeWhere((TrashEntry e) => removed.contains(e.assetId));
      await _local.removeTrashEntries(removed);
      return Success<EmptyTrashOutcome>(
        EmptyTrashOutcome(
          removedIds: removed,
          deniedIds: denied,
          // No unreachable ids here: entries come from the recorded
          // list, so every id was resolvable at trash time.
          failedIds: const <String>[],
        ),
      );
    } catch (_) {
      return const Failure<EmptyTrashOutcome>(
        AppFailure(messageKey: AppStrings.errorTrash),
      );
    }
  }
}
