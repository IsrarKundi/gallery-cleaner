// One asset sitting in the Android system Trash, as Klara records it.
//
// Android hides trashed assets from normal MediaStore queries, so
// this record — written by [TrashService] at trash time — is the only
// way the Trash screen can list them across restarts. It holds ids,
// sizes and dates only, never photo content.
//
// The system owns expiry: after 30 days the system removes the asset.
// Klara never auto-deletes expired trash itself (requirements §4).

/// One trashed asset.
class TrashEntry {
  const TrashEntry({
    required this.assetId,
    required this.typeInt,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.trashedAt,
  });

  /// MediaStore id.
  final String assetId;

  /// photo_manager type int (image = 1, video = 2). Needed to rebuild
  /// the entity for a restore, since trashed assets cannot be queried.
  final int typeInt;
  final int width;
  final int height;
  final int sizeBytes;

  /// When the native confirmation moved the asset to Trash.
  final DateTime trashedAt;

  /// The system removes the asset 30 days after [trashedAt].
  /// Until then it is recoverable — never reported as freed.
  DateTime get recoverableUntil => trashedAt.add(const Duration(days: 30));

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'assetId': assetId,
      'typeInt': typeInt,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
      'trashedAt': trashedAt.toIso8601String(),
    };
  }

  factory TrashEntry.fromJson(Map<String, dynamic> json) {
    return TrashEntry(
      assetId: json['assetId'] as String,
      typeInt: json['typeInt'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      sizeBytes: json['sizeBytes'] as int,
      trashedAt: DateTime.parse(json['trashedAt'] as String),
    );
  }
}
