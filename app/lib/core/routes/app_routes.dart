/// Named route constants (AGENTS.md: named routes only, never
/// Navigator.push). Wiring lives in app_pages.dart.
class AppRoutes {
  AppRoutes._();

  /// Splash screen, the initial route (design.md §13).
  static const String splash = '/splash';

  /// Deck (home).
  static const String deck = '/';

  /// Review screen: editable grid of marked photos.
  static const String review = '/review';

  /// Finish screen after a completed delete batch (fix plan
  /// Stage 5, ADR-020). The batch travels as the route argument
  /// (a FinishSummary).
  static const String finish = '/finish';

  /// Delete-moment celebration (ADR-024): the short-lived hop
  /// both delete completions route through on their way to the
  /// finish screen. It receives the same FinishSummary argument
  /// and forwards it untouched.
  static const String celebration = '/celebration';

  /// 30-day Trash with restore.
  static const String trash = '/trash';

  /// Deletion history.
  static const String history = '/history';

  /// Smart-deck hub (Phase 2A).
  static const String decks = '/decks';

  /// Exact-duplicate groups from the scan's memberships (Phase 2A;
  /// the similarity slider was removed in fix plan Stage 4,
  /// ADR-019).
  static const String duplicates = '/duplicates';

  /// One smart deck as a swipe deck (Phase 2A). The deck's assets
  /// travel as route arguments (see SmartDeckLaunch).
  static const String smartDeck = '/smart-deck';

  /// All Albums screen (owner instruction 31 Oct 2026, ADR-027):
  /// every device album from the hub's "See all" — tapping one
  /// opens it as a swipe deck via the smart-deck route.
  static const String albums = '/albums';

  /// Settings screen (Phase 3A).
  static const String settings = '/settings';

  /// Compress-video screen (Phase 4).
  static const String compress = '/compress';
}
