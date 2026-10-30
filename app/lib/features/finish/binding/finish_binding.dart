// Finish route binding (fix plan Stage 5).

import 'package:get/get.dart';

import '../../../services/review_ask/review_ask_service.dart';
import '../controller/finish_controller.dart';

class FinishBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FinishController>(
      () => FinishController(
        reviewAsk: Get.isRegistered<ReviewAskService>()
            ? Get.find<ReviewAskService>()
            : null,
      ),
    );
  }
}
