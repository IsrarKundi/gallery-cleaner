import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../features/deck/binding/deck_binding.dart';
import '../../features/decks/binding/decks_binding.dart';
import '../../features/decks/binding/duplicates_binding.dart';
import '../../features/decks/binding/smart_deck_binding.dart';
import '../../features/decks/view/decks_view.dart';
import '../../features/decks/view/duplicates_view.dart';
import '../../features/decks/view/smart_deck_view.dart';
import '../../features/history/binding/history_binding.dart';
import '../../features/history/view/history_view.dart';
import '../../features/review/binding/review_binding.dart';
import '../../features/review/view/review_view.dart';
import '../../features/settings/binding/settings_binding.dart';
import '../../features/settings/view/settings_view.dart';
import '../../features/splash/binding/splash_binding.dart';
import '../../features/splash/view/splash_view.dart';
import '../../features/compress/binding/compress_binding.dart';
import '../../features/compress/view/compress_view.dart';
import '../../features/deck/view/deck_view.dart';
import '../../features/trash/binding/trash_binding.dart';
import '../../features/trash/view/trash_view.dart';

/// GetPage wiring (AGENTS.md: named routes only).
///
/// Phase 1 screens: splash, deck, review, trash and history. Review
/// receives the delete-marked list as route arguments plus the deck
/// filter key as a route parameter; Trash optionally receives the
/// recoverable-until date as route arguments for its arrival snackbar.
class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: SplashView.new,
      binding: SplashBinding(
        onComplete: () => Get.offAllNamed<dynamic>(AppRoutes.deck),
      ),
    ),
    GetPage<dynamic>(
      name: AppRoutes.deck,
      page: DeckView.new,
      binding: DeckBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.review,
      page: ReviewView.new,
      binding: ReviewBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trash,
      page: TrashView.new,
      binding: TrashBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.history,
      page: HistoryView.new,
      binding: HistoryBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.decks,
      page: DecksView.new,
      binding: DecksBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.duplicates,
      page: DuplicatesView.new,
      binding: DuplicatesBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.smartDeck,
      page: SmartDeckView.new,
      binding: SmartDeckBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settings,
      page: SettingsView.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.compress,
      page: CompressView.new,
      binding: CompressBinding(),
    ),
  ];
}
