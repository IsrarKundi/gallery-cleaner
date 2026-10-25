import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';

/// History screen state (requirements §4): deletion-history records,
/// newest first. Read-only: no action other than back to the deck.
///
/// Navigation contract: back resets the stack with [Get.offAllNamed]
/// to the deck, never [Get.back] into a stale controller (see the
/// review controller for why). Three-state accounting is preserved
/// in the rows: trashed MB is shown as trashed, freed MB only on
/// empty-trash records (0 for trash events, never the reverse).
class HistoryController extends GetxController {
  HistoryController({required this.local});

  final LocalService local;

  /// History records, newest first.
  final RxList<HistoryRecord> records = <HistoryRecord>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorKey = ''.obs;

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Loads the history records. Shared by onInit and retry.
  Future<void> init() async {
    isLoading.value = true;
    errorKey.value = '';
    final Result<List<HistoryRecord>> result = await local.loadHistory();
    result.fold(
      onSuccess: records.assignAll,
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
      },
    );
    isLoading.value = false;
  }

  /// Resets the stack to the deck. Never [Get.back] into the stale
  /// deck controller.
  void goToDeck() {
    Get.offAllNamed<dynamic>(AppRoutes.deck);
  }
}
