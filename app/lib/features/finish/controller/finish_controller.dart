// Finish screen controller (fix plan Stage 5, ADR-020).
//
// Holds the batch summary handed over as the route argument
// and the Done navigation. The screen has no other state: the
// numbers were final when the batch completed.

import 'dart:async';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../services/review_ask/review_ask_service.dart';
import '../../shell/controller/shell_controller.dart';
import '../model/finish_summary.dart';

class FinishController extends GetxController {
  FinishController({this.reviewAsk});

  /// The review-ask service, optional (null = the delete-place
  /// ask never presents — tests and service-less launches stay
  /// inert). The binding resolves it when registered.
  final ReviewAskService? reviewAsk;

  /// The completed batch, read from the route argument in
  /// [onInit]. Null only on a programmer error (the route was
  /// opened without a summary) — [onInit] then leaves the
  /// screen for the deck instead of showing invented numbers.
  FinishSummary? summary;

  final RxBool isReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    final Object? args = Get.arguments;
    if (args is FinishSummary) {
      summary = args;
      isReady.value = true;
      return;
    }
    // No batch, no screen: fall back to the deck tab rather
    // than dead-ending on an empty congratulations page.
    unawaited(
      Future<void>.microtask(
        () => Get.offAllNamed<dynamic>(AppRoutes.deck, arguments: 0),
      ),
    );
  }

  /// Done (and the system back button, via the view's
  /// PopScope): back to the deck tab — pop to the retained
  /// shell when there is one (the ReviewController.goToDeck
  /// pattern), standalone reset otherwise.
  void done() {
    if (Get.isRegistered<ShellController>()) {
      Get.find<ShellController>().selectTab(0);
      Get.back<dynamic>();
      return;
    }
    Get.offAllNamed<dynamic>(AppRoutes.deck, arguments: 0);
  }
}
