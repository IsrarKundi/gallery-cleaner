// package_info_plus implementation of [AppInfoService]. This is
// the ONLY file importing package_info_plus (AGENTS.md dependency
// rules). A failure reads as empty, never as a guessed version.

import 'package:package_info_plus/package_info_plus.dart';

import 'app_info_service.dart';

class AppInfoServiceImpl implements AppInfoService {
  @override
  Future<String> appVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }
}
