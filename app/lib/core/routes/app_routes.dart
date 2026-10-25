/// Named route constants (AGENTS.md: named routes only, never
/// Navigator.push). Wiring lives in app_pages.dart, which is NOT built
/// in this increment: feature views do not exist yet, and placeholder
/// pages with dead buttons are banned.
class AppRoutes {
  AppRoutes._();

  /// Deck (home). The deck view replaces the temporary home in
  /// main.dart in a later increment.
  static const String deck = '/';

  /// Review screen: editable grid of marked photos.
  static const String review = '/review';

  /// 30-day Trash with restore.
  static const String trash = '/trash';

  /// Deletion history.
  static const String history = '/history';
}
