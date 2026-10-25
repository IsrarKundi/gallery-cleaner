// Document guard (requirements §7, Phase 4): the guard uses only
// on-device metadata signals — screenshot album or a document
// token in the filename — because Klara has no OCR and no content
// classification. These tests pin the signal boundaries, including
// the token-boundary cases that a substring match would get wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/document_guard.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset asset({
  required String id,
  String title = 'photo.jpg',
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: title,
    albumName: album,
  );
}

void main() {
  test('screenshot album matches, case-insensitively', () {
    expect(isDocumentLike(asset(id: 'a', album: 'Screenshots')), isTrue);
    expect(
      isDocumentLike(asset(id: 'b', album: 'my screenshots folder')),
      isTrue,
    );
    expect(isDocumentLike(asset(id: 'c', album: 'Camera')), isFalse);
  });

  test('document filename tokens match', () {
    for (final String title in <String>[
      'receipt_2024.jpg',
      'invoice-12.pdf.jpg',
      'boarding-pass.jpg',
      'passport-scan.jpg',
      'my_id.jpg',
      'ticket.png',
      'qr-code.jpg',
    ]) {
      expect(
        isDocumentLike(asset(id: title, title: title)),
        isTrue,
        reason: title,
      );
    }
  });

  test('token boundaries: substrings do not false-positive', () {
    // "id" inside "video", "bill" inside "billboard" must not match.
    expect(isDocumentLike(asset(id: 'a', title: 'myvideo.jpg')), isFalse);
    expect(isDocumentLike(asset(id: 'b', title: 'billboard.jpg')), isFalse);
    expect(isDocumentLike(asset(id: 'c', title: 'holiday.jpg')), isFalse);
  });

  test('videos are never document-like, even in a screenshot album', () {
    expect(
      isDocumentLike(
        asset(id: 'v', album: 'Screenshots', type: MediaAssetType.video),
      ),
      isFalse,
    );
  });

  test('documentLikeItems filters in grid order', () {
    final List<MediaAsset> items = <MediaAsset>[
      asset(id: 'plain'),
      asset(id: 'shot', album: 'Screenshots'),
      asset(id: 'rec', title: 'receipt.jpg'),
      asset(id: 'other'),
    ];
    final List<MediaAsset> guarded = documentLikeItems(items);
    expect(guarded.map((MediaAsset a) => a.id).toList(), <String>[
      'shot',
      'rec',
    ]);
  });
}
