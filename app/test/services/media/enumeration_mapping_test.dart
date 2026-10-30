// Fix plan Stage 2 (ADR-017): the enumeration's pure rules —
// screenshot marking by file name (the teardown's exact rule)
// and the row → MediaAsset conversion that mirrors the
// photo_manager entity semantics the app was built on.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/media/enumerated_asset.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_mappings.dart';

EnumeratedAsset _row({
  String id = '1',
  MediaAssetType type = MediaAssetType.image,
  String title = 'IMG_0001.jpg',
  String bucketId = '10',
  String bucketName = 'Camera',
  int sizeBytes = 1234,
  int width = 4000,
  int height = 3000,
  int? storeWidth,
  int? storeHeight,
  int dateAddedSec = 1700000000,
  int dateTakenMs = 0,
  int dateModifiedSec = 1700001000,
  bool isFavorite = false,
  String? relativePath = 'DCIM/Camera',
  bool fileExists = true,
}) {
  return EnumeratedAsset(
    id: id,
    type: type,
    title: title,
    bucketId: bucketId,
    bucketName: bucketName,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    storeWidth: storeWidth ?? width,
    storeHeight: storeHeight ?? height,
    dateAddedSec: dateAddedSec,
    dateTakenMs: dateTakenMs,
    dateModifiedSec: dateModifiedSec,
    isFavorite: isFavorite,
    relativePath: relativePath,
    fileExists: fileExists,
  );
}

void main() {
  group('isScreenshotAssetName (teardown rule, name only)', () {
    test('contains-rules match anywhere in the name', () {
      expect(isScreenshotAssetName('Screenshot_2024.png'), isTrue);
      expect(isScreenshotAssetName('screen_shot_01.png'), isTrue);
      expect(isScreenshotAssetName('SCREEN-SHOT.png'), isTrue);
      // Literal reading: the contains-rules are not anchored, so
      // a camera-style name carrying the word still matches.
      expect(isScreenshotAssetName('IMG_screenshot_back.jpg'), isTrue);
      expect(isScreenshotAssetName('myscreen_shot.png'), isTrue);
    });

    test('starts-with rules match at the head', () {
      expect(isScreenshotAssetName('screenshot_20240101.png'), isTrue);
      expect(isScreenshotAssetName('screen_20240101.png'), isTrue);
      expect(isScreenshotAssetName('SCREEN_2024.PNG'), isTrue);
    });

    test('ordinary names do not match', () {
      expect(isScreenshotAssetName('IMG_2024.jpg'), isFalse);
      expect(isScreenshotAssetName('PXL_20240101.jpg'), isFalse);
      expect(isScreenshotAssetName('screen.png'), isFalse);
      expect(isScreenshotAssetName('shot_screen.png'), isFalse);
      expect(isScreenshotAssetName(''), isFalse);
    });
  });

  group('resolveAlbumName', () {
    test('uses the last relative-path segment', () {
      expect(resolveAlbumName('DCIM/Camera/', 'Recent'), 'Camera');
      expect(resolveAlbumName('Pictures', 'Recent'), 'Pictures');
      expect(resolveAlbumName('a/b/c', 'Recent'), 'c');
    });

    test('falls back when the path is missing or empty', () {
      expect(resolveAlbumName(null, 'Camera'), 'Camera');
      expect(resolveAlbumName('', 'Camera'), 'Camera');
      expect(resolveAlbumName('  ', 'Camera'), 'Camera');
    });
  });

  group('mediaAssetFromEnumerated', () {
    test('createDate prefers DATE_TAKEN, in whole seconds', () {
      final MediaAsset asset = mediaAssetFromEnumerated(
        _row(dateTakenMs: 1700000500999, dateAddedSec: 1700000000),
        albumNameFallback: 'Recent',
      );
      // The plugin truncated DATE_TAKEN to seconds before its
      // getter scaled back to milliseconds — same value here.
      expect(
        asset.createDate,
        DateTime.fromMillisecondsSinceEpoch(1700000500 * 1000),
      );
    });

    test('createDate falls back to DATE_ADDED when taken is 0', () {
      final MediaAsset asset = mediaAssetFromEnumerated(
        _row(dateTakenMs: 0, dateAddedSec: 1700000000),
        albumNameFallback: 'Recent',
      );
      expect(
        asset.createDate,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
    });

    test('modifiedDate scales DATE_MODIFIED seconds, never null', () {
      final MediaAsset asset = mediaAssetFromEnumerated(
        _row(dateModifiedSec: 1700001000),
        albumNameFallback: 'Recent',
      );
      expect(
        asset.modifiedDate,
        DateTime.fromMillisecondsSinceEpoch(1700001000 * 1000),
      );
    });

    test('carries size, dims, favourite and the screenshot mark', () {
      final MediaAsset asset = mediaAssetFromEnumerated(
        _row(title: 'Screenshot_2024.png', isFavorite: true),
        albumNameFallback: 'Recent',
      );
      expect(asset.sizeBytes, 1234);
      expect(asset.width, 4000);
      expect(asset.height, 3000);
      expect(asset.isSystemFavourite, isTrue);
      expect(asset.isScreenshot, isTrue);
    });

    test('albumName resolves from the path, else the fallback', () {
      expect(
        mediaAssetFromEnumerated(
          _row(relativePath: 'Pictures/Screenshots'),
          albumNameFallback: 'Recent',
        ).albumName,
        'Screenshots',
      );
      expect(
        mediaAssetFromEnumerated(
          _row(relativePath: null),
          albumNameFallback: 'Camera',
        ).albumName,
        'Camera',
      );
    });
  });

  group('isPluginListRow (the plugin list dimension rule)', () {
    test('an image with stored dimensions is a list row', () {
      expect(isPluginListRow(_row()), isTrue);
    });

    test('a header-repaired image is NOT a list row: the store '
        'columns decide, not the repaired dimensions', () {
      // Store width 0, header gave 4000x3000 (the _row defaults):
      // the plugin's SQL size condition never listed this row.
      expect(isPluginListRow(_row(storeWidth: 0)), isFalse);
      expect(isPluginListRow(_row(storeHeight: 0)), isFalse);
    });

    test('a zero-dimension image (SVG-style, repair skipped) is '
        'not a list row', () {
      expect(
        isPluginListRow(
          _row(width: 0, height: 0, storeWidth: 0, storeHeight: 0),
        ),
        isFalse,
      );
    });

    test('videos carry no dimension condition, even at zero', () {
      expect(
        isPluginListRow(
          _row(
            type: MediaAssetType.video,
            width: 0,
            height: 0,
            storeWidth: 0,
            storeHeight: 0,
          ),
        ),
        isTrue,
      );
      expect(isPluginListRow(_row(type: MediaAssetType.video)), isTrue);
    });
  });
}
