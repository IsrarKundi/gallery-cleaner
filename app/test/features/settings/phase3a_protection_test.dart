// Phase 3A protection tests (requirements §7, Phase 3): favourites
// protection enforced at every delete-marking point — deck,
// smart deck, duplicates non-keeper marking, review — plus the
// trash auto-empty prompt and its record-only cleanup.
//
// Settings/sessions use the real [LocalServiceImpl] with a temp
// directory, so protection reads the same persisted record the
// Settings screen writes. Media/trash are small fakes.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/utils/app_haptics.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/deck/controller/deck_controller.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/controller/smart_deck_controller.dart';
import 'package:klara/features/decks/model/smart_deck_launch.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

MediaAsset _asset(String id, {bool systemFavourite = false}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
    isSystemFavourite: systemFavourite,
  );
}

TrashEntry _entry(String id, DateTime trashedAt) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    trashedAt: trashedAt,
  );
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

  _Media(this.assets);

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
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Trash implements TrashService {
  List<String> trashCalls = <String>[];
  List<String> deleteCalls = <String>[];
  bool emptyCalled = false;
  List<TrashEntry> listed = <TrashEntry>[];

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) async {
    deleteCalls = ids;
    return Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<TrashOutcome>> trashAssets(List<String> ids) async {
    trashCalls = ids;
    return Success<TrashOutcome>(
      TrashOutcome(
        trashedIds: ids,
        deniedIds: const <String>[],
        failedIds: const <String>[],
      ),
    );
  }

  @override
  Future<Result<RestoreOutcome>> restoreAssets(List<String> ids) async {
    return const Success<RestoreOutcome>(
      RestoreOutcome(
        restoredIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return Success<List<TrashEntry>>(listed);
  }

  @override
  Future<Result<EmptyTrashOutcome>> emptyTrash() async {
    emptyCalled = true;
    return const Success<EmptyTrashOutcome>(
      EmptyTrashOutcome(
        removedIds: <String>[],
        deniedIds: <String>[],
        failedIds: <String>[],
      ),
    );
  }
}

Future<LocalServiceImpl> _tempLocal() async {
  final Directory dir = await Directory.systemTemp.createTemp('klara3b');
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  return LocalServiceImpl(directoryResolver: () async => dir);
}

/// Phase 2.5: same settle rule as the deck unit tests — a mark on
/// a not-yet-visible card is refused, so tests wait for the current
/// card's thumbnail before marking.
Future<void> _settleThumbnails(DeckController controller) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (true) {
    final String? id = controller.currentAsset?.id;
    if (id == null || controller.thumbnails.containsKey(id)) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the current thumbnail');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _settleSmartThumbnails(SmartDeckController controller) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (true) {
    final String? id = controller.currentAsset?.id;
    if (id == null || controller.thumbnails.containsKey(id)) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the current thumbnail');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
    AppHaptics.enabled = true;
  });

  group('deck protection', () {
    test(
      'delete on a Klara favourite is blocked with an explanation',
      () async {
        final LocalServiceImpl local = await _tempLocal();
        await local.saveSettings(const AppSettings(protection: true));
        await local.saveSession(
          const DeckSession(
            filterKey: 'all',
            currentIndex: 0,
            marks: <String, DeckMark>{},
            favouriteIds: <String>{'fav'},
          ),
        );
        final DeckController controller = DeckController(
          media: _Media(<MediaAsset>[
            _asset('plain'),
            _asset('fav'),
            _asset('sys', systemFavourite: true),
          ]),
          trash: _Trash(),
          local: local,
        );
        await controller.init();
        await _settleThumbnails(controller);
        await controller.markCurrent(DeckMark.delete);
        expect(controller.marks['plain'], DeckMark.delete);
        await _settleThumbnails(controller);
        await controller.markCurrent(DeckMark.delete);
        expect(controller.marks.containsKey('fav'), isFalse);
        expect(controller.currentAsset?.id, 'fav');
        expect(controller.protection.blockedKey.value, isNotEmpty);
        await _settleThumbnails(controller);
        controller.markCurrent(DeckMark.keep);
        expect(controller.protection.blockedKey.value, isEmpty);
        await _settleThumbnails(controller);
        await controller.markCurrent(DeckMark.delete);
        expect(controller.marks.containsKey('sys'), isFalse);
        expect(controller.protection.blockedKey.value, isNotEmpty);
      },
    );

    test('protection off leaves delete marks working', () async {
      final LocalServiceImpl local = await _tempLocal();
      final DeckController controller = DeckController(
        media: _Media(<MediaAsset>[_asset('fav')]),
        trash: _Trash(),
        local: local,
      );
      await controller.init();
      await _settleThumbnails(controller);
      await controller.markCurrent(DeckMark.delete);
      expect(controller.marks['fav'], DeckMark.delete);
    });
  });

  group('smart-deck protection', () {
    test('delete on a system favourite is blocked', () async {
      final LocalServiceImpl local = await _tempLocal();
      await local.saveSettings(const AppSettings(protection: true));
      final SmartDeckController controller = SmartDeckController(
        media: _Media(<MediaAsset>[]),
        local: local,
        initialLaunch: SmartDeckLaunch(
          deckId: SmartDeckId.screenshots,
          assets: <MediaAsset>[_asset('sys', systemFavourite: true)],
        ),
      );
      controller.onInit();
      for (int i = 0; i < 50 && !controller.ready.value; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.ready.value, isTrue);
      await _settleSmartThumbnails(controller);
      controller.markCurrent(DeckMark.delete);
      expect(controller.marks.containsKey('sys'), isFalse);
      expect(controller.protection.blockedKey.value, isNotEmpty);
      expect(controller.currentAsset?.id, 'sys');
    });
  });

  group('duplicates protection', () {
    PhotoAnalysis analysis(String id, int hash) {
      return PhotoAnalysis(
        assetId: id,
        hash: hash,
        width: 10,
        height: 10,
        blurScore: id == 'a' ? 900 : 10,
        meanLuminance: 128,
      );
    }

    Future<DuplicatesController> make(bool protectionOn) async {
      final LocalServiceImpl local = await _tempLocal();
      await local.saveAnalyses(<PhotoAnalysis>[
        analysis('a', 0),
        analysis('b', 0),
        analysis('c', 63),
      ]);
      if (protectionOn) {
        await local.saveSettings(const AppSettings(protection: true));
        await local.saveSession(
          const DeckSession(
            filterKey: 'other',
            currentIndex: 0,
            marks: <String, DeckMark>{},
            favouriteIds: <String>{'b'},
          ),
        );
      }
      final DuplicatesController controller = DuplicatesController(
        media: _Media(<MediaAsset>[_asset('a'), _asset('b'), _asset('c')]),
        local: local,
      );
      await controller.init();
      return controller;
    }

    test('favourited non-keeper stays keeper-protected, not deleted', () async {
      final DuplicatesController controller = await make(true);
      expect(controller.groups.length, 1);
      expect(controller.groups.first.keeperId, 'a');
      await controller.markNonKeepers(0);
      expect(controller.protectedExcludedCount.value, 1);
      final DeckSession? saved = (await controller.local.loadSession(
        DuplicatesController.sessionKey,
      )).fold(onSuccess: (DeckSession? value) => value, onFailure: (_) => null);
      expect(saved?.marks['b'], DeckMark.keep);
      expect(saved?.marks['a'], DeckMark.keep);
    });

    test('protection off marks the non-keeper delete', () async {
      final DuplicatesController controller = await make(false);
      // Navigation needs a GetMaterialApp (covered by the widget
      // test); the session write happens before navigation, so a
      // navigation error here must not mask the mark assertions.
      try {
        await controller.markNonKeepers(0);
      } catch (_) {}
      expect(controller.protectedExcludedCount.value, 0);
      final DeckSession? saved = (await controller.local.loadSession(
        DuplicatesController.sessionKey,
      )).fold(onSuccess: (DeckSession? value) => value, onFailure: (_) => null);
      expect(saved?.marks['b'], DeckMark.delete);
    });
  });

  group('review protection', () {
    test('delete excludes Klara favourites and system favourites', () async {
      final LocalServiceImpl local = await _tempLocal();
      await local.saveSettings(const AppSettings(protection: true));
      await local.saveSession(
        const DeckSession(
          filterKey: 'all',
          currentIndex: 0,
          marks: <String, DeckMark>{
            'fav': DeckMark.delete,
            'sys': DeckMark.delete,
            'plain': DeckMark.delete,
          },
          favouriteIds: <String>{'fav'},
        ),
      );
      final _Trash trash = _Trash();
      final ReviewController controller = ReviewController(
        media: _Media(<MediaAsset>[]),
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[
          _asset('fav'),
          _asset('sys', systemFavourite: true),
          _asset('plain'),
        ],
        filterKeyOverride: 'all',
      );
      controller.onInit();
      final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
      expect(outcome, ReviewDeleteOutcome.deleted);
      expect(trash.deleteCalls, <String>['plain']);
      expect(controller.items.map((MediaAsset a) => a.id).toList(), <String>[
        'fav',
        'sys',
      ]);
      expect(controller.protectedExcludedCount.value, 2);
    });

    test('all protected means no trash call and no native sheet', () async {
      final LocalServiceImpl local = await _tempLocal();
      await local.saveSettings(const AppSettings(protection: true));
      final _Trash trash = _Trash();
      final ReviewController controller = ReviewController(
        media: _Media(<MediaAsset>[]),
        trash: trash,
        local: local,
        initialAssets: <MediaAsset>[_asset('sys', systemFavourite: true)],
        filterKeyOverride: 'all',
      );
      controller.onInit();
      expect(await controller.deleteSelected(), isNull);
      expect(trash.deleteCalls, isEmpty);
      expect(controller.items.length, 1);
    });
  });

  group('trash auto-empty prompt', () {
    test(
      'setting on + expired record prompts, decline cleans records only',
      () async {
        final LocalServiceImpl local = await _tempLocal();
        await local.saveSettings(const AppSettings(trashAutoEmptyPrompt: true));
        await local.recordTrashed(<TrashEntry>[
          _entry('old', DateTime.now().subtract(const Duration(days: 40))),
        ]);
        final _Trash trash = _Trash()
          ..listed = <TrashEntry>[
            _entry('old', DateTime.now().subtract(const Duration(days: 40))),
            _entry('new', DateTime.now()),
          ];
        final TrashController controller = TrashController(
          trash: trash,
          local: local,
        );
        await controller.init();
        expect(controller.expiredCount.value, 1);
        expect(controller.autoEmptyPromptPending.value, isTrue);
        await controller.cleanupExpiredRecords();
        expect(trash.emptyCalled, isFalse);
        final List<TrashEntry> remaining = (await local.loadTrashEntries())
            .fold(
              onSuccess: (List<TrashEntry> value) => value,
              onFailure: (_) => <TrashEntry>[],
            );
        expect(remaining, isEmpty);
      },
    );

    test('setting off leaves expired records without a prompt', () async {
      final LocalServiceImpl local = await _tempLocal();
      final _Trash trash = _Trash()
        ..listed = <TrashEntry>[
          _entry('old', DateTime.now().subtract(const Duration(days: 40))),
        ];
      final TrashController controller = TrashController(
        trash: trash,
        local: local,
      );
      await controller.init();
      expect(controller.expiredCount.value, 1);
      expect(controller.autoEmptyPromptPending.value, isFalse);
    });
  });
}
