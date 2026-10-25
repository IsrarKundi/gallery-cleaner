import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/trash/trash_entry.dart';
import '../../../services/trash/trash_service.dart';

/// Outcome of a trash action, for the view's feedback (snackbar,
/// denied dialog, error strip) and for tests. Navigation itself is
/// not asserted — see the navigation contract below.
enum TrashActionOutcome { restored, emptied, denied, failed, serviceError }

/// Trash screen state (requirements §4): Klara's recorded Trash list
/// (newest first), restore single + multi, and emptying.
///
/// Navigation contract: every exit resets the stack with
/// [Get.offAllNamed] to the deck, never [Get.back] into a stale
/// controller (see the review controller for why).
///
/// Record-cleanup ownership (verified in [TrashServiceImpl]): the
/// SERVICE removes restored/emptied ids from the recorded Trash list
/// ([LocalService.removeTrashEntries]) as part of [restoreAssets] /
/// [emptyTrash]. This controller therefore never removes records
/// itself — it only refreshes its list after the service returns, so
/// a denied id (still in Trash) reappears and a restored id does not.
///
/// Copy rule: trashed items are always "recoverable until [date]".
/// Space counts as freed only after a confirmed emptying, which is
/// the only path that appends a history record with freed MB.
class TrashController extends GetxController {
  TrashController({
    required this.trash,
    required this.local,
    String? arrivalSnackDate,
  }) : _arrivalSnackDateOverride = arrivalSnackDate;

  final TrashService trash;
  final LocalService local;

  final String? _arrivalSnackDateOverride;

  /// Recorded Trash entries, newest first. Metadata only — trashed
  /// assets are hidden from MediaStore queries, so no thumbnails.
  final RxList<TrashEntry> entries = <TrashEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isBusy = false.obs;
  final RxString errorKey = ''.obs;

  /// Recoverable-until date carried from a successful review delete
  /// (route arguments), for the arrival snackbar. Cleared once shown.
  final RxString arrivalSnackDate = ''.obs;

  /// MB freed by the last confirmed emptying, for the snackbar.
  final RxInt lastFreedBytes = 0.obs;

  /// Phase 3B mixed-outcome counts for the view's denied dialogs:
  /// how many of the last restore were actually restored, and how
  /// many failed to resolve. A pure denied run leaves both at 0, so
  /// the view can tell a pure denial from a partial one.
  final RxInt lastRestoredCount = 0.obs;
  final RxInt lastFailedCount = 0.obs;

  /// Phase 3A private blur (same setting as Review/Settings).
  /// Trash rows are metadata-only — trashed assets are hidden from
  /// MediaStore queries, so there is no thumbnail to blur here.
  /// The toggle still lives on this screen because the setting is
  /// global, and the rows themselves already show no photo content.
  final RxBool privateBlur = false.obs;

  /// Phase 3A auto-empty prompt state. True only when the setting
  /// is ON and at least one record has passed its recoverableUntil
  /// date. The view then shows the prompt dialog (in-app
  /// confirmation); confirming calls [emptyTrash] (native sheet
  /// follows), declining calls [cleanupExpiredRecords].
  final RxBool autoEmptyPromptPending = false.obs;
  final RxInt expiredCount = 0.obs;

  /// Records past their recoverableUntil date (system media for
  /// these is already gone after the 30 days).
  List<TrashEntry> get expiredEntries {
    final DateTime now = DateTime.now();
    return entries
        .where((TrashEntry e) => e.recoverableUntil.isBefore(now))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    final String? fromArgs = _arrivalSnackDateOverride ?? _routeSnackDate();
    if (fromArgs != null && fromArgs.isNotEmpty) {
      arrivalSnackDate.value = fromArgs;
    }
    init();
  }

  /// Reads the arrival-snackbar date the review screen passed as
  /// route arguments. Guarded for direct construction in tests.
  String? _routeSnackDate() {
    try {
      final dynamic args = Get.arguments;
      if (args is String) {
        return args;
      }
    } catch (_) {
      // No route in this context.
    }
    return null;
  }

  /// Clears the arrival snackbar after the view shows it, so a
  /// rebuild never shows it twice.
  void clearArrivalSnack() {
    arrivalSnackDate.value = '';
  }

  /// True once [init] has fully finished (list + settings). The
  /// arrival snackbar waits for this (Phase 3.4): the auto-empty
  /// prompt flag is set asynchronously at the end of init, so a
  /// snackbar shown before init completes would race the dialog.
  final RxBool initComplete = false.obs;

  /// Loads the recorded Trash list. Shared by onInit and retry.
  /// Also loads the Phase 3A settings (blur + auto-empty prompt):
  /// the prompt fires only when the setting is ON and expired
  /// records exist — when OFF, expired records are simply left
  /// for manual emptying, with no prompt and no cleanup.
  Future<void> init() async {
    isLoading.value = true;
    errorKey.value = '';
    final Result<List<TrashEntry>> result = await trash.listTrashed();
    result.fold(
      onSuccess: entries.assignAll,
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
      },
    );
    isLoading.value = false;
    final Result<AppSettings> settingsResult = await local.loadSettings();
    settingsResult.fold(
      onSuccess: (AppSettings value) {
        privateBlur.value = value.privateBlur;
        expiredCount.value = expiredEntries.length;
        autoEmptyPromptPending.value =
            value.trashAutoEmptyPrompt && expiredCount.value > 0;
      },
      onFailure: (_) {},
    );
    initComplete.value = true;
  }

  /// Flips private blur and persists it (same setting as Review
  /// and Settings). See [privateBlur] for why Trash rows do not
  /// visibly change: they carry no thumbnails.
  Future<void> toggleBlur() async {
    final Result<AppSettings> loaded = await local.loadSettings();
    final AppSettings current = loaded.fold(
      onSuccess: (AppSettings value) => value,
      onFailure: (_) => const AppSettings(),
    );
    final bool next = !current.privateBlur;
    final Result<void> saved = await local.saveSettings(
      current.copyWith(privateBlur: next),
    );
    saved.fold(
      onSuccess: (_) {
        privateBlur.value = next;
        AppHaptics.mark();
      },
      onFailure: (_) => errorKey.value = AppStrings.errorLocal,
    );
  }

  /// Record-only cleanup of expired records (Phase 3A trust-rule
  /// resolution): drops stale local records whose system media
  /// already expired after 30 days. This deletes NO media — there
  /// is none left to delete for these ids — and it never touches
  /// still-recoverable records. Called when the user declines the
  /// auto-empty prompt, so the list stops advertising restores
  /// that the system can no longer honour.
  Future<void> cleanupExpiredRecords() async {
    final List<String> ids = expiredEntries
        .map((TrashEntry e) => e.assetId)
        .toList();
    autoEmptyPromptPending.value = false;
    if (ids.isEmpty) {
      return;
    }
    await local.removeTrashEntries(ids);
    await _refresh();
    expiredCount.value = expiredEntries.length;
  }

  /// Restores [ids] (single row or all) through the native sheet.
  /// Returns null when there is nothing to restore or an action is
  /// already running. Denied ids stay in Trash; failed ids keep
  /// their records too. The list refreshes after every outcome.
  Future<TrashActionOutcome?> restore(List<String> ids) async {
    if (ids.isEmpty || isBusy.value) {
      return null;
    }
    isBusy.value = true;
    errorKey.value = '';
    lastRestoredCount.value = 0;
    lastFailedCount.value = 0;
    final Result<RestoreOutcome> result = await trash.restoreAssets(ids);
    isBusy.value = false;
    if (result.isFailure) {
      errorKey.value = (result as Failure<RestoreOutcome>).failure.messageKey;
      return TrashActionOutcome.serviceError;
    }
    final RestoreOutcome outcome = (result as Success<RestoreOutcome>).value;
    lastRestoredCount.value = outcome.restoredIds.length;
    lastFailedCount.value = outcome.failedIds.length;
    await _refresh();
    if (outcome.deniedIds.isNotEmpty) {
      // Phase 3B: a denied run that also failed some ids used to
      // hide the failures behind the denied dialog. The error strip
      // survives under the dialog, so the user still sees that a
      // retry is possible for the failed ids.
      if (outcome.failedIds.isNotEmpty) {
        errorKey.value = AppStrings.errorTrash;
      }
      return TrashActionOutcome.denied;
    }
    if (outcome.failedIds.isNotEmpty) {
      errorKey.value = AppStrings.errorTrash;
      return TrashActionOutcome.failed;
    }
    return TrashActionOutcome.restored;
  }

  /// Empties Trash through the native sheet. The view shows Klara's
  /// own in-app confirmation first; this method only runs after it.
  /// On success it appends the one history record for the run
  /// (freed MB = sum of the emptied entries, trashed 0) and refreshes
  /// the list. On denied, records stay untouched and no history is
  /// written. Returns null when Trash is already empty or an action
  /// is already running.
  Future<TrashActionOutcome?> emptyTrash() async {
    if (entries.isEmpty || isBusy.value) {
      return null;
    }
    isBusy.value = true;
    errorKey.value = '';
    lastFreedBytes.value = 0;
    final Map<String, TrashEntry> byId = <String, TrashEntry>{
      for (final TrashEntry entry in entries) entry.assetId: entry,
    };
    final Result<EmptyTrashOutcome> result = await trash.emptyTrash();
    isBusy.value = false;
    if (result.isFailure) {
      errorKey.value =
          (result as Failure<EmptyTrashOutcome>).failure.messageKey;
      return TrashActionOutcome.serviceError;
    }
    final EmptyTrashOutcome outcome =
        (result as Success<EmptyTrashOutcome>).value;
    if (outcome.removedIds.isNotEmpty) {
      int bytes = 0;
      for (final String id in outcome.removedIds) {
        bytes += byId[id]?.sizeBytes ?? 0;
      }
      lastFreedBytes.value = bytes;
      await local.appendHistory(
        HistoryRecord(
          date: DateTime.now(),
          count: outcome.removedIds.length,
          mbTrashed: 0,
          mbFreed: bytes / 1048576,
        ),
      );
      // Phase 3A haptics (design.md §8): firm pulse when trash is
      // emptied and space is actually freed.
      AppHaptics.freed();
    }
    await _refresh();
    autoEmptyPromptPending.value = false;
    if (outcome.deniedIds.isNotEmpty) {
      return TrashActionOutcome.denied;
    }
    return TrashActionOutcome.emptied;
  }

  /// Silent refresh (no loading spinner): the service already owns
  /// record removal, so the list is simply re-read.
  Future<void> _refresh() async {
    final Result<List<TrashEntry>> result = await trash.listTrashed();
    result.fold(onSuccess: entries.assignAll, onFailure: (_) {});
  }

  /// Resets the stack to the deck so it reloads fresh from the
  /// session. Never [Get.back] into the stale deck controller.
  void goToDeck() {
    Get.offAllNamed<dynamic>(AppRoutes.deck);
  }
}
