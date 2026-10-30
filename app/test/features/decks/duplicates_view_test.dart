// Duplicates screen widget tests (fix plan Stage 7, ADR-022):
// the summary totals, group headers, keeper pill, selection
// marks, live bottom-bar totals, select/deselect all, and the
// mark action writing exactly the selected ids to the
// `duplicates` session before opening Review. The screen itself
// deletes nothing — removal stays with Review + the native
// confirmation (requirements §4).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/formatters.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/core/widgets/primary_button.dart';
import 'package:klara/features/decks/binding/duplicates_binding.dart';
import 'package:klara/features/decks/controller/duplicates_controller.dart';
import 'package:klara/features/decks/model/decks_status.dart';
import 'package:klara/features/decks/view/duplicates_view.dart';
import 'package:klara/features/decks/widgets/duplicate_group_card.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _asset(String id, {int sizeBytes = 1000}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: sizeBytes,
    createDate: DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

Uint8List _png(int shade) {
  final img.Image image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(shade, shade, shade));
  return Uint8List.fromList(img.encodePng(image));
}

/// Two exact-duplicate groups: a/b share the dark PNG and every
/// fact (1000 B each); d/e share the white PNG (2000 B each).
/// The size difference alone puts them in different exact-key
/// buckets, so the groups are independent.
class _Media implements MediaService {
  @override
  Future<Result<void>> presentLimitedSelection() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> openAppSettings() async {
    return const Success<void>(null);
  }

  @override
  Future<Result<MediaPermission>> requestPermission() async {
    return const Success<MediaPermission>(MediaPermission.grantedFull);
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[
      MediaAlbum(id: 'all', name: 'Recent', count: 4),
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
    return Success<List<MediaAsset>>(<MediaAsset>[
      _asset('a'),
      _asset('b'),
      _asset('d', sizeBytes: 2000),
      _asset('e', sizeBytes: 2000),
    ]);
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    final bool dark = assetId == 'a' || assetId == 'b';
    return Success<Uint8List>(_png(dark ? 5 : 250));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }
}

class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};
  int trashedRecords = 0;

  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

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
    return Success<List<DeckSession>>(sessions.values.toList());
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
  Future<Result<void>> clearSnoozes(List<String> ids) async {
    return const Success<void>(null);
  }

  @override
  Future<void> flushPendingWrites() async {}

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
    trashedRecords += entries.length;
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
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async {
    return const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
  }
}

/// The shared scan hops worker isolates; waiting interleaves fake
/// pumps with real delays, bounded (same helper shape as the hub
/// tests) so a broken scan fails the expects instead of hanging.
Future<void> _waitForScan(WidgetTester tester, bool Function() done) async {
  int rounds = 0;
  while (!done() && rounds < 100) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    rounds++;
  }
}

void main() {
  tearDown(Get.reset);

  Future<_Local> pumpDuplicates(WidgetTester tester) async {
    // Tall surface: both group cards and every mark stay visible,
    // so taps never need scrolling.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final _Local local = _Local();
    Get.put<MediaService>(_Media());
    Get.put<LocalService>(local);
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
    final DuplicatesController controller = Get.find<DuplicatesController>();
    await _waitForScan(
      tester,
      () => controller.status.value == DecksStatus.ready,
    );
    await tester.pumpAndSettle();
    return local;
  }

  testWidgets('summary, group headers, keeper pills and marks render', (
    WidgetTester tester,
  ) async {
    await pumpDuplicates(tester);
    final DuplicatesController controller = Get.find<DuplicatesController>();
    expect(controller.groups.length, 2);
    // Summary: the non-keepers across all groups (b + e) and
    // their size — the same definition the group headers use.
    expect(
      find.text('2 photos · ${Formatters.formatBytes(3000)}'),
      findsOneWidget,
    );
    expect(find.text('1 duplicates'), findsNWidgets(2));
    expect(find.text(Formatters.formatBytes(1000)), findsOneWidget);
    expect(find.text(Formatters.formatBytes(2000)), findsOneWidget);
    // One explanation line for the whole screen, not per card.
    expect(
      find.text(
        'These are exact copies of the same photo. Marked duplicates '
        'go to Review — nothing is deleted from this screen.',
      ),
      findsOneWidget,
    );
    // A Keeper pill per group, on the suggested keepers only.
    expect(find.text('Keeper'), findsNWidgets(2));
    // One selection mark per non-keeper; keepers carry none; all
    // start selected.
    final List<DuplicateSelectionMark> marks = tester
        .widgetList<DuplicateSelectionMark>(find.byType(DuplicateSelectionMark))
        .toList();
    expect(marks.length, 2);
    expect(marks.every((DuplicateSelectionMark m) => m.selected), isTrue);
    // The sticky button opens with the full selected totals.
    expect(
      find.text(
        'Mark 2 duplicates for review · ${Formatters.formatBytes(3000)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mark taps update the bar live; select/deselect all work', (
    WidgetTester tester,
  ) async {
    // The mark taps below find nodes by their semantics labels,
    // including labels that change when a mark flips state — hold
    // a handle so the semantics tree recompiles on every pump
    // (the phase3b a11y test's pattern).
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpDuplicates(tester);
    // Spare b via its own mark (not the photo).
    await tester.tap(
      find.bySemanticsLabel('b.jpg, will be marked, tap to spare this photo'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Mark 1 duplicates for review · ${Formatters.formatBytes(2000)}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('b.jpg, spared, tap to mark this photo'),
      findsOneWidget,
    );
    // Re-select b the same way.
    await tester.tap(
      find.bySemanticsLabel('b.jpg, spared, tap to mark this photo'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Mark 2 duplicates for review · ${Formatters.formatBytes(3000)}',
      ),
      findsOneWidget,
    );
    // Deselect all: the button disables and the caption explains.
    await tester.tap(find.text('Deselect all'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mark 0 duplicates for review · ${Formatters.formatBytes(0)}'),
      findsOneWidget,
    );
    expect(find.text('Select at least 1 photo'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    // Select all restores the full totals.
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Mark 2 duplicates for review · ${Formatters.formatBytes(3000)}',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
    handle.dispose();
  });

  testWidgets('the bar marks exactly the selected ids and opens review', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Local local = await pumpDuplicates(tester);
    // Spare e; only b remains selected.
    await tester.tap(
      find.bySemanticsLabel('e.jpg, will be marked, tap to spare this photo'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        'Mark 1 duplicates for review · ${Formatters.formatBytes(1000)}',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review 1'), findsOneWidget);
    // The durable marks: b delete, its keeper a keep — and e's
    // whole group untouched (spared e, and no keep mark for d:
    // the group contributed nothing). Nothing was trashed or
    // deleted by this screen.
    final DeckSession? session = local.sessions['duplicates'];
    expect(session, isNotNull);
    expect(session!.marks, <String, DeckMark>{
      'a': DeckMark.keep,
      'b': DeckMark.delete,
    });
    expect(local.trashedRecords, 0);
    handle.dispose();
  });

  testWidgets('a three-photo group wraps two per row; the photo tap and '
      'the mark tap are separate targets', (WidgetTester tester) async {
    final List<String> keeperTaps = <String>[];
    final List<String> markTaps = <String>[];
    final List<MediaAsset> assets = <MediaAsset>[
      _asset('a'),
      _asset('b'),
      _asset('c'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DuplicateGroupCard(
              group: DuplicateGroup(assets: assets, keeperId: 'a'),
              thumbnails: <String, Uint8List>{
                for (final MediaAsset a in assets) a.id: _png(5),
              },
              failedThumbnails: <String>{},
              selectedIds: <String>{'b', 'c'},
              onKeeperTap: keeperTaps.add,
              onToggleSelection: markTaps.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Rect first = tester.getRect(find.byType(Image).at(0));
    final Rect second = tester.getRect(find.byType(Image).at(1));
    final Rect third = tester.getRect(find.byType(Image).at(2));
    // Two per row: b sits right of a on the same row; c wraps to
    // the first column of the next row.
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.left));
    expect(third.top, greaterThan(first.top));
    expect(third.left, first.left);
    // Tapping b's PHOTO asks for the keeper change...
    await tester.tap(find.byType(Image).at(1));
    expect(keeperTaps, <String>['b']);
    expect(markTaps, isEmpty);
    // ...tapping b's MARK toggles only the selection.
    await tester.tap(find.byType(DuplicateSelectionMark).first);
    expect(markTaps, <String>['b']);
    expect(keeperTaps, <String>['b']);
  });
}
