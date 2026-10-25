// [StorageService] via the `disk_space_plus` plugin. This is the ONLY
// file importing disk_space_plus (AGENTS.md: service implementations
// are the only files importing platform/storage SDKs). The plugin
// reports MB (bytes / 1024 / 1024) from StatFs on shared storage —
// the volume that holds the photos being cleaned.

import 'package:disk_space_plus/disk_space_plus.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'storage_service.dart';

class StorageServiceImpl implements StorageService {
  StorageServiceImpl([DiskSpacePlus? plugin])
      : _plugin = plugin ?? DiskSpacePlus();

  final DiskSpacePlus _plugin;

  @override
  Future<Result<double>> getFreeMb() async {
    try {
      final double? freeMb = await _plugin.getFreeDiskSpace;
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
