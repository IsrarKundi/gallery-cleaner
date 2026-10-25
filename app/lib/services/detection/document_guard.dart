// Document guard (requirements §7, Phase 4): warn before deleting
// screenshots that look like receipts, IDs, tickets or QR codes.
//
// Honest scope, stated plainly: Klara has NO OCR and NO content
// classification on-device, so it cannot read what a screenshot
// shows. The guard therefore uses only signals that already exist
// on-device through photo_manager/MediaStore metadata:
//  - the asset lives in a screenshot album/folder (the same
//    case-insensitive "screenshot" match the Screenshots smart deck
//    uses), or
//  - the asset's filename/title contains a document word (receipt,
//    invoice, ticket, passport, licence, QR code, barcode, ...).
// A screenshot of a meme and a receipt both match the album rule;
// a receipt photo saved outside a screenshot folder matches only
// when its filename says so. The guard is a warning, never a
// claim that the photo IS a document, and never a block the user
// cannot override: after the warning, an explicit "delete anyway"
// confirmation stands (the app's user-is-in-control trust model).
// Videos are excluded: a video filename is not a document photo,
// and the spec's examples are all still images.
//
// Enforcement point is Review only, deliberately: a swipe only
// marks (requirements §4), so no deletion is initiated on the deck,
// in a smart deck or on Duplicates. Every delete-marked
// document-like item is caught at Review — a banner while it sits
// in the grid, and a counted confirmation dialog at delete time —
// whichever route marked it. Nothing here deletes anything.

import '../media/media_asset.dart';

/// Filename tokens that mark an asset document-like. Matched as
/// whole tokens (the title is split on non-alphanumerics), so "id"
/// never matches inside "video" and "bill" never matches inside
/// "billboard" — a substring match would false-positive constantly.
const Set<String> documentTitleTokens = <String>{
  'receipt',
  'invoice',
  'bill',
  'ticket',
  'boarding',
  'passport',
  'licence',
  'license',
  'identity',
  'id',
  'cnic',
  'nid',
  'qr',
  'barcode',
  'document',
  'contract',
  'certificate',
  'voucher',
  'prescription',
};

/// True when [asset] looks document-like by the on-device signals
/// above. Images only; screenshots are matched by album, other
/// photos only by a document token in the title.
bool isDocumentLike(MediaAsset asset) {
  if (asset.type != MediaAssetType.image) {
    return false;
  }
  if (asset.albumName.toLowerCase().contains('screenshot') ||
      asset.title.toLowerCase().contains('screenshot')) {
    return true;
  }
  final Iterable<String> tokens = asset.title
      .toLowerCase()
      .split(RegExp('[^a-z0-9]+'))
      .where((String token) => token.isNotEmpty);
  return tokens.any(documentTitleTokens.contains);
}

/// The document-like subset of [items], in grid order. Pure, so
/// Review tests can assert the gate without a device.
List<MediaAsset> documentLikeItems(List<MediaAsset> items) {
  return items.where(isDocumentLike).toList();
}
