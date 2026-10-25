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

  /// 30-day Trash with restore.
  static const String trash = '/trash';

  /// Deletion history.
  static const String history = '/history';

  /// Smart-deck hub (Phase 2A).
  static const String decks = '/decks';

  /// Duplicate / similar groups with the similarity slider (Phase 2A).
  static const String duplicates = '/duplicates';

  /// One smart deck as a swipe deck (Phase 2A). The deck's assets
  /// travel as route arguments (see SmartDeckLaunch).
  static const String smartDeck = '/smart-deck';

  /// Settings screen (Phase 3A).
  static const String settings = '/settings';
}
