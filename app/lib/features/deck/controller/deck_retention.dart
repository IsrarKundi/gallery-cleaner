// Retention glue shared by the main deck and smart-deck
// controllers (Phase 2B). A plain helper class, NOT a GetxController
// and NOT registered in any binding — each controller owns one
// instance, so its share error state survives across view rebuilds.
// The pure math lives in retention.dart; this class owns only the
// service calls around it (snooze-record clearing, completion-day
// recording, sharing), so neither controller duplicates them.

import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/share/share_service.dart';
import '../model/retention.dart';

class DeckRetention {
  DeckRetention({required this.local, this.share});

  final LocalService local;
  final ShareService? share;

  final RxString shareErrorKey = ''.obs;

  bool get canShare => share != null;

  /// Summarizes one queue's marks (see retention.dart).
  SessionSummary summarize(
    Map<String, DeckMark> marks,
    List<MediaAsset> queue,
  ) {
    return computeSessionSummary(
      marks: marks,
      assetsById: <String, MediaAsset>{
        for (final MediaAsset asset in queue) asset.id: asset,
      },
    );
  }

  /// Applies expired snoozes to [marks]: expired snoozed Maybe
  /// marks are removed and their snooze records cleared. Returns
  /// the updated marks and whether anything changed; the caller
  /// persists the returned marks (it owns the session key/index).
  /// A failed snooze read leaves marks untouched (safe default).
  Future<({Map<String, DeckMark> marks, bool changed})> clearExpiredSnoozes(
    Map<String, DeckMark> marks,
    DateTime now,
  ) async {
    final Result<Map<String, DateTime>> snoozesResult = await local
        .loadSnoozes();
    final Map<String, DateTime>? snoozes = snoozesResult.fold(
      onSuccess: (Map<String, DateTime> value) => value,
      onFailure: (_) => null,
    );
    if (snoozes == null || snoozes.isEmpty) {
      return (marks: marks, changed: false);
    }
    final ({Map<String, DeckMark> marks, List<String> clearedIds}) applied =
        applySnoozeExpiry(marks, snoozes, now);
    if (applied.clearedIds.isEmpty) {
      return (marks: marks, changed: false);
    }
    // Phase 4.1: one batched write for the whole expiry sweep,
    // not one read-modify-write per cleared snooze.
    await local.clearSnoozes(applied.clearedIds);
    return (marks: applied.marks, changed: true);
  }

  /// Restores a saved session into the controller's live [marks]
  /// and [favouriteIds], then applies snooze expiry (Phase 2B):
  /// expired snoozed Maybe marks clear so those assets return
  /// undecided. Returns true when expiry changed the marks, so
  /// the caller persists. Marks for assets no longer present are
  /// kept (they contribute nothing and never crash resume: the
  /// resume index scans the loaded queue only). Shared by the deck
  /// and smart-deck controllers — previously duplicated in both.
  Future<bool> restoreSession(
    RxMap<String, DeckMark> marks,
    RxSet<String> favouriteIds,
    DeckSession? session,
  ) async {
    if (session == null) {
      return false;
    }
    marks.assignAll(session.marks);
    favouriteIds.assignAll(session.favouriteIds);
    final expiry = await clearExpiredSnoozes(
      Map<String, DeckMark>.of(marks),
      DateTime.now(),
    );
    if (!expiry.changed) {
      return false;
    }
    marks.assignAll(expiry.marks);
    return true;
  }

  /// Records today as a completed day (idempotent per day).
  void recordCompletion() {
    local.recordCompletionDay(DateTime.now());
  }

  /// Shares [summary]: the card PNG when [imagePng] was captured,
  /// otherwise the same numbers as text (the documented
  /// capture-failure fallback). A failure sets [shareErrorKey].
  Future<void> shareSummary(SessionSummary summary, Uint8List? imagePng) async {
    final ShareService? backend = share;
    if (backend == null) {
      return;
    }
    shareErrorKey.value = '';
    final Result<void> result = await backend.shareSummary(
      text: summaryShareText(summary),
      imagePng: imagePng,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (AppFailure failure) {
        shareErrorKey.value = failure.messageKey;
      },
    );
  }
}
