// Phase 3.3 / F-37: the fanned "On this day" card is stateless
// since Phase 2.3, so it needs no didUpdateWidget — this test
// proves the fan follows a changed asset list instead of holding
// a stale photo. No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/features/decks/widgets/on_this_day_hero_card.dart';
import 'package:klara/services/media/media_asset.dart';

/// Valid 1×1 PNGs, decoded once: Uint8List equality is identity,
// so the assertions below compare against these same instances.
final Uint8List _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final Uint8List _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
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

List<Uint8List> _shownBytes(WidgetTester tester) {
  // cacheWidth/cacheHeight wrap MemoryImage in a ResizeImage.
  return tester.widgetList<Image>(find.byType(Image)).map((Image image) {
    final ImageProvider provider = image.image;
    if (provider is ResizeImage) {
      return (provider.imageProvider as MemoryImage).bytes;
    }
    return (provider as MemoryImage).bytes;
  }).toList();
}

void main() {
  testWidgets('fan follows a changed asset list (no stale photo)', (
    WidgetTester tester,
  ) async {
    final RxMap<String, Uint8List> thumbnails = <String, Uint8List>{}.obs;
    final RxSet<String> failed = <String>{}.obs;
    thumbnails['a'] = _pngA;

    Widget card(List<MediaAsset> assets) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OnThisDayHeroCard(
              assets: assets,
              onTap: () {},
              thumbnails: thumbnails,
              failedThumbnails: failed,
              requestThumbnail: (_) {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(card(<MediaAsset>[_asset('a')]));
    await tester.pump();
    List<Uint8List> shown = _shownBytes(tester);
    expect(shown, isNotEmpty);
    expect(shown.every((Uint8List b) => b == _pngA), isTrue);

    // Swap the list and seed the new photo: the fan must show
    // the new photo, never the old one.
    thumbnails['b'] = _pngB;
    await tester.pumpWidget(card(<MediaAsset>[_asset('b')]));
    await tester.pump();
    shown = _shownBytes(tester);
    expect(shown, isNotEmpty);
    expect(shown.every((Uint8List b) => b == _pngB), isTrue);
  });
}
