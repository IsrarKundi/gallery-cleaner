// Single WidgetsBindingObserver for the app (solutions 4.4).
//
// Semantics:
// - paused / detached / hidden → backgrounded: pause listeners
//   fire, then pending session writes flush (a mandatory flush
//   point — the coalescing window must never survive a
//   backgrounding, because a kill after it would lose up to
//   ~1.5 s of marks). The flush is fired without awaiting: the
//   observer callback is synchronous, but calling flush cancels
//   the debounce timer and enqueues the write immediately, so
//   the data leaves the window at once.
// - resumed → foregrounded, but ONLY when previously
//   backgrounded: a resumed event at launch (before any pause)
//   must not trigger resume handling.
// - inactive is transient (call overlay, split-screen focus
//   loss) and is ignored — it is neither background nor
//   foreground for our purposes.
// - Permission state is never persisted and never cached here:
//   every resume handler re-checks permission itself (Android
//   14 rule). This service only delivers the transition.
//
// Listener failures are contained: one throwing listener must
// not prevent the others (or the flush) from running.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../local/local_service.dart';
import '../media/library_change_source.dart';
import 'app_lifecycle.dart';

class AppLifecycleImpl extends WidgetsBindingObserver implements AppLifecycle {
  AppLifecycleImpl({required this.local, this.changeSource});

  final LocalService local;

  /// Null when no native delivery is wired: the libraryChanged
  /// stream then never emits (see app_lifecycle.dart).
  final LibraryChangeSource? changeSource;

  bool _backgrounded = false;
  final List<void Function()> _pauseListeners = <void Function()>[];
  final List<void Function()> _resumeListeners = <void Function()>[];
  final StreamController<void> _libraryChangedController =
      StreamController<void>.broadcast();
  StreamSubscription<void>? _changeSubscription;
  bool _attached = false;

  @override
  bool get isBackgrounded => _backgrounded;

  @override
  Stream<void> get libraryChanged => _libraryChangedController.stream;

  @override
  void addPauseListener(void Function() listener) {
    _pauseListeners.add(listener);
  }

  @override
  void removePauseListener(void Function() listener) {
    _pauseListeners.remove(listener);
  }

  @override
  void addResumeListener(void Function() listener) {
    _resumeListeners.add(listener);
  }

  @override
  void removeResumeListener(void Function() listener) {
    _resumeListeners.remove(listener);
  }

  /// Registers the observer and starts native change delivery.
  /// Safe to call where no WidgetsBinding exists (plain unit
  /// tests): the observer registration is skipped there and
  /// [handleStateChange] remains the drive mechanism.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // No binding (unit-test context): transitions are driven
      // via handleStateChange instead.
    }
    _changeSubscription = changeSource?.onLibraryChanged.listen(
      (_) => _libraryChangedController.add(null),
    );
    _startSource();
  }

  /// Unregisters the observer and stops native change delivery.
  void detach() {
    if (!_attached) {
      return;
    }
    _attached = false;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {
      // See attach(): no binding in this context.
    }
    unawaited(_changeSubscription?.cancel());
    _changeSubscription = null;
    unawaited(_stopSource());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleStateChange(state));
  }

  /// Testable transition handler (also the observer bridge):
  /// drives pause/resume from a lifecycle state value.
  Future<void> handleStateChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handlePause();
      case AppLifecycleState.resumed:
        _handleResume();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _handlePause() {
    if (_backgrounded) {
      return;
    }
    _backgrounded = true;
    for (final void Function() listener in List<void Function()>.of(
      _pauseListeners,
    )) {
      try {
        listener();
      } catch (_) {
        // Contained: one listener must not break the rest.
      }
    }
    // Mandatory flush point (solutions 4.1/4.4): session marks
    // must not sit in the coalescing window across a background.
    unawaited(local.flushPendingWrites());
  }

  void _handleResume() {
    if (!_backgrounded) {
      return;
    }
    _backgrounded = false;
    for (final void Function() listener in List<void Function()>.of(
      _resumeListeners,
    )) {
      try {
        listener();
      } catch (_) {
        // Contained: one listener must not break the rest.
      }
    }
  }

  Future<void> _startSource() async {
    try {
      await changeSource?.start();
    } catch (_) {
      // Change delivery is best-effort: without it, consumers
      // fall back to their resume-time refresh.
    }
  }

  Future<void> _stopSource() async {
    try {
      await changeSource?.stop();
    } catch (_) {
      // Best-effort teardown.
    }
  }
}
