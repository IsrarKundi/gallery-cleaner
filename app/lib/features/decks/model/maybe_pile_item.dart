// One Maybe-pile row (Phase 2B): a Maybe-marked asset gathered
// from a saved session, plus its snooze state. The asset metadata
// (title, date, size) comes from the hub's scanned library — an
// asset no longer in the library cannot be shown and is skipped.

import '../../../services/media/media_asset.dart';

class MaybePileItem {
  const MaybePileItem({
    required this.asset,
    required this.sessionKey,
    required this.snoozeUntil,
  });

  final MediaAsset asset;
  final String sessionKey;

  /// Return date, or null when the asset is Maybe but not snoozed.
  final DateTime? snoozeUntil;
}
