// Phase 4 extraction from [ReviewController] (which sits at its
// ~400-line budget): private-blur state for the review grid.
//
// Behaviour is unchanged from Phase 3A: blur is a global setting
// shared with Settings (default OFF — blurring by default would
// hide exactly what the user must judge before a restore/delete);
// when ON, grid thumbnails render blurred until tapped; a reveal
// lasts until blur is toggled or the screen is left. The deck is
// never blurred. Errors surface as a string key for the controller
// to render; nothing here touches the view.

import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';

class ReviewBlur {
  /// Global private-blur setting, mirrored from Settings.
  final RxBool privateBlur = false.obs;

  /// Per-item reveals while blur is ON. Cleared on toggle and lost
  /// when the screen is left, so a revealed photo is never left
  /// unblurred behind the user.
  final RxSet<String> revealedIds = <String>{}.obs;

  /// Reads the persisted blur setting (defaults OFF).
  Future<void> load(LocalService local) async {
    final Result<AppSettings> result = await local.loadSettings();
    result.fold(
      onSuccess: (AppSettings value) => privateBlur.value = value.privateBlur,
      onFailure: (_) {},
    );
  }

  /// Flips private blur and persists it (the same setting the
  /// Settings screen toggles). Toggling clears all reveals.
  /// Returns an error string key on save failure, null on success.
  Future<String?> toggle(LocalService local) async {
    final Result<AppSettings> loaded = await local.loadSettings();
    final AppSettings current = loaded.fold(
      onSuccess: (AppSettings value) => value,
      onFailure: (_) => const AppSettings(),
    );
    final bool next = !current.privateBlur;
    final Result<void> saved = await local.saveSettings(
      current.copyWith(privateBlur: next),
    );
    return saved.fold(
      onSuccess: (_) {
        privateBlur.value = next;
        revealedIds.clear();
        AppHaptics.mark();
        return null;
      },
      onFailure: (_) => AppStrings.errorLocal,
    );
  }

  /// Reveals one blurred thumbnail until blur is toggled off or
  /// the screen is left (see [revealedIds]).
  void reveal(String assetId) {
    revealedIds.add(assetId);
  }

  /// True when [asset]'s tile must render blurred: blur ON and
  /// this item not yet tapped to reveal.
  bool isBlurred(MediaAsset asset) {
    return privateBlur.value && !revealedIds.contains(asset.id);
  }
}
