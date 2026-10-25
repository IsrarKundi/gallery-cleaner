// Device free-storage reading (Phase 2B projection bar).
//
// Interface only. The implementation uses the `disk_space` plugin
// (StatFs over shared storage, MB) — the first plugin tried per
// the Phase 2B brief, and it resolved cleanly on Flutter 3.47.7.
// Nothing here is faked: a null/unreadable value is a failure, and
// the hub then shows the labelled library projection instead of
// inventing device numbers.

import '../../core/utils/result.dart';

abstract class StorageService {
  /// Free device storage in MB, or a failure when it cannot be read.
  Future<Result<double>> getFreeMb();
}
