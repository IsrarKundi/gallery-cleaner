/// Every user-visible string for Klara (design.md §10).
/// Phase 1 + Phase 2A (smart decks, duplicates) only.
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
  static const String screenDecks = 'screenDecks';
  static const String screenDuplicates = 'screenDuplicates';
  static const String screenSmartDeck = 'screenSmartDeck';

  // Bottom navigation.
  static const String navClean = 'navClean';
  static const String navDecks = 'navDecks';
  static const String navTrash = 'navTrash';
  static const String navSettings = 'navSettings';

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
  static const String actionAddToAlbum = 'actionAddToAlbum';
  static const String actionShare = 'actionShare';

  // Generic actions.
  static const String actionCancel = 'actionCancel';
  static const String actionConfirm = 'actionConfirm';
  static const String actionClose = 'actionClose';
  static const String actionOk = 'actionOk';
  static const String actionBackToDeck = 'actionBackToDeck';

  // Three-state space meter (requirements §4). Never report trashed
  // space as freed.
  static const String meterToBeFreed = 'meterToBeFreed';
  static const String meterInTrash = 'meterInTrash';
  static const String meterFreed = 'meterFreed';

  // Review.
  static const String reviewDeleteCount = 'reviewDeleteCount';
  static const String reviewEmptyTitle = 'reviewEmptyTitle';
  static const String reviewEmptyMessage = 'reviewEmptyMessage';
  static const String reviewUnmarkHint = 'reviewUnmarkHint';

  // Trash.
  static const String trashEmpty = 'trashEmpty';
  static const String trashEmptyConfirmTitle = 'trashEmptyConfirmTitle';
  static const String trashEmptyConfirmMessage = 'trashEmptyConfirmMessage';
  static const String trashEmptyTitle = 'trashEmptyTitle';
  static const String trashEmptyMessage = 'trashEmptyMessage';
  static const String trashRestoreAll = 'trashRestoreAll';
  static const String trashDeniedMessage = 'trashDeniedMessage';
  static const String trashRowMeta = 'trashRowMeta';

  // History.
  static const String historyEmptyTitle = 'historyEmptyTitle';
  static const String historyEmptyMessage = 'historyEmptyMessage';
  static const String historyRowMeta = 'historyRowMeta';

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

  // Service failures (services return keys, never raw exception text).
  static const String errorMediaPermission = 'errorMediaPermission';
  static const String errorMediaLoad = 'errorMediaLoad';
  static const String errorMediaAlbum = 'errorMediaAlbum';
  static const String errorTrash = 'errorTrash';
  static const String errorTrashUnsupported = 'errorTrashUnsupported';
  static const String errorLocal = 'errorLocal';
  static const String errorStorage = 'errorStorage';
  static const String errorShare = 'errorShare';

  // Scan and session.
  static const String scanNow = 'scanNow';
  static const String scanAgain = 'scanAgain';
  static const String clearFilters = 'clearFilters';
  static const String scanningPhotos = 'scanningPhotos';
  static const String resumeSession = 'resumeSession';

  // Deck filters and finished state (requirements §7, Phase 1 only:
  // month, album/folder, plus All — no smart decks, those are Phase 2).
  static const String filterTitle = 'filterTitle';
  static const String filterAll = 'filterAll';
  static const String deckFinishedTitle = 'deckFinishedTitle';
  static const String deckFinishedMessage = 'deckFinishedMessage';
  static const String meterInTrashEmpty = 'meterInTrashEmpty';
  static const String splashSkipLabel = 'splashSkipLabel';

  // Phase 2A smart decks (requirements §7): hub rows, scanning,
  // duplicates grouping, keeper choice and the similarity slider.
  // No Phase 2B strings (snooze, goals, streaks, On This Day,
  // summary/share, projection) and no Phase 3/4 strings.
  static const String decksTitle = 'decksTitle';
  static const String decksSubtitle = 'decksSubtitle';
  static const String decksReadyToClean = 'decksReadyToClean';
  static const String decksScanning = 'decksScanning';
  static const String decksScanningCount = 'decksScanningCount';
  static const String decksEmpty = 'decksEmpty';
  static const String decksEmptyMessage = 'decksEmptyMessage';
  static const String decksRowCount = 'decksRowCount';
  static const String decksRowScanning = 'decksRowScanning';
  static const String deckScreenshots = 'deckScreenshots';
  static const String deckWhatsapp = 'deckWhatsapp';
  static const String deckCamera = 'deckCamera';
  static const String deckDownloads = 'deckDownloads';
  static const String deckVideos = 'deckVideos';
  static const String deckLarge = 'deckLarge';
  static const String deckOld = 'deckOld';
  static const String deckBursts = 'deckBursts';
  static const String deckBlurry = 'deckBlurry';
  static const String deckDark = 'deckDark';
  static const String deckDuplicates = 'deckDuplicates';
  static const String duplicatesTitle = 'duplicatesTitle';
  static const String duplicatesEmptyTitle = 'duplicatesEmptyTitle';
  static const String duplicatesEmptyMessage = 'duplicatesEmptyMessage';
  static const String duplicatesGroupCount = 'duplicatesGroupCount';
  static const String duplicatesKeeper = 'duplicatesKeeper';
  static const String duplicatesTapToKeep = 'duplicatesTapToKeep';
  static const String duplicatesMarkNonKeepers = 'duplicatesMarkNonKeepers';
  static const String duplicatesShowMore = 'duplicatesShowMore';
  static const String duplicatesSliderLabel = 'duplicatesSliderLabel';
  static const String duplicatesSliderValue = 'duplicatesSliderValue';
  static const String duplicatesSliderHint = 'duplicatesSliderHint';
  static const String smartDeckProgress = 'smartDeckProgress';
  static const String smartDeckFinishedTitle = 'smartDeckFinishedTitle';
  static const String smartDeckFinishedMessage = 'smartDeckFinishedMessage';
  static const String smartDeckEmptyTitle = 'smartDeckEmptyTitle';
  static const String smartDeckEmptyMessage = 'smartDeckEmptyMessage';

  // Phase 2B retention (requirements §7): Maybe snooze, goals,
  // streaks, On This Day, session summary + share, storage
  // projection. No Phase 3/4 strings.
  static const String deckOnThisDay = 'deckOnThisDay';
  static const String retentionProgressTitle = 'retentionProgressTitle';
  static const String retentionGoalLabel = 'retentionGoalLabel';
  static const String retentionGoalProgress = 'retentionGoalProgress';
  static const String retentionGoalReached = 'retentionGoalReached';
  static const String retentionGoalPreset = 'retentionGoalPreset';
  static const String retentionStreak = 'retentionStreak';
  static const String retentionStreakBest = 'retentionStreakBest';
  static const String retentionStreakNone = 'retentionStreakNone';
  static const String retentionMaybeTitle = 'retentionMaybeTitle';
  static const String retentionMaybeEmpty = 'retentionMaybeEmpty';
  static const String retentionMaybeSnoozedUntil = 'retentionMaybeSnoozedUntil';
  static const String retentionSnooze7 = 'retentionSnooze7';
  static const String retentionSnooze14 = 'retentionSnooze14';
  static const String retentionSnooze30 = 'retentionSnooze30';
  static const String retentionClearSnooze = 'retentionClearSnooze';
  static const String retentionMaybeHint = 'retentionMaybeHint';
  static const String retentionProjectionTitle = 'retentionProjectionTitle';
  static const String retentionProjection = 'retentionProjection';
  static const String retentionProjectionLibrary = 'retentionProjectionLibrary';
  static const String retentionProjectionInTrash = 'retentionProjectionInTrash';
  static const String retentionProjectionMarked = 'retentionProjectionMarked';
  static const String timelineTitle = 'timelineTitle';
  static const String timelineTotal = 'timelineTotal';
  static const String seeAllDecks = 'seeAllDecks';
  static const String onThisDayReview = 'onThisDayReview';
  static const String videoBadge = 'videoBadge';
  static const String summaryTitle = 'summaryTitle';
  static const String summaryReviewed = 'summaryReviewed';
  static const String summaryKept = 'summaryKept';
  static const String summaryDeleteMarked = 'summaryDeleteMarked';
  static const String summaryMaybe = 'summaryMaybe';
  static const String summaryFavourite = 'summaryFavourite';
  static const String summaryShare = 'summaryShare';
  static const String summaryShareFailed = 'summaryShareFailed';
  static const String tutorialTitle = 'tutorialTitle';
  static const String tutorialKeep = 'tutorialKeep';
  static const String tutorialDelete = 'tutorialDelete';
  static const String tutorialMaybe = 'tutorialMaybe';
  static const String tutorialFavourite = 'tutorialFavourite';
  static const String tutorialSwipeNote = 'tutorialSwipeNote';
  static const String tutorialDone = 'tutorialDone';

  // Phase 3A settings (requirements §7, Phase 3): theme, private
  // blur, favourites protection, weekly nudge, haptics, reduced
  // motion, trash auto-empty preference, about.
  // Phase 3B (requirements §7, Phase 3): denied/partial polish
  // copy (partial-access actions, mixed native-sheet outcomes) and
  // accessibility labels. No Phase 4 strings (video, documents,
  // iOS, monetization) are added here.
  static const String screenSettings = 'screenSettings';
  static const String settingsSectionDisplay = 'settingsSectionDisplay';
  static const String settingsSectionPrivacy = 'settingsSectionPrivacy';
  static const String settingsSectionFeedback = 'settingsSectionFeedback';
  static const String settingsSectionTrash = 'settingsSectionTrash';
  static const String settingsSectionAbout = 'settingsSectionAbout';
  static const String settingsThemeTitle = 'settingsThemeTitle';
  static const String settingsThemeSystem = 'settingsThemeSystem';
  static const String settingsThemeLight = 'settingsThemeLight';
  static const String settingsThemeDark = 'settingsThemeDark';
  static const String settingsPrivateBlurTitle = 'settingsPrivateBlurTitle';
  static const String settingsPrivateBlurMessage = 'settingsPrivateBlurMessage';
  static const String settingsProtectionTitle = 'settingsProtectionTitle';
  static const String settingsProtectionMessage = 'settingsProtectionMessage';
  static const String settingsNotificationsTitle = 'settingsNotificationsTitle';
  static const String settingsNotificationsMessage =
      'settingsNotificationsMessage';
  static const String settingsNudgeTitle = 'settingsNudgeTitle';
  static const String settingsNudgeBody = 'settingsNudgeBody';
  static const String settingsNotificationsDenied =
      'settingsNotificationsDenied';
  static const String settingsHapticsTitle = 'settingsHapticsTitle';
  static const String settingsHapticsMessage = 'settingsHapticsMessage';
  static const String settingsReducedMotionTitle = 'settingsReducedMotionTitle';
  static const String settingsReducedMotionMessage =
      'settingsReducedMotionMessage';
  static const String settingsAutoEmptyTitle = 'settingsAutoEmptyTitle';
  static const String settingsAutoEmptyMessage = 'settingsAutoEmptyMessage';
  static const String settingsAboutVersion = 'settingsAboutVersion';
  static const String settingsVersionUnknown = 'settingsVersionUnknown';
  static const String settingsTrustNote = 'settingsTrustNote';
  static const String protectionDeckBlocked = 'protectionDeckBlocked';
  static const String protectionReviewExcluded = 'protectionReviewExcluded';
  static const String protectionDuplicatesExcluded =
      'protectionDuplicatesExcluded';
  static const String blurTapToReveal = 'blurTapToReveal';
  static const String blurShowPhotos = 'blurShowPhotos';
  static const String blurHidePhotos = 'blurHidePhotos';
  static const String trashAutoEmptyPromptTitle = 'trashAutoEmptyPromptTitle';
  static const String trashAutoEmptyPromptMessage =
      'trashAutoEmptyPromptMessage';
  static const String errorNotifications = 'errorNotifications';

  // Phase 3B denied/partial polish (requirements §5, §7).
  static const String permissionPartialAddMore = 'permissionPartialAddMore';
  static const String permissionPartialSettingsHint =
      'permissionPartialSettingsHint';
  static const String permissionDeniedSettingsHint =
      'permissionDeniedSettingsHint';
  static const String actionViewTrash = 'actionViewTrash';
  static const String deniedConfirmMixedMessage = 'deniedConfirmMixedMessage';
  static const String snackMovedToTrashMany = 'snackMovedToTrashMany';
  static const String trashRestoreDeniedMixed = 'trashRestoreDeniedMixed';
  static const String trashEmptyDeniedMixed = 'trashEmptyDeniedMixed';

  // Phase 3B accessibility labels (design.md §9): TalkBack labels
  // for controls whose tap target carries no visible text.
  static const String a11yThumbKeeper = 'a11yThumbKeeper';
  static const String a11yThumbKeeperUntitled = 'a11yThumbKeeperUntitled';
  static const String a11yThumb = 'a11yThumb';
  static const String a11yThumbUntitled = 'a11yThumbUntitled';
  static const String a11yReviewTile = 'a11yReviewTile';
  static const String a11yReviewTileUntitled = 'a11yReviewTileUntitled';

  // Phase 4 Android (requirements §7, Phase 4): video compression
  // (preview + keep original until the user confirms) and the
  // document guard (warn before deleting screenshots that look
  // like receipts, IDs, tickets, QR codes). No monetization, iOS,
  // localization or Play-listing strings are added here.
  static const String screenCompress = 'screenCompress';
  static const String compressEmptyTitle = 'compressEmptyTitle';
  static const String compressEmptyMessage = 'compressEmptyMessage';
  static const String compressHint = 'compressHint';
  static const String compressTapHint = 'compressTapHint';
  static const String compressing = 'compressing';
  static const String compressCancel = 'compressCancel';
  static const String compressPreviewTitle = 'compressPreviewTitle';
  static const String compressOriginalLabel = 'compressOriginalLabel';
  static const String compressCompressedLabel = 'compressCompressedLabel';
  static const String compressSaving = 'compressSaving';
  static const String compressNotSmaller = 'compressNotSmaller';
  static const String compressSaveCopy = 'compressSaveCopy';
  static const String compressDiscard = 'compressDiscard';
  static const String compressSaved = 'compressSaved';
  static const String compressOriginalKept = 'compressOriginalKept';
  static const String compressSavedAndKept = 'compressSavedAndKept';
  static const String compressCancelled = 'compressCancelled';
  static const String errorCompress = 'errorCompress';
  static const String errorCompressNotVideo = 'errorCompressNotVideo';
  static const String documentGuardBanner = 'documentGuardBanner';
  static const String documentGuardTitle = 'documentGuardTitle';
  static const String documentGuardMessage = 'documentGuardMessage';
  static const String documentGuardDeleteAnyway = 'documentGuardDeleteAnyway';
  static const String documentGuardKeep = 'documentGuardKeep';
  static const String documentGuardKept = 'documentGuardKept';

  // Confirmations and feedback.
  static const String snackMovedToTrash = 'snackMovedToTrash';
  static const String snackMovedToTrashUntil = 'snackMovedToTrashUntil';
  static const String snackRestored = 'snackRestored';
  static const String snackRestoredMany = 'snackRestoredMany';
  static const String snackTrashEmptied = 'snackTrashEmptied';
  static const String snackUndone = 'snackUndone';

  /// English (v1) values, keyed by the constants above.
  static const Map<String, String> en = <String, String>{
    appTitle: 'Klara',
    screenDeck: 'Clean',
    screenReview: 'Review',
    screenTrash: 'Trash',
    screenHistory: 'History',
    screenDecks: 'Smart decks',
    screenDuplicates: 'Duplicates',
    screenSmartDeck: 'Smart deck',
    navClean: 'Clean',
    navDecks: 'Decks',
    navTrash: 'Trash',
    navSettings: 'Settings',
    decksTitle: 'Smart decks',
    decksSubtitle:
        'Groups Klara found in your library. Open one to swipe through it.',
    decksReadyToClean: 'READY TO CLEAN ({count})',
    decksScanning: 'Scanning your library…',
    decksScanningCount: 'Scanned {count} photos…',
    decksEmpty: 'Nothing found yet',
    decksEmptyMessage:
        'No smart deck has any photos yet. Scan again after adding photos.',
    decksRowCount: '{count} photos · {size}',
    decksRowScanning: 'Still scanning…',
    deckScreenshots: 'Screenshots',
    deckWhatsapp: 'WhatsApp',
    deckCamera: 'Camera',
    deckDownloads: 'Downloads',
    deckVideos: 'Videos',
    deckLarge: 'Large photos',
    deckOld: 'Old photos',
    deckBursts: 'Bursts',
    deckBlurry: 'Blurry photos',
    deckDark: 'Dark photos',
    deckDuplicates: 'Duplicates',
    duplicatesTitle: 'Duplicates',
    duplicatesEmptyTitle: 'No duplicates found',
    duplicatesEmptyMessage:
        'No photos look alike at this similarity level. Try moving the slider.',
    duplicatesGroupCount: '{count} similar photos',
    duplicatesKeeper: 'Keeper',
    duplicatesTapToKeep: 'Tap a photo to make it the keeper.',
    duplicatesMarkNonKeepers: 'Mark others for deletion',
    duplicatesShowMore: 'Show {count} more photos',
    duplicatesSliderLabel: 'Similarity',
    duplicatesSliderValue: 'Distance {value}',
    duplicatesSliderHint: 'Higher values group photos that look less alike. Groups update instantly.',
    smartDeckProgress: '{index} of {count} decided',
    smartDeckFinishedTitle: 'All decided',
    smartDeckFinishedMessage: 'Every photo in this deck has a mark. Review your choices before anything is removed.',
    smartDeckEmptyTitle: 'This deck is empty',
    smartDeckEmptyMessage: 'There are no photos in this deck right now.',
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
    actionAddToAlbum: 'Add to album',
    actionShare: 'Share',
    actionCancel: 'Cancel',
    actionConfirm: 'Confirm',
    actionClose: 'Close',
    actionOk: 'OK',
    actionBackToDeck: 'Back to deck',
    meterToBeFreed: 'To be freed',
    meterInTrash: 'In trash until {date}',
    meterFreed: 'Freed',
    reviewDeleteCount: 'Delete {count} photos',
    reviewEmptyTitle: 'Nothing to review',
    reviewEmptyMessage:
        'Every marked photo is decided. Go back to the deck to keep cleaning.',
    reviewUnmarkHint: 'Tap a photo to remove it from this list.',
    trashEmpty: 'Empty trash',
    trashEmptyConfirmTitle: 'Empty trash?',
    trashEmptyConfirmMessage:
        'Photos in trash will be removed and cannot be restored.',
    trashEmptyTitle: 'Trash is empty',
    trashEmptyMessage: 'Photos you remove stay here for 30 days.',
    trashRestoreAll: 'Restore all',
    trashDeniedMessage:
        'You did not confirm, so those photos are still in trash.',
    trashRowMeta: 'Trashed {trashed} · Recoverable until {until}',
    historyEmptyTitle: 'No history yet',
    historyEmptyMessage: 'Your cleaning history will appear here.',
    historyRowMeta: '{count} photos · Trashed {trashed} · Freed {freed}',
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
    errorMediaPermission: 'Could not check photo access. Try again.',
    errorMediaLoad: 'Could not load your photos. Try again.',
    errorMediaAlbum: 'That album could not be found.',
    errorTrash: 'That trash action did not complete. Try again.',
    errorTrashUnsupported: 'Trash needs Android 11 or newer on this device.',
    errorLocal: 'Could not save or load your cleaning data. Try again.',
    errorStorage:
        'Could not read device storage. Showing library figures instead.',
    errorShare: 'Sharing did not complete. Try again.',
    deckOnThisDay: 'On this day',
    retentionProgressTitle: 'Your progress',
    retentionGoalLabel: 'Weekly goal',
    retentionGoalProgress: '{freed} freed of {target} this week',
    retentionGoalReached: 'Goal reached — nice cleaning!',
    retentionGoalPreset: '{target} per week',
    retentionStreak: '{count}-day streak',
    retentionStreakBest: 'Best: {count} days',
    retentionStreakNone:
        'No streak yet — finish a deck or move photos to trash to start one.',
    retentionMaybeTitle: 'Maybe pile',
    retentionMaybeEmpty: 'No photos waiting for a decision.',
    retentionMaybeSnoozedUntil: 'Snoozed until {date}',
    retentionSnooze7: 'Snooze 7 days',
    retentionSnooze14: 'Snooze 14 days',
    retentionSnooze30: 'Snooze 30 days',
    retentionClearSnooze: 'Clear snooze',
    retentionMaybeHint: 'Snoozed photos stay Maybe and return to the deck when the snooze ends.',
    retentionProjectionTitle: 'Storage projection',
    retentionProjection:
        '{free} free now → {projected} free after emptying trash',
    retentionProjectionLibrary:
        'Library projection (device storage unavailable)',
    retentionProjectionInTrash: '{size} in trash, recoverable',
    retentionProjectionMarked: '{size} marked, to be freed',
    summaryTitle: 'Session summary',
    timelineTitle: 'Timeline',
    timelineTotal: '{size} total',
    seeAllDecks: 'See all ({count}) ›',
    onThisDayReview: '{date} · {count} PHOTOS TO REVIEW',
    videoBadge: 'VIDEO',
    summaryReviewed: '{count} reviewed',
    summaryKept: '{count} kept',
    summaryDeleteMarked: '{count} marked · {size} to be freed',
    summaryMaybe: '{count} maybe',
    summaryFavourite: '{count} favourited',
    summaryShare: 'Share result',
    summaryShareFailed: 'Sharing did not complete. Try again.',
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
    splashSkipLabel: 'Skip splash',
    filterTitle: 'Filters',
    filterAll: 'All photos',
    deckFinishedTitle: 'All decided',
    deckFinishedMessage:
        'Every photo in this filter has a mark. Review your choices '
        'before anything is removed.',
    meterInTrashEmpty: 'In trash',
    screenSettings: 'Settings',
    settingsSectionDisplay: 'Appearance',
    settingsSectionPrivacy: 'Privacy',
    settingsSectionFeedback: 'Feedback',
    settingsSectionTrash: 'Trash',
    settingsSectionAbout: 'About',
    settingsThemeTitle: 'Theme',
    settingsThemeSystem: 'System',
    settingsThemeLight: 'Light',
    settingsThemeDark: 'Dark',
    settingsPrivateBlurTitle: 'Private blur',
    settingsPrivateBlurMessage:
        'Blur thumbnails on Review and Trash until you tap one to '
        'reveal it. The deck is never blurred — it is where you decide.',
    settingsProtectionTitle: 'Protect favourites',
    settingsProtectionMessage:
        'Favourited photos can never be marked for deletion while '
        'this is on — your Klara favourites and photos starred on '
        'the device. There is no reliable edited flag on-device, so '
        'edited photos are not covered by this toggle.',
    settingsNotificationsTitle: 'Weekly nudge',
    settingsNotificationsMessage:
        'One gentle reminder a week to clean up. No countdowns, no '
        'marketing.',
    settingsNudgeTitle: 'Time for a quick clean?',
    settingsNudgeBody:
        'A few swipes can free up space. Open Klara when you have a minute.',
    settingsNotificationsDenied:
        'Notifications are off on this device, so the weekly nudge '
        'could not be set. The toggle stays off.',
    settingsHapticsTitle: 'Haptics',
    settingsHapticsMessage:
        'A light tick on each mark, a medium click when a delete is '
        'confirmed, and a firm pulse when trash is emptied.',
    settingsReducedMotionTitle: 'Reduced motion',
    settingsReducedMotionMessage:
        'When on, animations are replaced with fades even if the '
        'system setting is off. When off, the system setting applies.',
    settingsAutoEmptyTitle: 'Prompt to empty expired trash',
    settingsAutoEmptyMessage:
        'When on, Klara asks before emptying trash whose 30 days '
        'have passed. Nothing is ever deleted without your '
        'confirmation — this only adds a prompt.',
    settingsAboutVersion: 'Version {version}',
    settingsVersionUnknown: 'Version unknown',
    settingsTrustNote:
        'Klara never deletes anything without your confirmation: '
        'swipes only mark, review comes first, and the system '
        'confirmation moves photos to trash for 30 days.',
    protectionDeckBlocked:
        'This photo is favourited and protected, so it cannot be '
        'marked for deletion. Turn off Protect favourites in '
        'Settings to delete it.',
    protectionReviewExcluded:
        '{count} favourited photos were kept out of this delete and '
        'stay in your library.',
    protectionDuplicatesExcluded:
        '{count} favourited photos were kept as keepers instead of '
        'being marked for deletion.',
    blurTapToReveal: 'Tap to reveal',
    blurShowPhotos: 'Show photos',
    blurHidePhotos: 'Hide photos',
    trashAutoEmptyPromptTitle: 'Trash has expired photos',
    trashAutoEmptyPromptMessage:
        'Some photos in trash have passed their 30 days. Emptying '
        'trash now removes everything in trash, including photos '
        'still within their 30 days. Nothing is removed without '
        'the system confirmation that follows.',
    errorNotifications: 'The weekly nudge could not be set. Try again.',
    snackMovedToTrash: 'Moved to trash. You have 30 days to restore.',
    snackMovedToTrashUntil: 'Moved to trash, recoverable until {date}',
    snackMovedToTrashMany: '{count} photos moved to trash. The rest could not be moved — try again.',
    permissionPartialAddMore: 'Add more photos',
    permissionPartialSettingsHint:
        'To see your whole library, open Settings and choose Allow all '
        'photos, then come back and tap Add more photos to reload.',
    permissionDeniedSettingsHint:
        'If Allow access does nothing, photo access was denied for good. '
        'Open Settings to allow it there.',
    actionViewTrash: 'View trash',
    deniedConfirmMixedMessage:
        '{trashed} photos moved to trash, {denied} returned to the deck, '
        'and {failed} could not be moved. The returned photos are back '
        'in your deck, undecided.',
    trashRestoreDeniedMixed:
        '{restored} photos restored. The rest are still in trash because '
        'you did not confirm.',
    trashEmptyDeniedMixed:
        '{size} freed. The rest are still in trash because you did not '
        'confirm.',
    a11yThumbKeeper: '{name}, keeper, tap to keep this photo',
    a11yThumbKeeperUntitled: 'Keeper photo, tap to keep this photo',
    a11yThumb: '{name}, tap to make this photo the keeper',
    a11yThumbUntitled: 'Photo, tap to make this photo the keeper',
    a11yReviewTile: '{name}, tap to remove from review',
    a11yReviewTileUntitled: 'Photo, tap to remove from review',
    screenCompress: 'Compress video',
    compressEmptyTitle: 'No videos found',
    compressEmptyMessage:
        'There are no videos in your library to compress right now.',
    compressHint:
        'Pick one video. Klara makes a smaller copy first and shows '
        'you both sizes — nothing is replaced until you say so.',
    compressTapHint: 'Tap a video to compress it.',
    compressing: 'Compressing… {percent}%',
    compressCancel: 'Cancel compression',
    compressPreviewTitle: 'Compressed copy ready',
    compressOriginalLabel: 'Original: {size}',
    compressCompressedLabel: 'Compressed copy: {size}',
    compressSaving: 'Smaller by {size} — the original stays in your library.',
    compressNotSmaller:
        'The compressed copy is not smaller than the original, so '
        'there is nothing to gain by saving it. Discard it and keep '
        'the original as it is.',
    compressSaveCopy: 'Save compressed copy',
    compressDiscard: 'Discard',
    compressSaved: 'Compressed copy saved to your library.',
    compressOriginalKept:
        'Your original video is still in your library. To remove it, '
        'mark it for deletion and confirm it in Review — it is not '
        'counted as freed until trash is emptied.',
    compressSavedAndKept:
        'Compressed copy saved to your library. Your original video '
        'is still in your library. To remove it, mark it for '
        'deletion and confirm it in Review — it is not counted as '
        'freed until trash is emptied.',
    compressCancelled: 'Compression cancelled. The original is untouched.',
    errorCompress: 'Compression did not complete. The original is untouched.',
    errorCompressNotVideo: 'Only videos can be compressed.',
    documentGuardBanner:
        '{count} photos here look like documents (screenshots, or '
        'filenames like receipts, tickets or IDs). Klara cannot read '
        'what they show — check them before deleting.',
    documentGuardTitle: 'These may be documents',
    documentGuardMessage:
        '{count} photos you marked look like documents — screenshots, '
        'or filenames like receipts, tickets, IDs or QR codes. Klara '
        'cannot read what they show, so check them first. Deleting '
        'them anyway still goes through the system confirmation and '
        'they stay recoverable in trash for 30 days.',
    documentGuardDeleteAnyway: 'Delete anyway',
    documentGuardKeep: 'Keep these documents',
    documentGuardKept:
        '{count} document-like photos were kept and removed from this list.',
    snackRestored: 'Photo restored',
    snackRestoredMany: '{count} photos restored',
    snackTrashEmptied: 'Trash emptied. {size} freed.',
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
