// Engine tests for the state-based reminders (fix plan
// Stage 1, requirements §7): ReminderServiceImpl observes the
// app's persisted state through fakes and applies plans through
// a fake notification gateway — state detection, the toggle and
// permission gates, waiting-count truth (trashed and
// unresolvable ids never count), cancellation when the work is
// finished, and the read-failure rule (a failed read leaves the
// previous schedule untouched).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/local/reminder_state_store.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/notifications/notification_service.dart';
import 'package:klara/services/notifications/reminder.dart';
import 'package:klara/services/notifications/reminder_service_impl.dart';
import 'package:klara/services/trash/trash_entry.dart';

class _FakeLocal implements LocalService {
  // Stage 4: memberships default to "none stored" in these fakes.
  @override
  Future<Result<ScanMemberships>> loadScanMemberships() async =>
      const Success<ScanMemberships>(ScanMemberships.empty);

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) async =>
      const Success<void>(null);
  AppSettings settings = const AppSettings(reminders: true);
  List<DeckSession> sessions = <DeckSession>[];
  List<TrashEntry> trashEntries = <TrashEntry>[];
  List<HistoryRecord> history = <HistoryRecord>[];
  List<DateTime> completionDays = <DateTime>[];
  bool failSessions = false;

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      Success<AppSettings>(settings);

  @override
  Future<Result<void>> saveSettings(AppSettings next) async {
    settings = next;
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    if (failSessions) {
      return const Failure<List<DeckSession>>(
        AppFailure(messageKey: 'errorLocal'),
      );
    }
    return Success<List<DeckSession>>(sessions);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    for (final DeckSession session in sessions) {
      if (session.filterKey == filterKey) {
        return Success<DeckSession?>(session);
      }
    }
    return const Success<DeckSession?>(null);
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      Success<List<TrashEntry>>(trashEntries);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      Success<List<HistoryRecord>>(history);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      Success<List<DateTime>>(completionDays);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

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
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async =>
      const Success<double>(1024);

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
      const Success<void>(null);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});

  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async =>
      const Success<int>(0);
}

class _FakeMedia implements MediaService {
  _FakeMedia(this.assetsById);

  final Map<String, MediaAsset> assetsById;
  MediaPermission permission = MediaPermission.grantedFull;

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      Success<MediaPermission>(permission);

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return Success<List<MediaAsset>>(<MediaAsset>[
      for (final String id in ids)
        if (assetsById.containsKey(id)) assetsById[id]!,
    ]);
  }

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async =>
      const Success<List<MediaAlbum>>(<MediaAlbum>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async => const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));
}

class _FakeNotifications implements NotificationService {
  bool enabled = true;
  int cancelCalls = 0;
  final List<({int id, String title, String body, DateTime fireAt})> scheduled =
      <({int id, String title, String body, DateTime fireAt})>[];

  /// Ordered gateway calls ('cancelAll' / 'schedule'), so tests
  /// can prove the cancel-all path runs before any scheduling.
  final List<String> events = <String>[];

  @override
  Future<Result<bool>> areEnabled() async => Success<bool>(enabled);

  @override
  Future<Result<bool>> requestPermission() async => Success<bool>(enabled);

  @override
  Future<Result<void>> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    events.add('schedule');
    scheduled.add((id: id, title: title, body: body, fireAt: fireAt));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> cancelAllReminders() async {
    events.add('cancelAll');
    cancelCalls++;
    scheduled.clear();
    return const Success<void>(null);
  }
}

class _FakeReminderStore implements ReminderStateStore {
  ReminderRecord record = const ReminderRecord();

  @override
  Future<Result<ReminderRecord>> load() async =>
      Success<ReminderRecord>(record);

  @override
  Future<Result<void>> save(ReminderRecord next) async {
    record = next;
    return const Success<void>(null);
  }
}

MediaAsset asset(String id, {MediaAssetType type = MediaAssetType.image}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 1),
    title: id,
    albumName: 'Camera',
  );
}

DeckSession session(String key, Map<String, DeckMark> marks) {
  return DeckSession(
    filterKey: key,
    currentIndex: marks.length,
    marks: marks,
    favouriteIds: const <String>{},
  );
}

/// Monday 2 Nov 2026, 10:00.
final DateTime t0 = DateTime(2026, 11, 2, 10);

void main() {
  late _FakeLocal local;
  late _FakeMedia media;
  late _FakeNotifications notifications;
  late _FakeReminderStore store;
  late DateTime now;
  late ReminderServiceImpl engine;

  setUp(() {
    local = _FakeLocal();
    media = _FakeMedia(<String, MediaAsset>{
      'p1': asset('p1'),
      'p2': asset('p2'),
      'v1': asset('v1', type: MediaAssetType.video),
    });
    notifications = _FakeNotifications();
    store = _FakeReminderStore();
    now = t0;
    engine = ReminderServiceImpl(
      local: local,
      media: media,
      notifications: notifications,
      reminderStore: store,
      clock: () => now,
    );
  });

  test('toggle off: everything is cancelled, nothing scheduled', () async {
    local.settings = const AppSettings(reminders: false);
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{'p1': DeckMark.delete}),
    ];
    await engine.refresh();
    expect(notifications.cancelCalls, 1);
    expect(notifications.scheduled, isEmpty);
    expect(store.record.tracks, isEmpty);
  });

  test('permission off: nothing scheduled, planned slots cleared', () async {
    notifications.enabled = false;
    store.record = ReminderRecord(
      tracks: <ReminderStateKind, ReminderTrack>{
        ReminderStateKind.waiting: ReminderTrack(
          startedAt: t0,
          planned: <int, DateTime>{0: DateTime(2026, 11, 3, 19)},
        ),
      },
    );
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{'p1': DeckMark.delete}),
    ];
    await engine.refresh();
    expect(notifications.scheduled, isEmpty);
    final ReminderTrack track = store.record.tracks[ReminderStateKind.waiting]!;
    expect(track.planned, isEmpty);
    expect(track.startedAt, t0);
  });

  test('waiting photos schedule state 1 at +1d and +4d evenings', () async {
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{
        'p1': DeckMark.delete,
        'p2': DeckMark.delete,
        'v1': DeckMark.delete,
        'gone': DeckMark.delete, // unresolvable: never counts
        'kept': DeckMark.keep,
      }),
      session('smart:screenshots', <String, DeckMark>{
        'p1': DeckMark.delete, // same photo in two decks: once
      }),
    ];
    // 'p2' was already trashed through the deck flow: its mark
    // stays in the session but it must not count as waiting.
    local.trashEntries = <TrashEntry>[
      TrashEntry(
        assetId: 'p2',
        typeInt: 1,
        width: 100,
        height: 100,
        sizeBytes: 1000,
        trashedAt: t0,
      ),
    ];
    await engine.refresh();
    final List<DateTime> fires = notifications.scheduled
        .map((s) => s.fireAt)
        .toList();
    // Waiting (p1 photo + v1 video) fires +1d/+4d; the
    // unfinished ladder also runs (marks exist, no completion):
    // its simple step defers to +2d, its counted step to +5d.
    expect(fires, <DateTime>[
      DateTime(2026, 11, 3, 19),
      DateTime(2026, 11, 4, 19),
      DateTime(2026, 11, 6, 19),
      DateTime(2026, 11, 7, 19),
    ]);
    final waiting = notifications.scheduled.firstWhere(
      (s) => s.id == reminderNotificationId(ReminderStateKind.waiting, 0),
    );
    expect(waiting.title, 'Finish what you started 🗑️');
    final counted = notifications.scheduled.firstWhere(
      (s) => s.id == reminderNotificationId(ReminderStateKind.unfinished, 1),
    );
    expect(
      counted.body,
      '1 photos and 1 videos are lined up for deletion. '
      'Open the app and finish the job.',
    );
    expect(store.record.tracks[ReminderStateKind.waiting]!.startedAt, t0);
  });

  test(
    'duplicates-session marks alone never start the waiting state',
    () async {
      // Checker N5 / ADR-016 §1: the Trash-tab union (ADR-015)
      // never displays the duplicates session, so its delete marks
      // must not start state 1 or feed the counted message — the
      // reminder would name photos the user cannot find waiting.
      // The marks still count as swipes (the unfinished ladder
      // runs), but with zero truthful waiting counts its counted
      // step is not planned either.
      local.sessions = <DeckSession>[
        session('duplicates', <String, DeckMark>{
          'p1': DeckMark.delete,
          'v1': DeckMark.delete,
        }),
      ];
      await engine.refresh();
      expect(
        store.record.tracks.containsKey(ReminderStateKind.waiting),
        isFalse,
      );
      final List<int> ids = notifications.scheduled.map((s) => s.id).toList();
      expect(
        ids,
        isNot(contains(reminderNotificationId(ReminderStateKind.waiting, 0))),
      );
      expect(
        ids,
        isNot(contains(reminderNotificationId(ReminderStateKind.waiting, 1))),
      );
      expect(
        ids,
        isNot(
          contains(reminderNotificationId(ReminderStateKind.unfinished, 1)),
        ),
      );
      expect(
        ids,
        contains(reminderNotificationId(ReminderStateKind.unfinished, 0)),
      );
    },
  );

  test('counted message counts exclude duplicates-session marks', () async {
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{'p1': DeckMark.delete}),
      session('duplicates', <String, DeckMark>{
        'p2': DeckMark.delete,
        'v1': DeckMark.delete,
      }),
    ];
    await engine.refresh();
    // Only the 'all' session's photo is waiting in the Trash
    // tab: 1 photo, 0 videos — the duplicates marks (p2, v1)
    // never enter the counted body.
    final counted = notifications.scheduled.firstWhere(
      (s) => s.id == reminderNotificationId(ReminderStateKind.unfinished, 1),
    );
    expect(
      counted.body,
      '1 photos and 0 videos are lined up for deletion. '
      'Open the app and finish the job.',
    );
    expect(
      notifications.scheduled.map((s) => s.id),
      contains(reminderNotificationId(ReminderStateKind.waiting, 0)),
    );
  });

  test(
    'finishing the work cancels the reminders at the next refresh',
    () async {
      local.sessions = <DeckSession>[
        session('all', <String, DeckMark>{'p1': DeckMark.delete}),
      ];
      await engine.refresh();
      expect(notifications.scheduled, isNotEmpty);

      // The user empties the waiting set (marks resolved), then
      // the app is paused / relaunched: the waiting reminders are
      // gone. (The unfinished ladder legitimately remains — the
      // user has swiped but never finished a deck.)
      local.sessions = <DeckSession>[
        session('all', <String, DeckMark>{'p1': DeckMark.keep}),
      ];
      now = DateTime(2026, 11, 2, 21);
      await engine.refresh();
      expect(
        notifications.scheduled.map((s) => s.id),
        isNot(contains(reminderNotificationId(ReminderStateKind.waiting, 0))),
      );
      expect(
        notifications.scheduled.map((s) => s.id),
        isNot(contains(reminderNotificationId(ReminderStateKind.waiting, 1))),
      );
      expect(
        store.record.tracks.containsKey(ReminderStateKind.waiting),
        isFalse,
      );
    },
  );

  test('never swiped + access granted schedules state 5 at +2d/+7d', () async {
    await engine.refresh();
    expect(notifications.scheduled, hasLength(2));
    expect(notifications.scheduled[0].fireAt, DateTime(2026, 11, 4, 19));
    expect(notifications.scheduled[1].fireAt, DateTime(2026, 11, 9, 19));
    expect(notifications.scheduled[0].title, 'Fun way to declutter ✨');
  });

  test('never swiped but access denied schedules nothing', () async {
    media.permission = MediaPermission.denied;
    await engine.refresh();
    expect(notifications.scheduled, isEmpty);
  });

  test(
    'unfinished deck: state 3 fires, counted step waits for counts',
    () async {
      local.sessions = <DeckSession>[
        session('all', <String, DeckMark>{'p1': DeckMark.keep}),
      ];
      await engine.refresh();
      expect(notifications.scheduled, hasLength(1));
      expect(notifications.scheduled.single.fireAt, DateTime(2026, 11, 3, 19));
      expect(
        notifications.scheduled.single.title,
        'Curious what we\'ll find? 👀',
      );
    },
  );

  test('finished deck with nothing deleted schedules state 2', () async {
    local.completionDays = <DateTime>[DateTime(2026, 11, 1)];
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{'p1': DeckMark.keep}),
    ];
    await engine.refresh();
    expect(notifications.scheduled, hasLength(2));
    expect(notifications.scheduled.first.title, 'Your results are ready ✅');
    expect(notifications.scheduled[0].fireAt, DateTime(2026, 11, 3, 19));
    expect(notifications.scheduled[1].fireAt, DateTime(2026, 11, 6, 19));
  });

  group('legacy weekly nudge (id 7001)', () {
    // The cancel-all path is what kills the legacy weekly nudge
    // (its id set, 7001 included, is pinned in
    // notification_service_impl_test.dart). These tests pin WHEN
    // the engine runs it: before scheduling on a live refresh,
    // and alone — scheduling nothing — on the off paths.
    test('a live refresh cancels everything before scheduling', () async {
      local.sessions = <DeckSession>[
        session('all', <String, DeckMark>{'p1': DeckMark.delete}),
      ];
      await engine.refresh();
      expect(notifications.scheduled, isNotEmpty);
      expect(notifications.events.first, 'cancelAll');
      expect(
        notifications.events.where((String e) => e == 'cancelAll'),
        hasLength(1),
      );
      expect(
        notifications.events.indexOf('schedule'),
        greaterThan(notifications.events.indexOf('cancelAll')),
      );
    });

    test('toggle off runs the cancel-all path and schedules nothing', () async {
      local.settings = const AppSettings(reminders: false);
      local.sessions = <DeckSession>[
        session('all', <String, DeckMark>{'p1': DeckMark.delete}),
      ];
      await engine.refresh();
      expect(notifications.events, <String>['cancelAll']);
      expect(notifications.scheduled, isEmpty);
    });

    test(
      'permission off runs the cancel-all path and schedules nothing',
      () async {
        notifications.enabled = false;
        local.sessions = <DeckSession>[
          session('all', <String, DeckMark>{'p1': DeckMark.delete}),
        ];
        await engine.refresh();
        expect(notifications.events, <String>['cancelAll']);
        expect(notifications.scheduled, isEmpty);
      },
    );
  });

  test('a failed read leaves the previous schedule untouched', () async {
    local.sessions = <DeckSession>[
      session('all', <String, DeckMark>{'p1': DeckMark.delete}),
    ];
    await engine.refresh();
    final int scheduledBefore = notifications.scheduled.length;
    final int cancelsBefore = notifications.cancelCalls;
    expect(scheduledBefore, greaterThan(0));

    local.failSessions = true;
    await engine.refresh();
    expect(notifications.scheduled, hasLength(scheduledBefore));
    expect(notifications.cancelCalls, cancelsBefore);
  });
}
