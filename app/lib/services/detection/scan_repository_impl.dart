// Production [ScanRepository]: one memoised, cancellable,
// pausable library scan shared by the hub, Duplicates, and
// smart-deck entry (solutions 4.2; contract in scan_repository.dart).
//
// How a run works: [_runScan] drives one [LibraryScanner] and
// fans its pages out to every subscriber. A subscriber that joins
// late replays the run's past pages first (same onPage code path
// as live pages), so controllers never see a partial accumulation
// — except a controller that resubscribes after clearing its own
// state, which is exactly the replay it needs. A run that is
// cancelled stops at the next page/asset boundary: no checkpoint
// save, no onPage for the partial page, no stale write.
//
// Memoisation: only a run that finished without cancellation or
// page failure is memoised. A run that completes while dirty is
// NOT memoised (its pages may predate the change); the next start
// re-scans and clears the dirty flag at start.

import 'dart:async';

import '../local/local_service.dart';
import '../media/library_enumeration_service.dart';
import '../media/media_asset.dart';
import '../media/media_service.dart';
import 'library_scanner.dart';
import 'photo_assessment.dart';
import 'scan_repository.dart';

/// Cancellation token for one scan run. Callbacks registered via
/// [onCancel] fire exactly once, synchronously inside [cancel] —
/// including completing pause-gate waiters, so a scan paused on a
/// backgrounded app still aborts promptly when cancelled.
class ScanCancelToken {
  bool _cancelled = false;
  final List<void Function()> _onCancel = <void Function()>[];

  bool get isCancelled => _cancelled;

  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _onCancel.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    final List<void Function()> callbacks = List<void Function()>.of(_onCancel);
    _onCancel.clear();
    for (final void Function() callback in callbacks) {
      callback();
    }
  }
}

class _Subscriber {
  _Subscriber({this.onPage, this.onProgress, this.onDegraded});

  final void Function(
    List<MediaAsset> page,
    Map<String, PhotoAssessment> fresh,
  )?
  onPage;
  final void Function(int scanned, int? estimatedTotal)? onProgress;

  /// Fired when the running scan's analysis falls back to the UI
  /// thread (solutions 5.1). Never fired for memoised replays:
  /// a replay re-analyses nothing, so a historical degraded flag
  /// must not show a "slower" state for an instant replay.
  final void Function()? onDegraded;
}

class _ScanSubscription implements ScanSubscription {
  _ScanSubscription(this._repository, this._subscriber);

  final ScanRepositoryImpl _repository;
  final _Subscriber _subscriber;
  bool _cancelled = false;

  @override
  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _repository._detach(_subscriber);
  }
}

class _RunningScan {
  _RunningScan({required this.token});

  final ScanCancelToken token;

  /// Assigned immediately after construction, before the run is
  /// published: [_runScan] updates this object directly as pages
  /// arrive, so late subscribers replay live state correctly.
  late final Future<LibraryScan> future;

  final List<List<MediaAsset>> pages = <List<MediaAsset>>[];
  final List<Map<String, PhotoAssessment>> pageFresh =
      <Map<String, PhotoAssessment>>[];
  final List<MediaAsset> assets = <MediaAsset>[];
  final Map<String, PhotoAssessment> analyses = <String, PhotoAssessment>{};
  int scanned = 0;
  int? estimatedTotal;
  bool pageFailed = false;

  /// True once this run's analysis has fallen back to the UI
  /// thread (solutions 5.1). Late subscribers to a degraded live
  /// run get the callback immediately on subscribe.
  bool degraded = false;
}

class ScanRepositoryImpl implements ScanRepository {
  ScanRepositoryImpl({
    required this.media,
    required this.local,
    this.enumeration,
  });

  final MediaService media;
  final LocalService local;

  /// The one-pass enumeration (fix plan Stage 2), handed to
  /// each run's scanner: a run forces one fresh pass and pages
  /// over it. Optional — without it the scanner keeps its
  /// paged plugin source.
  final LibraryEnumerationService? enumeration;

  final List<_Subscriber> _subscribers = <_Subscriber>[];
  _RunningScan? _running;
  LibraryScan? _completed;
  List<List<MediaAsset>> _completedPages = <List<MediaAsset>>[];
  List<Map<String, PhotoAssessment>> _completedFresh =
      <Map<String, PhotoAssessment>>[];
  bool _dirty = false;

  bool _paused = false;
  final List<Completer<bool>> _pauseWaiters = <Completer<bool>>[];

  @override
  bool get isScanning => _running != null;

  @override
  bool get isDirty => _dirty;

  @override
  void markDirty() {
    _dirty = true;
    // The memo is stale from here on; a running scan keeps going
    // (its pages are live data) but will not be memoised.
    _completed = null;
    _completedPages = <List<MediaAsset>>[];
    _completedFresh = <Map<String, PhotoAssessment>>[];
  }

  @override
  ScanSubscription subscribe({
    void Function(List<MediaAsset> page, Map<String, PhotoAssessment> fresh)?
    onPage,
    void Function(int scanned, int? estimatedTotal)? onProgress,
    void Function()? onDegraded,
  }) {
    final _Subscriber subscriber = _Subscriber(
      onPage: onPage,
      onProgress: onProgress,
      onDegraded: onDegraded,
    );
    _subscribers.add(subscriber);
    // Replay past pages first (running or memoised), then live
    // pages follow through the same callbacks.
    final _RunningScan? running = _running;
    if (running != null) {
      for (int i = 0; i < running.pages.length; i++) {
        subscriber.onPage?.call(running.pages[i], running.pageFresh[i]);
      }
      subscriber.onProgress?.call(running.scanned, running.estimatedTotal);
      if (running.degraded) {
        subscriber.onDegraded?.call();
      }
    } else if (_completed != null) {
      for (int i = 0; i < _completedPages.length; i++) {
        subscriber.onPage?.call(_completedPages[i], _completedFresh[i]);
      }
      final LibraryScan done = _completed!;
      subscriber.onProgress?.call(done.scanned, null);
    }
    return _ScanSubscription(this, subscriber);
  }

  void _detach(_Subscriber subscriber) {
    _subscribers.remove(subscriber);
    // Deliberately no auto-cancel: the run belongs to the
    // repository, not the controller (see scan_repository.dart).
    // A detached controller's callbacks simply stop firing.
  }

  @override
  Future<LibraryScan> start() {
    final LibraryScan? done = _completed;
    if (done != null && !_dirty) {
      return Future<LibraryScan>.value(done);
    }
    final _RunningScan? running = _running;
    if (running != null) {
      return running.future;
    }
    return _beginRun();
  }

  @override
  Future<LibraryScan> restart() {
    cancelCurrent();
    return _beginRun();
  }

  @override
  void cancelCurrent() {
    _running?.token.cancel();
  }

  @override
  void pause() {
    _paused = true;
  }

  @override
  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    final List<Completer<bool>> waiters = List<Completer<bool>>.of(
      _pauseWaiters,
    );
    _pauseWaiters.clear();
    for (final Completer<bool> waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(true);
      }
    }
  }

  Future<bool> _waitIfPaused(ScanCancelToken token) {
    if (!_paused) {
      return Future<bool>.value(true);
    }
    final Completer<bool> waiter = Completer<bool>();
    _pauseWaiters.add(waiter);
    token.onCancel(() {
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    });
    return waiter.future;
  }

  Future<LibraryScan> _beginRun() {
    // A fresh run answers the dirtiness: clear it at start so a
    // change DURING the run re-dirties and blocks memoisation.
    // It also invalidates the old memo: if this run fails, there
    // is no memo to fall back to (a stale memo would be worse
    // than a re-scan).
    _dirty = false;
    _completed = null;
    _completedPages = <List<MediaAsset>>[];
    _completedFresh = <Map<String, PhotoAssessment>>[];
    final ScanCancelToken token = ScanCancelToken();
    final _RunningScan run = _RunningScan(token: token);
    run.future = _runScan(run);
    _running = run;
    return run.future;
  }

  Future<LibraryScan> _runScan(_RunningScan run) async {
    final ScanCancelToken token = run.token;
    final LibraryScanner scanner = LibraryScanner(
      media: media,
      local: local,
      enumeration: enumeration,
    );
    final LibraryScan result = await scanner.scan(
      isCancelled: () => token.isCancelled,
      waitIfPaused: () => _waitIfPaused(token),
      onDegraded: () {
        run.degraded = true;
        final List<_Subscriber> listeners = List<_Subscriber>.of(_subscribers);
        for (final _Subscriber subscriber in listeners) {
          subscriber.onDegraded?.call();
        }
      },
      // NOTE: onPage below carries fresh analyses only (4.2), so
      // the full map (cached + fresh) is merged from the final
      // result after the scan — see below. Callers reading the
      // final result (e.g. Duplicates grouping) need the full map.
      onPage: (List<MediaAsset> page, Map<String, PhotoAssessment> fresh) {
        // Direct run updates: a subscriber joining mid-run replays
        // exactly these pages, so live state and replay agree.
        run.pages.add(page);
        run.pageFresh.add(fresh);
        run.assets.addAll(page);
        run.analyses.addAll(fresh);
        run.scanned = run.assets.length;
        final List<_Subscriber> listeners = List<_Subscriber>.of(_subscribers);
        for (final _Subscriber subscriber in listeners) {
          subscriber.onPage?.call(page, fresh);
        }
      },
      onProgress: (int count, int? total) {
        run.scanned = count;
        run.estimatedTotal = total;
        final List<_Subscriber> listeners = List<_Subscriber>.of(_subscribers);
        for (final _Subscriber subscriber in listeners) {
          subscriber.onProgress?.call(count, total);
        }
      },
    );
    run.pageFailed = result.pageFailed;
    // onPage carried fresh analyses only, so the run map is
    // missing cached analyses until now: merge the scanner's full
    // map (cached + fresh). Same values for fresh ids, so this is
    // idempotent — but without it, callers reading the final
    // result (e.g. Duplicates grouping from the cache) would see
    // an empty map whenever every asset was already cached.
    run.analyses.addAll(result.assessments);
    if (identical(_running, run)) {
      _running = null;
    }
    // One outcome object, memoised as-is when clean: a later
    // start() returns this exact result (identical, not a copy).
    // A cancelled/failed run leaves the memo as _beginRun left it
    // (empty) — it must never wipe a NEWER run's memo if this run
    // completes late.
    final LibraryScan outcome = LibraryScan(
      assets: run.assets,
      assessments: run.analyses,
      memberships: result.memberships,
      scanned: run.scanned,
      pageFailed: run.pageFailed,
      cancelled: result.cancelled,
      degraded: result.degraded,
    );
    if (!result.cancelled && !run.pageFailed && !_dirty) {
      _completed = outcome;
      _completedPages = run.pages;
      _completedFresh = run.pageFresh;
    }
    return outcome;
  }
}
