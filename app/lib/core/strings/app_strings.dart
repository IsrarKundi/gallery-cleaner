/// Every user-visible Phase 1 string for Klara (design.md §10).
///
/// Views and widgets use keys only, via [tr]; the English map is the v1
/// locale. Later locales are added here without touching views.
/// Placeholders use `{name}` and are filled by [tr].
///
/// Phase 1 scope only: no strings for duplicates, similarity, goals,
/// streaks, dark mode, notifications, video compression or documents
/// (Phases 2-4). Trust wording follows requirements §4: swipes only mark,
/// nothing is called freed while it sits in Trash, and the word
/// "permanent" is never used while restore exists.
class AppStrings {
  AppStrings._();

  // App.
  static const String appTitle = 'appTitle';

  // Screens.
  static const String screenDeck = 'screenDeck';
  static const String screenReview = 'screenReview';
  static const String screenTrash = 'screenTrash';
  static const String screenHistory = 'screenHistory';

  // Deck edge labels (requirements §3: LOCKED mapping, always visible).
  static const String edgeKeep = 'edgeKeep';
  static const String edgeDelete = 'edgeDelete';
  static const String edgeMaybe = 'edgeMaybe';
  static const String edgeFavourite = 'edgeFavourite';

  // Deck and review actions (sentence case labels, design.md §3).
  static const String actionKeep = 'actionKeep';
  static const String actionDelete = 'actionDelete';
  static const String actionMaybe = 'actionMaybe';
  static const String actionFavourite = 'actionFavourite';
  static const String actionUndo = 'actionUndo';
  static const String actionReview = 'actionReview';
  static const String actionTrash = 'actionTrash';
  static const String actionRestore = 'actionRestore';
  static const String actionHistory = 'actionHistory';
  static const String actionKeepAll = 'actionKeepAll';
  static const String actionSkip = 'actionSkip';

  // Generic actions.
  static const String actionCancel = 'actionCancel';
  static const String actionConfirm = 'actionConfirm';
  static const String actionClose = 'actionClose';
  static const String actionOk = 'actionOk';

  // Three-state space meter (requirements §4). Never report trashed
  // space as freed.
  static const String meterToBeFreed = 'meterToBeFreed';
  static const String meterInTrash = 'meterInTrash';
  static const String meterFreed = 'meterFreed';

  // Review.
  static const String reviewDeleteCount = 'reviewDeleteCount';

  // Trash.
  static const String trashEmpty = 'trashEmpty';
  static const String trashEmptyConfirmTitle = 'trashEmptyConfirmTitle';
  static const String trashEmptyConfirmMessage = 'trashEmptyConfirmMessage';
  static const String trashEmptyTitle = 'trashEmptyTitle';
  static const String trashEmptyMessage = 'trashEmptyMessage';

  // History.
  static const String historyEmptyTitle = 'historyEmptyTitle';
  static const String historyEmptyMessage = 'historyEmptyMessage';

  // Permissions (requirements §5). Partial access is stated honestly:
  // the app works on exactly the granted photos.
  static const String permissionTitle = 'permissionTitle';
  static const String permissionMessage = 'permissionMessage';
  static const String permissionAllowAccess = 'permissionAllowAccess';
  static const String permissionPartialTitle = 'permissionPartialTitle';
  static const String permissionPartialMessage = 'permissionPartialMessage';
  static const String permissionDeniedTitle = 'permissionDeniedTitle';
  static const String permissionDeniedMessage = 'permissionDeniedMessage';
  static const String permissionOpenSettings = 'permissionOpenSettings';

  // Denied native delete confirmation (requirements §5): photos return
  // to the deck with an explanation, never silently vanish.
  static const String deniedConfirmTitle = 'deniedConfirmTitle';
  static const String deniedConfirmMessage = 'deniedConfirmMessage';

  // Empty states (design.md §6): exactly one CTA each.
  static const String emptyFirstRunTitle = 'emptyFirstRunTitle';
  static const String emptyFirstRunMessage = 'emptyFirstRunMessage';
  static const String emptyFirstRunCta = 'emptyFirstRunCta';
  static const String emptyCleanTitle = 'emptyCleanTitle';
  static const String emptyCleanMessage = 'emptyCleanMessage';
  static const String emptyCleanCta = 'emptyCleanCta';
  static const String emptyNoFilterTitle = 'emptyNoFilterTitle';
  static const String emptyNoFilterMessage = 'emptyNoFilterMessage';
  static const String emptyNoFilterCta = 'emptyNoFilterCta';

  // Errors and retry.
  static const String errorGeneric = 'errorGeneric';
  static const String errorRetry = 'errorRetry';

  // Scan and session.
  static const String scanNow = 'scanNow';
  static const String scanAgain = 'scanAgain';
  static const String clearFilters = 'clearFilters';
  static const String scanningPhotos = 'scanningPhotos';
  static const String resumeSession = 'resumeSession';

  // First-run tutorial (requirements §3: mandatory, because the mapping
  // is the opposite of the usual convention).
  static const String tutorialTitle = 'tutorialTitle';
  static const String tutorialKeep = 'tutorialKeep';
  static const String tutorialDelete = 'tutorialDelete';
  static const String tutorialMaybe = 'tutorialMaybe';
  static const String tutorialFavourite = 'tutorialFavourite';
  static const String tutorialSwipeNote = 'tutorialSwipeNote';
  static const String tutorialDone = 'tutorialDone';

  // Confirmations and feedback.
  static const String snackMovedToTrash = 'snackMovedToTrash';
  static const String snackRestored = 'snackRestored';
  static const String snackUndone = 'snackUndone';

  /// English (v1) values, keyed by the constants above.
  static const Map<String, String> en = <String, String>{
    appTitle: 'Klara',
    screenDeck: 'Clean',
    screenReview: 'Review',
    screenTrash: 'Trash',
    screenHistory: 'History',
    edgeKeep: 'KEEP',
    edgeDelete: 'DELETE',
    edgeMaybe: 'MAYBE',
    edgeFavourite: 'FAVOURITE',
    actionKeep: 'Keep',
    actionDelete: 'Delete',
    actionMaybe: 'Maybe',
    actionFavourite: 'Favourite',
    actionUndo: 'Undo',
    actionReview: 'Review',
    actionTrash: 'Trash',
    actionRestore: 'Restore',
    actionHistory: 'History',
    actionKeepAll: 'Keep all',
    actionSkip: 'Skip',
    actionCancel: 'Cancel',
    actionConfirm: 'Confirm',
    actionClose: 'Close',
    actionOk: 'OK',
    meterToBeFreed: 'To be freed',
    meterInTrash: 'In trash until {date}',
    meterFreed: 'Freed',
    reviewDeleteCount: 'Delete {count} photos',
    trashEmpty: 'Empty trash',
    trashEmptyConfirmTitle: 'Empty trash?',
    trashEmptyConfirmMessage:
        'Photos in trash will be removed and cannot be restored.',
    trashEmptyTitle: 'Trash is empty',
    trashEmptyMessage: 'Photos you remove stay here for 30 days.',
    historyEmptyTitle: 'No history yet',
    historyEmptyMessage: 'Your cleaning history will appear here.',
    permissionTitle: 'Access your photos',
    permissionMessage:
        'Klara needs access to your photos so you can swipe through '
        'your whole library and decide what to keep.',
    permissionAllowAccess: 'Allow access',
    permissionPartialTitle: 'Working on selected photos',
    permissionPartialMessage:
        'You shared only some photos. Klara works on exactly those '
        'photos and nothing else.',
    permissionDeniedTitle: 'Photo access denied',
    permissionDeniedMessage:
        'Without photo access there is nothing to clean. You can '
        'change this in settings.',
    permissionOpenSettings: 'Open settings',
    deniedConfirmTitle: 'Nothing was removed',
    deniedConfirmMessage:
        'You did not confirm, so those photos were returned to the deck.',
    emptyFirstRunTitle: 'No scan yet',
    emptyFirstRunMessage: 'Scan your library to start cleaning it up.',
    emptyFirstRunCta: 'Scan now',
    emptyCleanTitle: 'Your library is clean',
    emptyCleanMessage: 'Nothing here needs your attention right now.',
    emptyCleanCta: 'Scan again',
    emptyNoFilterTitle: 'No photos match',
    emptyNoFilterMessage: 'Try a different filter to see more photos.',
    emptyNoFilterCta: 'Clear filters',
    errorGeneric: 'Something went wrong',
    errorRetry: 'Retry',
    scanNow: 'Scan now',
    scanAgain: 'Scan again',
    clearFilters: 'Clear filters',
    scanningPhotos: 'Scanning photos…',
    resumeSession: 'Resume where you left off',
    tutorialTitle: 'How swiping works',
    tutorialKeep: 'Swipe left to keep a photo.',
    tutorialDelete: 'Swipe right to mark a photo for removal.',
    tutorialMaybe: 'Swipe up to decide later.',
    tutorialFavourite: 'Swipe down to favourite and protect a photo.',
    tutorialSwipeNote:
        'Swiping only marks a photo. Nothing is removed until you '
        'review it and confirm.',
    tutorialDone: 'Got it',
    snackMovedToTrash: 'Moved to trash. You have 30 days to restore.',
    snackRestored: 'Photo restored',
    snackUndone: 'Action undone',
  };

  /// Resolves [key] to its English text, filling `{name}` placeholders
  /// from [params]. Unknown keys resolve to the key itself so a missing
  /// entry is visible in tests instead of crashing a view.
  static String tr(String key, [Map<String, String>? params]) {
    String value = en[key] ?? key;
    final Map<String, String>? replacements = params;
    if (replacements != null) {
      for (final MapEntry<String, String> entry in replacements.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return value;
  }
}
