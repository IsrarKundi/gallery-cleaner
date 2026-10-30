// Phase 4.4: one observer delivers pause/resume transitions,
// flushes pending writes on pause, and forwards library-change
// flags. Driven via handleStateChange (no WidgetsBinding needed).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/lifecycle/app_lifecycle_impl.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/library_change_source.dart';
import 'package:klara/services/trash/trash_entry.dart';

class _FakeLocal implements LocalService {
  // Stage 4: memberships default to "none stored" in these fakes.
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  int flushCalls = 0;

  @override
  Future<void> flushPendingWrites() async {
    flushCalls++;
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      const Success<DeckSession?>(null);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      const Success<List<DeckSession>>(<DeckSession>[]);

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      const Success<Map<String, DateTime>>(<String, DateTime>{});

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<double>> loadGoalTargetMb() async => const Success<double>(0);

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
      const Success<void>(null);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      const Success<List<DateTime>>(<DateTime>[]);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
}

class _FakeChangeSource implements LibraryChangeSource {
  final StreamController<void> events = StreamController<void>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<void> get onLibraryChanged => events.stream;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

void main() {
  test('pause fires listeners once and flushes', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    int pauseCount = 0;
    lifecycle.addPauseListener(() => pauseCount++);
    await lifecycle.handleStateChange(AppLifecycleState.paused);
    expect(lifecycle.isBackgrounded, isTrue);
    expect(pauseCount, 1);
    expect(local.flushCalls, 1);

    // A second pause is a no-op (already backgrounded).
    await lifecycle.handleStateChange(AppLifecycleState.paused);
    expect(pauseCount, 1);
    expect(local.flushCalls, 1);
  });

  test('resume without prior pause fires nothing', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    int resumeCount = 0;
    lifecycle.addResumeListener(() => resumeCount++);
    await lifecycle.handleStateChange(AppLifecycleState.resumed);
    expect(lifecycle.isBackgrounded, isFalse);
    expect(resumeCount, 0);
    expect(local.flushCalls, 0);
  });

  test('pause then resume clears backgrounded and fires resume', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    int resumeCount = 0;
    lifecycle.addResumeListener(() => resumeCount++);
    await lifecycle.handleStateChange(AppLifecycleState.paused);
    await lifecycle.handleStateChange(AppLifecycleState.resumed);
    expect(lifecycle.isBackgrounded, isFalse);
    expect(resumeCount, 1);
  });

  test('inactive is ignored; detached counts as background', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    int pauseCount = 0;
    lifecycle.addPauseListener(() => pauseCount++);
    await lifecycle.handleStateChange(AppLifecycleState.inactive);
    expect(lifecycle.isBackgrounded, isFalse);
    expect(pauseCount, 0);
    await lifecycle.handleStateChange(AppLifecycleState.detached);
    expect(lifecycle.isBackgrounded, isTrue);
    expect(pauseCount, 1);
  });

  test('a throwing listener does not block the rest or the flush', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    int secondCount = 0;
    lifecycle.addPauseListener(() => throw StateError('boom'));
    lifecycle.addPauseListener(() => secondCount++);
    await lifecycle.handleStateChange(AppLifecycleState.paused);
    expect(secondCount, 1);
    expect(local.flushCalls, 1);
  });

  test('library change flags forward; detach stops forwarding', () async {
    final _FakeLocal local = _FakeLocal();
    final _FakeChangeSource source = _FakeChangeSource();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(
      local: local,
      changeSource: source,
    );
    lifecycle.attach();
    expect(source.startCalls, 1);
    int forwarded = 0;
    final StreamSubscription<void> sub = lifecycle.libraryChanged.listen(
      (_) => forwarded++,
    );
    source.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(forwarded, 1);
    lifecycle.detach();
    expect(source.stopCalls, 1);
    source.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(forwarded, 1);
    await sub.cancel();
  });

  test('no source wired means the stream never emits', () async {
    final _FakeLocal local = _FakeLocal();
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(local: local);
    lifecycle.attach();
    int forwarded = 0;
    final StreamSubscription<void> sub = lifecycle.libraryChanged.listen(
      (_) => forwarded++,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(forwarded, 0);
    await sub.cancel();
    lifecycle.detach();
  });
}
