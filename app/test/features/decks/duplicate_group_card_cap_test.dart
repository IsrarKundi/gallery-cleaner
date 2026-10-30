// Phase 3.4 / brief 3.5: duplicate group previews render at most
// 20 collapsed, with an overflow tile that expands to the full
// group — the keeper pick must reach every member. No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/decks/widgets/duplicate_group_card.dart';
import 'package:klara/services/detection/grouping.dart';
import 'package:klara/services/media/media_asset.dart';

/// A valid 1×1 PNG, so thumbnails render for real.
Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  List<MediaAsset> assets,
  String keeperId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DuplicateGroupCard(
            group: DuplicateGroup(assets: assets, keeperId: keeperId),
            thumbnails: <String, Uint8List>{
              for (final MediaAsset a in assets) a.id: _png,
            },
            failedThumbnails: <String>{},
            selectedIds: <String>{
              for (final MediaAsset a in assets)
                if (a.id != keeperId) a.id,
            },
            onKeeperTap: (_) {},
            onToggleSelection: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('25 members collapse to 20 plus an overflow tile', (
    WidgetTester tester,
  ) async {
    final List<MediaAsset> assets = <MediaAsset>[
      for (int i = 0; i < 25; i++) _asset('d$i'),
    ];
    await _pumpCard(tester, assets, 'd0');
    expect(tester.widgetList(find.byType(Image)).length, 20);
    expect(find.text('+5'), findsOneWidget);

    // Stage 7: tiles are large now, so the overflow tile sits far
    // down the collapsed card — scroll it into view before tapping.
    await tester.scrollUntilVisible(
      find.text('+5'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+5'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(Image)).length, 25);
    expect(find.text('+5'), findsNothing);
  });

  testWidgets('keeper beyond the cap stays visible collapsed', (
    WidgetTester tester,
  ) async {
    final List<MediaAsset> assets = <MediaAsset>[
      for (int i = 0; i < 25; i++) _asset('d$i'),
    ];
    await _pumpCard(tester, assets, 'd24');
    // First 20 plus the keeper appended: 21 previews, 4 hidden.
    expect(tester.widgetList(find.byType(Image)).length, 21);
    expect(find.text('+4'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('+4'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+4'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(Image)).length, 25);
  });
}
