// App version, read at runtime (Phase 3A).
//
// Interface only. The implementation reads pubspec's version via
// package_info_plus, so the About row never hard-codes a version
// string that could drift from pubspec.

abstract class AppInfoService {
  /// The pubspec version name (e.g. `1.0.0`), or an empty string
  /// when it cannot be read — the caller then shows "unknown".
  Future<String> appVersion();
}
