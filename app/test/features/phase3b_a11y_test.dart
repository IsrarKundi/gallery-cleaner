// Phase 3B accessibility tests (design.md §9):
// - every fixed snooze button really has a 48dp tap target
//   (edge taps register — the old 40-in-48 pattern did not),
// - TalkBack labels exist on the hub row, duplicate thumbnails
//   and review tiles that previously announced nothing,
// - the shared SecondaryButton itself is 48dp tall.
// Widget tests use a tall surface (see the Phase 3A test-hang
// lesson: no real file IO here, so no runAsync is needed).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/formatters.dart';
import 'package:klara/core/widgets/secondary_button.dart';
import 'package:klara/features/decks/model/maybe_pile_item.dart';
import 'package:klara/features/decks/model/smart_deck_meta.dart';
import 'package:klara/features/decks/widgets/deck_row.dart';
import 'package:klara/features/decks/widgets/maybe_pile_row.dart';
import 'package:klara/features/decks/widgets/duplicate_group_card.dart';
import 'package:klara/features/review/widgets/review_grid_tile.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(String id, {String title = ''}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: title.isEmpty ? '$id.jpg' : title,
    albumName: 'Camera',
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size surface = const Size(400, 1200),
}) async {
  await tester.binding.setSurfaceSize(surface);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('snooze buttons: 48dp tall and edge taps register', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    final MaybePileItem item = MaybePileItem(
      asset: _asset('m1'),
      sessionKey: 'all',
      snoozeUntil: null,
    );
    await _pump(
      tester,
      MaybePileRow(
        item: item,
        onSnooze: (int days) => tapped = true,
        onClearSnooze: () {},
      ),
    );
    final Finder button = find.widgetWithText(OutlinedButton, 'Snooze 7 days');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, 48);
    final Offset top = tester.getTopLeft(button);
    final Offset center = tester.getCenter(button);
    await tester.tapAt(Offset(center.dx, top.dy + 2));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('SecondaryButton itself is 48dp tall', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SecondaryButton(label: 'Keep all'));
    expect(tester.getSize(find.byType(SecondaryButton)).height, 48);
    expect(tester.getSize(find.byType(OutlinedButton)).height, 48);
  });

  testWidgets('hub DeckRow announces title + subtitle as one button', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      DeckRow(
        deckId: SmartDeckId.screenshots,
        count: 3,
        totalBytes: 3000,
        ready: true,
        onTap: () {},
        thumbnails: <String, Uint8List>{}.obs,
        failedThumbnails: <String>{}.obs,
        requestThumbnail: (_) {},
      ),
    );
    final SemanticsHandle handle = tester.ensureSemantics();
    final Finder row = find.bySemanticsLabel(
      '${AppStrings.tr(smartDeckTitleKey(SmartDeckId.screenshots))} · '
      '${AppStrings.tr(AppStrings.decksRowCount, <String, String>{'count': Formatters.formatCount(3), 'size': Formatters.formatBytes(3000)})}',
    );
    expect(row, findsOneWidget);
    handle.dispose();
  });

  testWidgets('duplicate thumbnails announce keeper vs candidate', (
    WidgetTester tester,
  ) async {
    final MediaAsset keeper = _asset('k1', title: 'keeper.jpg');
    final MediaAsset other = _asset('o1', title: 'other.jpg');
    final DuplicateGroup group = DuplicateGroup(
      assets: <MediaAsset>[keeper, other],
      keeperId: 'k1',
    );
    // Wider surface: widget tests render with the Ahem test font,
    // whose glyphs are far wider than Inter, so the card's long
    // button label overflows at 400px in tests only (at the 1.30
    // text-scale cap it still fits a 400px phone in Inter).
    await _pump(
      tester,
      SingleChildScrollView(
        child: DuplicateGroupCard(
          group: group,
          thumbnails: <String, Uint8List>{},
          // Failed (not loading) thumbnails, so no spinner keeps
          // pumpAndSettle from ever settling.
          failedThumbnails: <String>{'k1', 'o1'},
          onKeeperTap: (_) {},
          onMarkNonKeepers: () {},
        ),
      ),
      surface: const Size(600, 1200),
    );
    final SemanticsHandle handle2 = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('keeper.jpg, keeper, tap to keep this photo'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('other.jpg, tap to make this photo the keeper'),
      findsOneWidget,
    );
    handle2.dispose();
  });

  testWidgets('review tile announces its unmark action', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 200,
        height: 200,
        child: ReviewGridTile(
          asset: _asset('r1', title: 'beach.jpg'),
          thumbnail: null,
          thumbnailFailed: true,
          onTap: () {},
        ),
      ),
    );
    final SemanticsHandle handle3 = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('beach.jpg, tap to remove from review'),
      findsOneWidget,
    );
    handle3.dispose();
  });

  testWidgets('review tile with no title still announces an action', (
    WidgetTester tester,
  ) async {
    final MediaAsset untitled = MediaAsset(
      id: 'r2',
      type: MediaAssetType.image,
      width: 10,
      height: 10,
      sizeBytes: 1000,
      createDate: DateTime(2026, 10, 5),
      title: '',
      albumName: 'Camera',
    );
    await _pump(
      tester,
      SizedBox(
        width: 200,
        height: 200,
        child: ReviewGridTile(
          asset: untitled,
          thumbnail: null,
          thumbnailFailed: true,
          onTap: () {},
        ),
      ),
    );
    final SemanticsHandle handle4 = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Photo, tap to remove from review'),
      findsOneWidget,
    );
    handle4.dispose();
  });
}
