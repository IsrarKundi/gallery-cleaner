// Favourites-protection state shared by the deck and smart-deck
// controllers (Phase 3A). The check lives here, not duplicated in
// both controllers: a delete mark on a protected photo is blocked
// (never silent — [blockedKey] carries the explanation string key
// the view shows as a banner), every other mark clears the notice.
//
// Cross-feature note: the smart-deck controller imports this file
// exactly like it already imports DeckRetention from this folder —
// the approved decks→deck reuse, not a new pattern.

import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../services/local/local_service.dart';
import '../../../services/local/protection.dart';
import '../../../services/media/media_asset.dart';

class DeckProtection {
  /// Set when a delete mark was blocked; cleared by any other mark
  /// and by [clearNotice].
  final RxString blockedKey = ''.obs;

  bool _enabled = false;
  Set<String> _klaraFavourites = <String>{};

  /// Loads the toggle + the union of Klara favourites across all
  /// sessions, so a favourite made in any deck protects the photo
  /// here too. A settings-load failure reads as protection OFF.
  Future<void> load(LocalService local) async {
    final settings = await local.loadSettings();
    _enabled = settings.fold(
      onSuccess: (AppSettings value) => value.protection,
      onFailure: (_) => false,
    );
    _klaraFavourites = await loadAllKlaraFavouriteIds(local);
  }

  /// True when [mark] on [asset] must be blocked: a delete mark on
  /// a protected photo (Klara favourite or system favourite) while
  /// protection is ON. Sets [blockedKey] on a block, clears it on
  /// any allowed mark, and never blocks a non-delete mark.
  bool blocksDelete(
    DeckMark mark,
    MediaAsset asset,
    Set<String> sessionFavourites,
  ) {
    if (mark != DeckMark.delete ||
        !_enabled ||
        !isProtected(
          asset,
          klaraFavourites: <String>{..._klaraFavourites, ...sessionFavourites},
        )) {
      blockedKey.value = '';
      return false;
    }
    blockedKey.value = AppStrings.protectionDeckBlocked;
    return true;
  }

  void clearNotice() {
    blockedKey.value = '';
  }
}
