// Deck warm-up: the critical-path work the splash overlaps.
//
// The splash animation itself is NOT shortened (design §13). Instead,
// the splash binding starts this service while the splash plays, and
// the deck joins the already-running work instead of redoing it:
// permission first, then the first page for the All filter. The
// session load and restore stay in the deck — they are local reads
// and pure mapping (milliseconds, ADR-001) — so this service never
// needs a filter key and never touches session state.
//
// Single-use by design: the deck consumes the warmed work on its
// first init only. A later retry (e.g. after a denied grant is fixed
// in Settings) re-requests permission and re-fetches page 0 fresh,
// so a stale grant can never survive a retry. Both futures always
// complete (failure reads as null), so the deck always falls back
// to its normal path instead of hanging on warm-up.

import '../media/media_asset.dart';

/// Warm-up for the deck's critical path (solutions 2.2).
abstract class DeckWarmUp {
  /// True once [start] has run. The deck only joins warmed work
  /// when this is true; otherwise it runs its normal path.
  bool get started;

  /// Starts permission + first-page work. Idempotent: later calls
  /// are no-ops, so the splash and the deck can both call it safely.
  void start();

  /// The warmed permission, or null when warm-up never ran, failed,
  /// or the user denied. Never throws; never hangs.
  Future<MediaPermission?> get permission;

  /// The warmed page-0 assets for the All filter, or null when
  /// warm-up never ran, permission was denied, or the page failed.
  /// Null means "fetch page 0 normally". Never throws; never hangs.
  Future<List<MediaAsset>?> get firstPage;
}
