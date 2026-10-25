// Per-file JSON store behind [LocalServiceImpl] (solutions 4.1).
//
// One store owns one file and one shape (a JSON map OR a JSON list —
// never both; mixing shapes is a programmer error). It provides what
// the old direct file IO did not:
//
// - An in-memory snapshot: the file is decoded once and every later
//   read serves the snapshot, so loads never re-decode the whole
//   file (issues F-06/F-07/F-08). Callers mutate the live snapshot
//   and then call [writeNow] or [scheduleWrite]; the snapshot is
//   always the newest truth, even before the disk write lands.
// - Serialised writes: every disk write chains onto one future per
//   file, so concurrent read-modify-write callers cannot interleave
//   and lose each other's updates (issue F-09).
// - Atomic writes: bytes go to `<name>.tmp`, are flushed, then the
//   temp file is renamed over the target — a kill mid-write leaves
//   the old file or the new file intact, never a truncation (issue
//   F-39). A leftover `.tmp` is ignored on load and overwritten by
//   the next write.
// - Coalescing (opt-in per call via [scheduleWrite]): session saves
//   flush at most every ~1.5 s (fixed window — see [scheduleWrite]
//   for why there is no count trigger). Only session saves
//   coalesce; trash, history, settings and analyses always use
//   [writeNow].
// - Best-effort salvage for list files: when the whole file no
//   longer parses (a legacy truncation from the pre-atomic era),
//   complete top-level objects are recovered by brace scanning and
//   the truncated tail is dropped and counted in [salvageSkipped].
//   Map files cannot be brace-salvaged (keys would be lost), so a
//   truncated map file reads as empty; atomic writes prevent new
//   truncations. Per-entry salvage (valid JSON, bad entries) lives
//   in [LocalServiceImpl], which skips unparsable entries.
//
// Crash windows, stated plainly: a coalesced session write that has
// not flushed yet is lost if the app is killed — at most ~1.5 s
// of session marks (a handful of swipes at human speed).
// Backgrounding always flushes first (app-paused is a mandatory
// flush point), so the window only bites on a hard kill.
// Trash, history, settings and analyses are never coalesced,
// so they have no window. A failed disk write keeps the snapshot
// dirty so the next flush retries it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves the directory holding Klara's JSON files. Shared by all
/// stores of one [LocalServiceImpl] so the documents directory is
/// resolved once (Phase 1.4 behaviour, kept).
typedef DirectoryResolver = Future<Directory> Function();

class JsonFileStore {
  JsonFileStore({
    required this.fileName,
    required DirectoryResolver directoryResolver,
  }) : _dirResolver = directoryResolver;

  final String fileName;
  final DirectoryResolver _dirResolver;

  /// Coalescing window for [scheduleWrite] (solutions 4.1: ~1–2 s).
  /// Fixed window, NOT a resetting debounce: the timer starts on
  /// the first pending write and fires 1.5 s later even if more
  /// marks arrive meanwhile, so continuous marking still flushes
  /// mid-stream and the loss bound stays ~1.5 s of marks.
  static const Duration coalesceWindow = Duration(milliseconds: 1500);

  Object? _snapshot;
  bool _isMap = false;
  bool _loaded = false;
  Future<void>? _loadFuture;
  Future<void> _writeChain = Future<void>.value();
  Timer? _timer;
  int _version = 0;
  bool _dirty = false;

  /// Atomic disk writes performed (test observability for the
  /// write-amplification benchmark: 1,000 coalesced marks must not
  /// cost 1,000 writes).
  int diskWrites = 0;

  /// List fragments dropped by brace-scan salvage (cumulative).
  int salvageSkipped = 0;

  /// True when a coalesced write is waiting for its flush.
  bool get isDirty => _dirty;

  Future<Directory> _dir() => _dirResolver();

  Future<void> _ensureLoaded(bool asMap) async {
    if (_loaded) {
      if (_isMap != asMap) {
        throw StateError('JsonFileStore $fileName used as both map and list');
      }
      return;
    }
    final Future<void> pending = _loadFuture ??= _load(asMap);
    try {
      await pending;
    } catch (_) {
      // A failed load must not poison the cache: drop it so a
      // later call retries instead of replaying the same error
      // (same rule Phase 1.4 applied to directory resolution).
      if (identical(_loadFuture, pending)) {
        _loadFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _load(bool asMap) async {
    final Directory dir = await _dir();
    final File file = File('${dir.path}/$fileName');
    _isMap = asMap;
    if (!await file.exists()) {
      _snapshot = asMap ? <String, dynamic>{} : <dynamic>[];
      _loaded = true;
      return;
    }
    final String text = await file.readAsString();
    if (text.trim().isEmpty) {
      _snapshot = asMap ? <String, dynamic>{} : <dynamic>[];
      _loaded = true;
      return;
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (asMap && decoded is Map<String, dynamic>) {
        _snapshot = decoded;
      } else if (!asMap && decoded is List<dynamic>) {
        _snapshot = decoded;
      } else if (!asMap) {
        // Wrong shape for a list file: salvage what can be found.
        _snapshot = _salvageList(text);
      } else {
        _snapshot = <String, dynamic>{};
      }
    } catch (_) {
      // Whole-file parse failure (legacy truncation): lists salvage
      // complete objects, maps read as empty (see file doc).
      _snapshot = asMap ? <String, dynamic>{} : _salvageList(text);
    }
    _loaded = true;
  }

  /// The live snapshot as a map. Mutations to the returned map are
  /// the store's snapshot — call [writeNow] or [scheduleWrite]
  /// afterwards to persist them.
  Future<Map<String, dynamic>> readMap() async {
    await _ensureLoaded(true);
    return _snapshot! as Map<String, dynamic>;
  }

  /// The live snapshot as a list (same mutation contract as
  /// [readMap]).
  Future<List<dynamic>> readList() async {
    await _ensureLoaded(false);
    return _snapshot! as List<dynamic>;
  }

  /// Persists the current snapshot immediately, serialised behind
  /// any in-flight write. A write failure leaves the snapshot
  /// dirty so the next flush retries it.
  Future<void> writeNow() {
    return _enqueueWrite();
  }

  /// Marks the current snapshot for a coalesced write: it flushes
  /// after [coalesceWindow], or on [flush] — whichever comes first.
  ///
  /// DEVIATION from solutions 4.1 (deliberate, see ADR-004): the
  /// doc also names a "~20 marks" early-flush trigger, but that
  /// trigger contradicts the doc's own acceptance benchmark —
  /// 1,000 rapid marks with a 20-mark trigger flush ~50 times
  /// over a growing file, costing ~25x the final size, not the
  /// required ≤2x. With a fixed time window only, 1,000 rapid
  /// marks cost exactly one write (1x). The loss bound stays the
  /// ~1.5 s window (a handful of swipes at human speed), plus the
  /// mandatory flush points, which are unchanged.
  void scheduleWrite() {
    _dirty = true;
    _version++;
    _timer ??= Timer(coalesceWindow, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Writes now if a coalesced write is pending; a no-op otherwise.
  /// Never throws: a failed write keeps the snapshot dirty for the
  /// next flush instead of losing the caller's data.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) {
      return;
    }
    try {
      await _ensureLoaded(_isMap);
      await _enqueueWrite();
    } catch (_) {
      // Keep dirty: the next flush retries. Disk trouble must not
      // surface as a lost session — the snapshot still holds it.
    }
  }

  /// Flushes any pending write and stops the coalescing timer.
  /// Call from test tearDown and service disposal.
  Future<void> close() async {
    await flush();
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _enqueueWrite() {
    final int versionAtEncode = _version;
    final Future<void> run = _writeChain.then((_) async {
      await _ensureLoaded(_isMap);
      final String text = jsonEncode(_snapshot);
      final Directory dir = await _dir();
      final File target = File('${dir.path}/$fileName');
      final File tmp = File('${dir.path}/$fileName.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(target.path);
      diskWrites++;
      // Only clear dirty when nothing was scheduled during the
      // write: a concurrent mutation postdates these bytes and
      // must survive for the next flush.
      if (_version == versionAtEncode) {
        _dirty = false;
      }
    });
    // The chain itself never breaks on a write failure; the
    // returned future still reports it to the awaiting caller.
    _writeChain = run.catchError((Object _) {});
    return run;
  }

  /// Recovers complete top-level objects from a truncated JSON
  /// list file. Fragments that fail to parse and the truncated
  /// tail object are counted in [salvageSkipped].
  List<dynamic> _salvageList(String text) {
    final List<dynamic> found = <dynamic>[];
    int i = text.indexOf('[');
    if (i < 0) {
      return found;
    }
    i++;
    while (i < text.length) {
      while (i < text.length &&
          (text[i] == ' ' ||
              text[i] == '\n' ||
              text[i] == '\r' ||
              text[i] == '\t' ||
              text[i] == ',')) {
        i++;
      }
      if (i >= text.length || text[i] == ']') {
        break;
      }
      if (text[i] != '{' && text[i] != '[') {
        // Garbage between objects: skip it without counting — only
        // failed object parses count as skipped entries.
        i++;
        continue;
      }
      final int start = i;
      int depth = 0;
      bool inString = false;
      bool escaped = false;
      bool closed = false;
      while (i < text.length) {
        final String c = text[i];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (c == '\\') {
            escaped = true;
          } else if (c == '"') {
            inString = false;
          }
        } else {
          if (c == '"') {
            inString = true;
          } else if (c == '{' || c == '[') {
            depth++;
          } else if (c == '}' || c == ']') {
            depth--;
            if (depth == 0) {
              i++;
              closed = true;
              break;
            }
          }
        }
        i++;
      }
      if (!closed) {
        salvageSkipped++;
        break;
      }
      try {
        found.add(jsonDecode(text.substring(start, i)));
      } catch (_) {
        salvageSkipped++;
      }
    }
    return found;
  }
}
