import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
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

  /// Loads the recorded Trash list. Shared by onInit and retry.
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
    final Result<RestoreOutcome> result = await trash.restoreAssets(ids);
    isBusy.value = false;
    if (result.isFailure) {
      errorKey.value = (result as Failure<RestoreOutcome>).failure.messageKey;
      return TrashActionOutcome.serviceError;
    }
    final RestoreOutcome outcome = (result as Success<RestoreOutcome>).value;
    await _refresh();
    if (outcome.deniedIds.isNotEmpty) {
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
    }
    await _refresh();
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
