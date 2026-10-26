import 'package:get/get.dart';

import '../../deck/binding/deck_binding.dart';
import '../../decks/binding/decks_binding.dart';
import '../../settings/binding/settings_binding.dart';
import '../controller/shell_controller.dart';

/// Registers the shell and its retained tabs (solutions 7.1).
/// Composition root, like AppPages: it delegates to the tabs' own
/// bindings, so each tab controller is still created only by its
/// feature binding. The tabs' controllers live as long as the shell
/// route (tab switches never dispose them). Review trips no longer
/// leave the shell (Review pushes on top and pops back, ADR-009),
/// so a Decks↔Trash round-trip keeps every tab; the Trash screen
/// reached from Review likewise pushes on top and pops back to
/// the shell (ADR-011) — no exit from Review or Trash destroys
/// the shell anymore.
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    DeckBinding().dependencies();
    DecksBinding().dependencies();
    SettingsBinding().dependencies();
    Get.put<ShellController>(ShellController(initialNavIndex: _initialTab()));
  }

  /// Initial tab from the route arguments (Review/Trash bottom-nav
  /// taps land here with 0, 1 or 3). Anything else — including no
  /// arguments, the splash handoff and Review's return — is Clean.
  /// Guarded like ReviewBinding's route reads: binding timing must
  /// never fail the shell.
  int _initialTab() {
    try {
      final dynamic args = Get.arguments;
      if (args is int && (args == 0 || args == 1 || args == 3)) {
        return args;
      }
    } catch (_) {
      // No route yet; Clean is the safe default.
    }
    return 0;
  }
}
