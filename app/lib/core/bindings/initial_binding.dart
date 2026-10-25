import 'package:get/get.dart';

/// The ONLY place global Get.put lives (AGENTS.md).
///
/// Phase 1 foundation: no services exist yet. Worker 3 registers the
/// media, trash and local services here. No fake services are
/// registered in the meantime.
class InitialBinding extends Bindings {
  @override
  void dependencies() {}
}
