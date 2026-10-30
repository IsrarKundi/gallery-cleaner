// Scan memberships, Drift-backed (fix plan Stage 4, ADR-019).
//
// Stage 3's three-store split, landed: asset-info facts, group
// memberships and the duplicate reference are separate tables,
// and NO hash or blur-score value is stored anywhere in them —
// the Stage 4 persisted product is memberships only
// (scan_memberships.dart). Fingerprints and scores are
// recomputed on demand whenever a scan's facts change.
//
// Shape notes:
// - The snapshot is written WHOLESALE after a complete scan
//   (one transaction: clear + insert), so replacement is also
//   the prune — a deleted asset's memberships simply are not
//   in the new snapshot.
// - Group members carry [memberIndex] so a group's persisted
//   order (seed first for similar groups) survives the round
//   trip exactly; duplicate-reference duplicates likewise.

import 'package:drift/drift.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../detection/scan_memberships.dart';
import '../media/media_asset.dart';
import 'klara_database.dart';

class ScanMembershipStore {
  ScanMembershipStore(this._db);

  final KlaraDatabase _db;

  /// Loads the whole snapshot. Never throws.
  Future<Result<ScanMemberships>> load() async {
    try {
      final List<AssetInfoRow> infoRows = await _db
          .select(_db.assetInfos)
          .get();
      final List<ScanGroupRow> groupRows = await _db
          .select(_db.scanGroups)
          .get();
      final List<ScanGroupMemberRow> memberRows =
          await (_db.select(_db.scanGroupMembers)
                ..orderBy(<OrderingTerm Function(ScanGroupMembers)>[
                  (ScanGroupMembers t) => OrderingTerm.asc(t.memberIndex),
                ]))
              .get();
      final List<DuplicateReferenceRow> refRows = await _db
          .select(_db.duplicateReferences)
          .get();
      final List<DuplicateReferenceMemberRow> refMemberRows =
          await (_db.select(_db.duplicateReferenceMembers)
                ..orderBy(<OrderingTerm Function(DuplicateReferenceMembers)>[
                  (DuplicateReferenceMembers t) =>
                      OrderingTerm.asc(t.memberIndex),
                ]))
              .get();
      final MetaEntry? versionRow =
          await (_db.select(_db.metaEntries)
                ..where((MetaEntries t) => t.key.equals(kMembershipVersionKey)))
              .getSingleOrNull();

      final Map<int, List<String>> membersByGroup = <int, List<String>>{};
      for (final ScanGroupMemberRow row in memberRows) {
        (membersByGroup[row.groupRowId] ??= <String>[]).add(row.assetId);
      }
      final Map<int, List<String>> dupsByRef = <int, List<String>>{};
      for (final DuplicateReferenceMemberRow row in refMemberRows) {
        (dupsByRef[row.referenceRowId] ??= <String>[]).add(row.assetId);
      }

      return Success<ScanMemberships>(
        ScanMemberships(
          algorithmVersion:
              int.tryParse(versionRow?.value ?? '') ??
              0, // No stamp: no memberships were ever saved.
          assetInfos: <String, AssetInfo>{
            for (final AssetInfoRow row in infoRows)
              row.assetId: AssetInfo(
                assetId: row.assetId,
                type: MediaAssetType.values.byName(row.type),
                width: row.width,
                height: row.height,
                sizeBytes: row.sizeBytes,
                modifiedDateMs: row.modifiedDateMs,
                isEdited: row.isEdited,
                isScreenshot: row.isScreenshot,
              ),
          },
          groups: <ScanGroup>[
            for (final ScanGroupRow row in groupRows)
              ScanGroup(
                kind: ScanGroupKind.values.byName(row.kind),
                memberIds: membersByGroup[row.id] ?? const <String>[],
                seedId: row.seedId,
                keeperId: row.keeperId,
              ),
          ],
          duplicateReferences: <DuplicateReference>[
            for (final DuplicateReferenceRow row in refRows)
              DuplicateReference(
                mainId: row.mainId,
                duplicateIds: dupsByRef[row.id] ?? const <String>[],
              ),
          ],
        ),
      );
    } catch (e) {
      return const Failure<ScanMemberships>(
        AppFailure(messageKey: AppStrings.errorLocal),
      );
    }
  }

  /// Replaces the whole snapshot in one transaction.
  Future<Result<void>> save(ScanMemberships memberships) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.assetInfos).go();
        await _db.delete(_db.scanGroupMembers).go();
        await _db.delete(_db.scanGroups).go();
        await _db.delete(_db.duplicateReferenceMembers).go();
        await _db.delete(_db.duplicateReferences).go();
        await _db.batch((Batch batch) {
          batch.insertAll(_db.assetInfos, <AssetInfosCompanion>[
            for (final AssetInfo info in memberships.assetInfos.values)
              AssetInfosCompanion.insert(
                assetId: info.assetId,
                type: info.type.name,
                width: info.width,
                height: info.height,
                sizeBytes: Value<int?>(info.sizeBytes),
                modifiedDateMs: Value<int?>(info.modifiedDateMs),
                isEdited: info.isEdited,
                isScreenshot: info.isScreenshot,
              ),
          ]);
        });
        for (final ScanGroup group in memberships.groups) {
          final int groupRowId = await _db
              .into(_db.scanGroups)
              .insert(
                ScanGroupsCompanion.insert(
                  kind: group.kind.name,
                  seedId: Value<String?>(group.seedId),
                  keeperId: Value<String?>(group.keeperId),
                ),
              );
          await _db.batch((Batch batch) {
            batch.insertAll(_db.scanGroupMembers, <ScanGroupMembersCompanion>[
              for (int i = 0; i < group.memberIds.length; i++)
                ScanGroupMembersCompanion.insert(
                  groupRowId: groupRowId,
                  assetId: group.memberIds[i],
                  memberIndex: i,
                ),
            ]);
          });
        }
        for (final DuplicateReference reference
            in memberships.duplicateReferences) {
          final int refRowId = await _db
              .into(_db.duplicateReferences)
              .insert(
                DuplicateReferencesCompanion.insert(mainId: reference.mainId),
              );
          await _db.batch((Batch batch) {
            batch.insertAll(
              _db.duplicateReferenceMembers,
              <DuplicateReferenceMembersCompanion>[
                for (int i = 0; i < reference.duplicateIds.length; i++)
                  DuplicateReferenceMembersCompanion.insert(
                    referenceRowId: refRowId,
                    assetId: reference.duplicateIds[i],
                    memberIndex: i,
                  ),
              ],
            );
          });
        }
        await _db
            .into(_db.metaEntries)
            .insertOnConflictUpdate(
              MetaEntriesCompanion.insert(
                key: kMembershipVersionKey,
                value: '${memberships.algorithmVersion}',
              ),
            );
      });
      return const Success<void>(null);
    } catch (e) {
      return const Failure<void>(AppFailure(messageKey: AppStrings.errorLocal));
    }
  }
}
