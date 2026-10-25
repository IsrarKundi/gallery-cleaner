// Shared library scan (solutions 4.2): one memoised scan future
// for the hub, Duplicates, and smart-deck entry, instead of one
// full scan per screen.
//
// Ownership rules (see ADR-004 for the reasoning):
// - The scan belongs to this repository (a permanent service), not
//   to any controller. Controllers subscribe for page callbacks
//   and unsubscribe in onClose; unsubscribing DETACHES the
//   controller's callbacks (a result arriving after the controller
//   left is dropped) but does NOT cancel the shared run — a
//   returning controller replays past pages and joins the live
//   run, so leave-and-return neither restarts nor duplicates work.
// - A completed scan is memoised until [markDirty] (library change
//   on resume, 4.4): a later [start] replays its pages through the
//   subscriber's callbacks and returns the completed result with
//   no media calls. A failed or cancelled scan is never memoised.
// - [start] while a scan runs JOINS it (same future, replayed past
//   pages + live pages). [restart] cancels the running scan and
//   starts fresh; a subscriber awaiting the cancelled run gets a
//   result with `cancelled` set and is expected to call [start]
//   again to join the fresh run.
// - [pause]/[resume] gate the scan at page boundaries for
//   backgrounding (4.4): pausing never loses progress — resuming
//   continues from the next page, never restarts.

import '../media/media_asset.dart';
import 'library_scanner.dart';
import 'photo_analysis.dart';

/// A controller's attachment to the shared scan. Cancel detaches
/// the callbacks; it never cancels the shared run itself.
abstract class ScanSubscription {
  void cancel();
}

/// The shared scan owner (see file doc).
abstract class ScanRepository {
  /// True while a scan run is in flight.
  bool get isScanning;

  /// True when the memoised scan is stale (library changed).
  bool get isDirty;

  /// Marks the memoised scan stale; the next [start] re-scans.
  /// Does not cancel a running scan (its pages are live data).
  void markDirty();

  /// Attaches page/progress callbacks. Past pages (of a running or
  /// memoised scan) replay immediately, in order, then live pages
  /// follow. The subscriber must [ScanSubscription.cancel] in
  /// onClose. [onDegraded] fires when a live run's analysis falls
  /// back to the UI thread (solutions 5.1); it never fires for
  /// memoised replays, which re-analyse nothing.
  ScanSubscription subscribe({
    void Function(List<MediaAsset> page, Map<String, PhotoAnalysis> fresh)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
    void Function()? onDegraded,
  });

  /// Ensures a scan is running and returns its result: the running
  /// future when joining, the memoised result when clean. Pages
  /// arrive through the subscriber's callbacks, not this future.
  Future<LibraryScan> start();

  /// Cancels any running scan and starts fresh. A subscriber
  /// awaiting the cancelled run gets a `cancelled` result.
  Future<LibraryScan> restart();

  /// Pauses the running scan at the next page boundary (4.4).
  void pause();

  /// Resumes a paused scan from the next page (never restarts).
  void resume();

  /// Cancels the running scan, if any. Its future completes with
  /// a `cancelled` result; nothing further is written.
  void cancelCurrent();
}
