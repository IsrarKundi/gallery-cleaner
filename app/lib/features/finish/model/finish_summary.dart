// What a completed delete batch did (fix plan Stage 5,
// ADR-020 decisions 1–2). Built by the flow that ran the batch
// (Review permanent delete / Clean-deck batched trash) from the
// native outcome itself, carried to the finish screen as its
// route argument. Pure data — no behaviour, no state.
//
// The space state is part of the value, not a display choice:
// the two flows free space differently and the finish screen
// must say which one happened (requirements §4, three states).

/// The true state of the batch's space.
enum FinishSpaceState {
  /// Permanently deleted (Review, ADR-014): the space is freed.
  freed,

  /// Sent to the system trash (Clean deck, ADR-013): freed only
  /// when the trash is emptied or the entries expire.
  inTrash,
}

class FinishSummary {
  const FinishSummary({
    required this.deletedCount,
    required this.sizeBytes,
    required this.spaceState,
    this.recoverableUntil,
  });

  /// Photos the native confirmation actually deleted/trashed.
  final int deletedCount;

  /// Their total size in bytes, summed from the same records.
  final int sizeBytes;

  final FinishSpaceState spaceState;

  /// For [FinishSpaceState.inTrash]: when the batch's entries
  /// leave the system trash (earliest recorded entry's
  /// recover-by date). Null when unknown — the caption then
  /// names no date rather than inventing one.
  final DateTime? recoverableUntil;
}
