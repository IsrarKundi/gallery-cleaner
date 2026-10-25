// Hub + smart-deck widget tests (requirements §7, Phase 2A):
// rows render with counts, tapping a deck opens its swipe deck,
// and the duplicates screen groups, re-keeps and navigates to
// review with the non-keeper list.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/decks/binding/decks_binding.dart';
import 'package:klara/features/decks/binding/duplicates_binding.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/binding/smart_deck_binding.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/decks/view/decks_view.dart';
import 'package:klara/features/decks/view/duplicates_view.dart';
import 'package:klara/features/decks/view/smart_deck_view.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(
  String id, {
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
  );
}

Uint8List _png() {
  final img.Image image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

class _Media implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  _Media({List<MediaAsset>? assets})
    : assets =
          assets ??
          <MediaAsset>[
            _asset('shot', album: 'Screenshots'),
            _asset('cam', album: 'Camera'),
          ];

  final List<MediaAsset> assets;

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: assets.length),
    ]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (page > 0) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    return Success<List<MediaAsset>>(assets);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(String assetId, int size) async {
    return Success<Uint8List>(_png());
  }
}

class _Local implements LocalService {
  _Local({Map<String, PhotoAnalysis>? analyses})
    : analyses = analyses ?? <String, PhotoAnalysis>{};

  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  final Map<String, PhotoAnalysis> analyses;

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async {
    return const Success<Map<String, DateTime>>(<String, DateTime>{});
  }

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<double>> loadGoalTargetMb() async {
    return const Success<double>(1024);
  }

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async {
    return const Success<List<DateTime>>(<DateTime>[]);
  }

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async {
    return const Success<List<TrashEntry>>(<TrashEntry>[]);
  }

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clearTrashEntries() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async {
    return const Success<List<HistoryRecord>>(<HistoryRecord>[]);
  }

  @override
  Future<Result<bool>> isTutorialSeen() async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> list) async {
    for (final PhotoAnalysis a in list) {
      analyses[a.assetId] = a;
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return Success<Map<String, PhotoAnalysis>>(
      Map<String, PhotoAnalysis>.of(analyses),
    );
  }
}

PhotoAnalysis _analysis(String id, int hash, double blur) {
  return PhotoAnalysis(
    assetId: id,
    hash: hash,
    width: 10,
    height: 10,
    blurScore: blur,
    meanLuminance: 128,
  );
}

void main() {
  tearDown(Get.reset);

  group('hub view', () {
    testWidgets('rows render and tapping a deck opens its swipe deck', (
      WidgetTester tester,
    ) async {
      Get.put<MediaService>(_Media());
      Get.put<LocalService>(_Local());
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          initialRoute: '/decks',
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: '/decks',
              page: DecksView.new,
              binding: DecksBinding(),
            ),
            GetPage<dynamic>(
              name: '/smart-deck',
              page: SmartDeckView.new,
              binding: SmartDeckBinding(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Screenshots'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      await tester.tap(find.text('Screenshots'));
      await tester.pumpAndSettle();
      // Smart-deck screen: same title, progress line, action bar.
      expect(find.text('0 of 1 decided'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
    });
  });

  group('duplicates view', () {
    Future<void> pumpDuplicates(WidgetTester tester) async {
      Get.put<MediaService>(
        _Media(assets: <MediaAsset>[_asset('a'), _asset('b'), _asset('c')]),
      );
      Get.put<LocalService>(
        _Local(
          analyses: <String, PhotoAnalysis>{
            'a': _analysis('a', 0, 900),
            'b': _analysis('b', 0, 10),
            'c': _analysis('c', 63, 500),
          },
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          initialRoute: '/duplicates',
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: '/duplicates',
              page: DuplicatesView.new,
              binding: DuplicatesBinding(),
            ),
            GetPage<dynamic>(
              name: '/review',
              page: () => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext context) {
                      final dynamic args = Get.arguments;
                      final int count = args is List ? args.length : -1;
                      return Text('Review $count');
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('group renders, keeper tap changes keeper', (
      WidgetTester tester,
    ) async {
      await pumpDuplicates(tester);
      expect(find.text('2 similar photos'), findsOneWidget);
      expect(find.text('Keeper'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // Second thumbnail is 'b': tapping it makes 'b' the keeper.
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Keeper'), findsOneWidget);
      expect(Get.find<DuplicatesController>().groups.first.keeperId, 'b');
    });

    testWidgets('mark non-keepers navigates to review with one photo', (
      WidgetTester tester,
    ) async {
      await pumpDuplicates(tester);
      await tester.tap(find.text('Mark others for deletion'));
      await tester.pumpAndSettle();
      expect(find.text('Review 1'), findsOneWidget);
    });
  });

  group('smart deck view', () {
    testWidgets('Keep button advances and Undo returns', (
      WidgetTester tester,
    ) async {
      final SmartDeckController controller = SmartDeckController(
        media: _Media(),
        local: _Local(),
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[_asset('shot'), _asset('cam')],
        ),
      );
      Get.put<SmartDeckController>(controller);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.light, home: const SmartDeckView()),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 decided'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 decided'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 decided'), findsOneWidget);
    });
  });
}
