import 'package:flutter/foundation.dart';

/// TEMPORARY Phase 0 baseline instrumentation — REMOVE BEFORE ANY RELEASE.
///
/// Prints one timestamped line per mark to logcat, tagged `KLARA_PERF`,
/// with milliseconds since the first mark (`runApp` in production).
/// Silent in release builds ([kReleaseMode]); active in debug AND
/// profile builds, because Phase 0 measurements run in profile mode
/// (`flutter run --profile`), where `kDebugMode` is false.
///
/// This file, and every `PerfLog.mark` call site, must be deleted once
/// Phase 0 baselines are captured (see `docs/performance-solutions.md`
/// Phase 0). It is not product code and must never ship.
class PerfLog {
  PerfLog._();

  static final Stopwatch _stopwatch = Stopwatch();

  static void mark(String label) {
    if (kReleaseMode) {
      return;
    }
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    debugPrint('KLARA_PERF ${_stopwatch.elapsedMilliseconds}ms $label');
  }
}
