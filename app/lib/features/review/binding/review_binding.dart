import 'package:get/get.dart';

import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../../../services/trash/trash_service.dart';
import '../controller/review_controller.dart';

/// Registers the review controller with constructor injection
/// (AGENTS.md: controllers are registered ONLY in bindings). Services
/// come from the initial binding, behind their interfaces. The review
/// set travels as route arguments (the deck's asset list) and the
/// deck filter key as a route parameter; the controller re-resolves
/// both on init, so binding timing can never leave it empty.
class ReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReviewController>(
      () => ReviewController(
        media: Get.find<MediaService>(),
        trash: Get.find<TrashService>(),
        local: Get.find<LocalService>(),
        initialAssets: _routeAssets(),
        filterKeyOverride: _routeFilterKey(),
      ),
    );
  }

  List<MediaAsset>? _routeAssets() {
    try {
      final dynamic args = Get.arguments;
      if (args is List<MediaAsset>) {
        return args;
      }
    } catch (_) {
      // No route yet; the controller falls back on init.
    }
    return null;
  }

  String? _routeFilterKey() {
    try {
      return Get.parameters['filterKey'];
    } catch (_) {
      return null;
    }
  }
}
