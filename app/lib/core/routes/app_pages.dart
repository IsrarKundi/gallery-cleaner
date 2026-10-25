import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../features/deck/binding/deck_binding.dart';
import '../../features/splash/binding/splash_binding.dart';
import '../../features/splash/view/splash_view.dart';
import '../../features/deck/view/deck_view.dart';

/// GetPage wiring (AGENTS.md: named routes only).
///
/// Only splash and deck are wired. Review, trash and history pages do
/// not exist yet and are deliberately NOT wired with placeholders —
/// navigating to '/review' from the deck 404s until the review
/// increment wires it, which is expected, not papered over.
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
  ];
}
