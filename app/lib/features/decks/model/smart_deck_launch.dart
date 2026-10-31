// Route arguments for the smart-deck swipe screen: which deck and
// its precomputed assets. Cross-feature data travels via route
// arguments (AGENTS.md), never by importing another feature.

import '../../../services/detection/smart_decks.dart';
import '../../../services/media/media_asset.dart';

class SmartDeckLaunch {
  const SmartDeckLaunch({
    this.deckId,
    required this.assets,
    this.customSessionKey,
    this.customTitle,
  });

  final SmartDeckId? deckId;
  final List<MediaAsset> assets;
  final String? customSessionKey;

  /// Header title for a launch that has no [SmartDeckId] to take
  /// one from (ADR-027: an album launch shows the album's name).
  /// Null keeps the generic smart-deck title — the timeline
  /// month launch behaves exactly as before.
  final String? customTitle;

  /// Session key for this deck's marks, so resume works per deck
  /// and delete marks flow to review exactly like main-deck marks.
  String get sessionKey =>
      customSessionKey ?? 'smart:${deckId?.name ?? 'custom'}';
}
