// Delete-moment celebration tests (ADR-024): the hop between
// a completed delete batch and the finish screen. The batch
// argument travels untouched; the animation plays once when
// motion is on; reduced motion — and a failed asset load —
// go straight to the finish screen, because decoration never
// blocks the landing. The Stage 5 delete-place review ask
// still presents from the finish screen after the hop.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:klara/core/routes/app_routes.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/celebration/binding/celebration_binding.dart';
import 'package:klara/features/celebration/view/celebration_view.dart';
import 'package:klara/features/finish/binding/finish_binding.dart';
import 'package:klara/features/finish/model/finish_summary.dart';
import 'package:klara/features/finish/view/finish_view.dart';
import 'package:klara/services/review_ask/review_ask.dart';
import 'package:klara/services/review_ask/review_ask_service.dart';

class _AskService extends Fake implements ReviewAskService {
  bool due = false;
  final List<ReviewAskPlace> shown = <ReviewAskPlace>[];

  @override
  Future<bool> isDue(ReviewAskPlace place) async => due;

  @override
  Future<void> markShown(ReviewAskPlace place) async {
    shown.add(place);
  }

  @override
  Future<void> markDismissed(ReviewAskPlace place) async {}

  @override
  Future<void> answerWithReview() async {}

  @override
  Future<int> fallbackAmountBytes() async => 0;
}

/// An asset bundle that serves everything except the
/// celebration Lottie, to prove a load failure still lands on
/// the finish screen.
class _NoCelebrationBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == CelebrationView.celebrationAsset) {
      throw FlutterError('celebration asset unavailable in this test');
    }
    return rootBundle.load(key);
  }
}

const FinishSummary _summary = FinishSummary(
  deletedCount: 128,
  sizeBytes: 1258291, // 1.2 MB
  spaceState: FinishSpaceState.freed,
);

Future<void> _pumpApp(
  WidgetTester tester, {
  bool reducedMotion = false,
  AssetBundle? bundle,
}) async {
  Widget app = GetMaterialApp(
    theme: AppTheme.light,
    initialRoute: '/',
    // Reduced motion is injected the way main.dart's builder
    // does it in the real app (from the persisted setting), so
    // the routes actually inherit it.
    builder: reducedMotion
        ? (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          )
        : null,
    getPages: <GetPage<dynamic>>[
      GetPage<dynamic>(
        name: '/',
        page: () => const Scaffold(body: Text('deck-dummy')),
      ),
      GetPage<dynamic>(
        name: AppRoutes.celebration,
        page: CelebrationView.new,
        binding: CelebrationBinding(),
      ),
      GetPage<dynamic>(
        name: AppRoutes.finish,
        page: FinishView.new,
        binding: FinishBinding(),
      ),
    ],
  );
  if (bundle != null) {
    app = DefaultAssetBundle(bundle: bundle, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  test('the bundled celebration asset parses as the approved '
      'composition (2 s, 500x500)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ByteData data = await rootBundle.load(
      CelebrationView.celebrationAsset,
    );
    final LottieComposition composition = await LottieComposition.fromByteData(
      data,
    );
    expect(composition.duration, const Duration(seconds: 2));
    expect(composition.bounds.width, 500);
    expect(composition.bounds.height, 500);
  });

  group('CelebrationView hop', () {
    testWidgets('plays once, then lands on the finish screen '
        'with the same summary', (WidgetTester tester) async {
      await _pumpApp(tester);
      // Mirrors ReviewView's whole-set delete branch (ADR-020
      // decision 1 via the ADR-024 hop).
      Get.offNamed<dynamic>(AppRoutes.celebration, arguments: _summary);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The celebration is up; the finish screen is not yet.
      expect(find.byType(CelebrationView), findsOneWidget);
      expect(find.text('Congratulations!'), findsNothing);

      // The composition plays out (2 s) and hands over.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('128 photos'), findsOneWidget);
      expect(find.text('Freed from your storage'), findsOneWidget);

      // Done leaves the whole hop behind: the celebration
      // removed itself when the finish screen popped.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('deck-dummy'), findsOneWidget);
      expect(find.byType(CelebrationView), findsNothing);
      expect(Get.currentRoute, '/');
    });

    testWidgets('the delete-place review ask still presents '
        'from the finish screen after the hop', (WidgetTester tester) async {
      final _AskService ask = _AskService()..due = true;
      Get.put<ReviewAskService>(ask);
      await _pumpApp(tester);
      Get.offNamed<dynamic>(AppRoutes.celebration, arguments: _summary);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(ask.shown, <ReviewAskPlace>[ReviewAskPlace.delete]);
      expect(find.text('You just freed up 1.2 MB'), findsOneWidget);
    });

    testWidgets('reduced motion goes straight to the finish '
        'screen, no 2 s wait', (WidgetTester tester) async {
      await _pumpApp(tester, reducedMotion: true);
      Get.offNamed<dynamic>(AppRoutes.celebration, arguments: _summary);
      // Two route transitions plus the skip need a few frames;
      // the proof is WHEN the finish screen appears: had the
      // 2 s animation played first, it could not be up within
      // 1.2 s of fake time.
      int elapsedMs = 0;
      while (elapsedMs <= 1200 &&
          find.text('Congratulations!').evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 100));
        elapsedMs += 100;
      }
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(elapsedMs, lessThanOrEqualTo(1200));
      expect(find.text('Freed from your storage'), findsOneWidget);
    });

    testWidgets('a failed asset load still lands on the finish '
        'screen', (WidgetTester tester) async {
      await _pumpApp(tester, bundle: _NoCelebrationBundle());
      Get.offNamed<dynamic>(AppRoutes.celebration, arguments: _summary);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('128 photos'), findsOneWidget);
    });
  });
}
