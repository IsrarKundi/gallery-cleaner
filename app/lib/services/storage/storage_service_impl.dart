// [StorageService] via the `disk_space` plugin. This is the ONLY
// file importing disk_space (AGENTS.md: service implementations
// are the only files importing platform/storage SDKs). The plugin
// reports MB (bytes / 1024 / 1024) from StatFs on shared storage —
// the volume that holds the photos being cleaned.

import 'package:disk_space/disk_space.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'storage_service.dart';

class StorageServiceImpl implements StorageService {
  @override
  Future<Result<double>> getFreeMb() async {
    try {
      final double? freeMb = await DiskSpace.getFreeDiskSpace;
      if (freeMb == null) {
        return const Failure<double>(
          AppFailure(messageKey: AppStrings.errorStorage),
        );
      }
      return Success<double>(freeMb);
    } catch (_) {
      return const Failure<double>(
        AppFailure(messageKey: AppStrings.errorStorage),
      );
    }
  }
}
