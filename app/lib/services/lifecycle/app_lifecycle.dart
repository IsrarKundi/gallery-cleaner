// App foreground/background delivery (solutions 4.4).
//
// One observer for the whole app: controllers register pause /
// resume listeners instead of each owning a WidgetsBindingObserver.
// The observer itself is a thin bridge in [AppLifecycleImpl]; the
// testable seam is the impl's `handleStateChange`, so unit tests
// drive lifecycle transitions without a WidgetsBinding.

import 'dart:async';

/// Foreground/background state plus the library-change flag
/// stream, behind one interface so controllers depend on an
/// abstraction and tests can substitute a fake.
abstract class AppLifecycle {
  /// True between a pause event and the next resume event.
  bool get isBackgrounded;

  /// Fires (with no payload) on every native library change,
  /// forwarded from the [LibraryChangeSource] when one is wired.
  /// Never emits when no source is wired — consumers then rely
  /// on their resume-time refresh, not on this stream.
  Stream<void> get libraryChanged;

  void addPauseListener(void Function() listener);

  void removePauseListener(void Function() listener);

  void addResumeListener(void Function() listener);

  void removeResumeListener(void Function() listener);
}
