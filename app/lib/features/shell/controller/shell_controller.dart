import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_service.dart';
import '../../deck/controller/deck_controller.dart';
import '../../decks/controller/smart_deck_controller.dart';
import '../../review/controller/review_union.dart';

/// Bottom-nav shell state (solutions 7.1): the shell keeps the deck,
/// hub and settings tabs alive across tab switches (F-26), instead
/// of destroying and re-creating the destination on every tap.
///
/// Tab model: the nav bar has 4 destinations (Clean, Decks, Trash,
/// Settings) but only 3 retained stack children — Trash is an
/// ACTION, not a tab: tapping it pushes a fresh Review route on
/// top of the retained shell. Review is still fresh on every open
/// (a new binding runs each time), so it can never go stale — but
/// the shell underneath is never destroyed, so returning from
/// Review pops back to the exact tab state instead of rebuilding
/// every tab (see ADR-009). The Trash screen reached from Review
/// likewise pushes on top of the shell and pops back to it (see
/// ADR-011). The stack index maps nav index 3 (Settings) to
/// stack index 2.
///
/// Composition exception (AGENTS.md): this controller coordinates
/// tabs, so it imports [DeckController] the way AppPages imports
/// feature bindings — the shell owns no feature state itself, it
/// only asks the deck whether a card exit is in flight. See ADR-007.
class ShellController extends GetxController {
  ShellController({int initialNavIndex = 0, this.local, this.media})
    : initialNavIndex = _validatedNav(initialNavIndex),
      navIndex = _validatedNav(initialNavIndex).obs,
      visitedStacks = <int>{stackIndexForNav(_validatedNav(initialNavIndex))};

  final LocalService? local;
  final MediaService? media;

  /// Validates an initial tab: only Clean, Decks and Settings are
  /// tabs (Trash is an action, never an initial tab).
  static int _validatedNav(int nav) => (nav == 1 || nav == 3) ? nav : 0;

  /// Maps a nav destination to its IndexedStack child: Clean → 0,
  /// Decks → 1, Settings → 2.
  static int stackIndexForNav(int navIndex) => navIndex == 3 ? 2 : navIndex;

  /// First nav tab (0, 1 or 3). Defaults to Clean.
  final int initialNavIndex;

  /// Current nav destination (0, 1 or 3; never 2).
  final RxInt navIndex;

  /// Stack children built so far. Tabs build lazily on first visit
  /// and stay mounted afterwards (IndexedStack retention).
  final Set<int> visitedStacks;

  /// Current IndexedStack child index.
  int get stackIndex => stackIndexForNav(navIndex.value);

  /// App-exit guard prompt state (ADR-016 addendum): true while
  /// the view's "Before you go…" confirmation is on screen, so a
  /// second back press cannot stack a second prompt on top of it.
  bool exitPromptOpen = false;

  /// True once the stack child has been built (and so is retained).
  bool isTabVisited(int stackIndex) => visitedStacks.contains(stackIndex);

  /// Handles a bottom-nav tap. Retained tabs switch in place (no
  /// reload, no re-scan); Trash pushes a fresh Review route.
  void selectTab(int nav) {
    if (nav == 2) {
      _openReview();
      return;
    }
    if (nav != 0 && nav != 1 && nav != 3) {
      return;
    }
    if (nav == navIndex.value) {
      return;
    }
    visitedStacks.add(stackIndexForNav(nav));
    navIndex.value = nav;
  }

  /// Opens Review for the bottom-nav Trash tab, deferred through
  /// the deck's settled-review gate when a card exit is in flight:
  /// the mark records first (see DeckController.runAfterCardExit),
  /// so Review never opens with the in-flight mark missing. When
  /// the deck was never visited no exit can be in flight.
  void _openReview() {
    if (visitedStacks.contains(0)) {
      try {
        Get.find<DeckController>().runAfterCardExit(_pushReview);
        return;
      } catch (_) {
        // Deck visited but unresolvable (should not happen): fall
        // through to plain navigation rather than stranding the tap.
      }
    }
    _pushReview();
  }

  /// Pushes a fresh Review route on top of the retained shell —
  /// never off-all: destroying the shell here is what rebuilt
  /// every tab on the way back from Trash (ADR-009). A second
  /// Trash tap while Review is already on top is a no-op, so a
  /// fast double tap never stacks Review twice. Review itself
  /// stays fresh — a new binding runs on every open — so pushing
  /// it cannot show a stale delete set.
  ///
  /// The current delete set travels as route arguments (same as
  /// the deck's own go-to-review), so Review renders its count,
  /// buttons and tiles on the first frame instead of flashing the
  /// loading skeleton while it re-resolves the set from the
  /// session (ADR-012). The arguments are read here, at push
  /// time — after the settled-review gate releases — so a mark
  /// recorded during a gated wait is included. When the deck is
  /// unresolvable the plain push stands and Review falls back to
  /// the session path, skeleton included, as before.
  Future<void> _pushReview() async {
    if (Get.currentRoute == AppRoutes.review) {
      return;
    }
    try {
      final ReviewLaunch launch = await _buildUnion();

      Get.toNamed<dynamic>(
        AppRoutes.review,
        arguments: launch,
        parameters: <String, String>{'filterKey': 'union'},
      );
    } catch (_) {
      Get.toNamed<dynamic>(AppRoutes.review);
    }
  }

  /// Builds the Trash tab's union (ADR-015) from the injected
  /// services plus the live deck controllers when they are
  /// registered — the one resolution [_pushReview] and the exit
  /// guard's count share, so both always name the same set.
  Future<ReviewLaunch> _buildUnion() async {
    final LocalService localService = local ?? Get.find<LocalService>();
    final MediaService mediaService = media ?? Get.find<MediaService>();
    final DeckController? deck = Get.isRegistered<DeckController>()
        ? Get.find<DeckController>()
        : null;
    final SmartDeckController? smart = Get.isRegistered<SmartDeckController>()
        ? Get.find<SmartDeckController>()
        : null;
    return buildReviewUnion(
      local: localService,
      media: mediaService,
      deck: deck,
      liveSmartDeck: smart,
    );
  }

  /// How many items are waiting in Trash right now: the size of
  /// the ADR-015 union — exactly what opening the Trash tab
  /// would show (Clean-deck delete marks plus `smart:`-family
  /// delete marks; the `duplicates` session never joins the
  /// union). This is the same waiting set the reminder engine's
  /// state 1 mirrors (ADR-016 §1). A failed read counts as zero:
  /// the exit guard must never trap the user in the app over a
  /// count it could not read.
  Future<int> waitingInTrashCount() async {
    try {
      final ReviewLaunch launch = await _buildUnion();
      return launch.assets.length;
    } catch (_) {
      return 0;
    }
  }

  /// Exits the app. The shell is the root route, so the system
  /// navigator pop IS the exit; kept as one seam so the view's
  /// exit guard and its tests share the exact action.
  Future<void> exitApp() => SystemNavigator.pop();
}
