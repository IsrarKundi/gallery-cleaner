// Haptic feedback, gated by the Settings haptics toggle
// (Phase 3A, design.md §8).
//
// Mapping (exact, from design.md §8):
// - mark/select (a swipe or button mark, a keeper/toggle selection):
//   [mark] = selection click, the light tick.
// - delete-confirm success (review's native-sheet run trashed
//   photos): [deleteConfirm] = medium impact, the medium click.
// - freed completion (trash emptied): [freed] = heavy impact, one
//   firm pulse. Never a long vibration: buzzy vibrations are banned
//   by design.md §8, so `vibrate()` is never called here.
// - Nothing on scroll or hover: no method exists for those.
//
// [enabled] defaults ON (the toggle's default). SettingsController
// applies the persisted value on load and on every toggle change.
// Calls are safe from tests and from platforms without haptics:
// failures are swallowed, never surfaced as errors.

import 'dart:async';

import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  static bool enabled = true;

  static void mark() {
    unawaited(_run(HapticFeedback.selectionClick));
  }

  static void deleteConfirm() {
    unawaited(_run(HapticFeedback.mediumImpact));
  }

  static void freed() {
    unawaited(_run(HapticFeedback.heavyImpact));
  }

  static Future<void> _run(Future<void> Function() feedback) async {
    if (!enabled) {
      return;
    }
    try {
      await feedback();
    } catch (_) {
      // No haptics on this platform/runner: feedback is optional.
    }
  }
}
