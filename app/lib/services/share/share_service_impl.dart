// [ShareService] via `share_plus`. This is the ONLY file importing
// share_plus (AGENTS.md: service implementations are the only
// files importing platform SDKs). The PNG is written to the app
// cache directory (path_provider) under a fixed name so a repeat
// share overwrites instead of accumulating files; nothing is
// uploaded anywhere — the sheet hands the file to the app the
// user picks, on-device.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'share_service.dart';

class ShareServiceImpl implements ShareService {
  @override
  Future<Result<void>> shareSummary({
    required String text,
    Uint8List? imagePng,
  }) async {
    try {
      List<XFile>? files;
      if (imagePng != null) {
        final Directory cache = await getTemporaryDirectory();
        final File file = File('${cache.path}/klara-summary.png');
        await file.writeAsBytes(imagePng);
        files = <XFile>[XFile(file.path)];
      }
      await SharePlus.instance.share(ShareParams(text: text, files: files));
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(AppFailure(messageKey: AppStrings.errorShare));
    }
  }
}
