// Implementation of [ReminderService] (wipe. fix plan Stage 1).
//
// Observation truth (ADR-016): every fact comes from state the
// app already persists — no new tracking is invented.
//
// - Waiting photos/videos: delete marks across the saved deck
//   sessions the Trash tab's union (ADR-015) can show — Clean
//   filter sessions and smart decks — minus the ids already
//   recorded as trashed, resolved through
//   MediaService.getAssetsByIds. The `duplicates` session is
//   excluded: the union never displays it (its marks are
//   reviewed inside the Duplicates deck's own flow), so counting
//   it would point the user at photos they cannot find waiting
//   in the Trash tab. Unresolvable ids (already trashed or
//   deleted — MediaStore hides them, the same rule Review's own
//   session loader relies on) never count, so the reminder can
//   only name photos that are genuinely waiting.
// - Finished deck: a recorded completion day (both deck
//   controllers record one when a session's final mark lands).
// - Ever swiped / ever deleted: any session mark exists / any
//   Trash record or history record exists.
// - Media granted: MediaService.requestPermission (the same
//   call the deck warm-up makes at every launch; it prompts
//   only when access was never decided, which the deck's own
//   first-run flow already handles before any swipe can exist).

import 'dart:async';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../lifecycle/app_lifecycle.dart';
import '../local/local_service.dart';
import '../local/reminder_state_store.dart';
import '../media/media_asset.dart';
import '../media/media_service.dart';
import '../trash/trash_entry.dart';
import 'notification_service.dart';
import 'reminder.dart';
import 'reminder_planner.dart';
import 'reminder_service.dart';

class ReminderServiceImpl implements ReminderService {
  ReminderServiceImpl({
    required this.local,
    required this.media,
    required this.notifications,
    required this.reminderStore,
    this.lifecycle,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    lifecycle?.addPauseListener(_onPause);
  }

  final LocalService local;
  final MediaService media;
  final NotificationService notifications;

  /// Where the per-state tracks live between refreshes.
  final ReminderStateStore reminderStore;

  /// Optional: when wired (production), every app pause triggers
  /// a refresh — the user has just left, so what they left
  /// unfinished is final for this session.
  final AppLifecycle? lifecycle;

  final DateTime Function() _clock;
  final ReminderPlanner _planner = const ReminderPlanner();

  /// Session key of the Duplicates deck (DuplicatesController.
  /// sessionKey — a feature constant the service layer cannot
  /// import). Its marks are reviewed in that deck's own flow and
  /// never appear in the Trash-tab union (ADR-015), so they are
  /// excluded from the waiting observation (ADR-016 §1).
  static const String _duplicatesSessionKey = 'duplicates';

  bool _refreshing = false;
  bool _refreshAgain = false;

  void _onPause() {
    unawaited(refresh());
  }

  @override
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        await _refreshOnce();
      } while (_refreshAgain);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshOnce() async {
    try {
      final Result<AppSettings> settingsResult = await local.loadSettings();
      final AppSettings? settings = settingsResult.fold(
        onSuccess: (AppSettings value) => value,
        onFailure: (_) => null,
      );
      if (settings == null) {
        return;
      }
      if (!settings.reminders) {
        // Off means off — including anything an older build (or
        // an earlier ON period) left scheduled.
        await notifications.cancelAllReminders();
        return;
      }

      final Result<bool> enabledResult = await notifications.areEnabled();
      final bool enabled = enabledResult.fold(
        onSuccess: (bool value) => value,
        onFailure: (_) => false,
      );
      if (!enabled) {
        // Permission revoked (or never granted): schedule
        // nothing, and clear the planned slots so steps are not
        // later counted as sent when they never fired. The
        // tracks themselves (start times, sent steps) survive.
        await notifications.cancelAllReminders();
        final Result<ReminderRecord> recordResult = await reminderStore.load();
        final ReminderRecord? record = recordResult.fold(
          onSuccess: (ReminderRecord value) => value,
          onFailure: (_) => null,
        );
        if (record != null) {
          bool changed = false;
          for (final ReminderTrack track in record.tracks.values) {
            if (track.planned.isNotEmpty) {
              track.planned.clear();
              changed = true;
            }
          }
          if (changed) {
            await reminderStore.save(record);
          }
        }
        return;
      }

      final ReminderObservation? observed = await _observe();
      if (observed == null) {
        // A read failed: leave the existing schedule untouched.
        return;
      }
      final Result<ReminderRecord> recordResult = await reminderStore.load();
      final ReminderRecord? record = recordResult.fold(
        onSuccess: (ReminderRecord value) => value,
        onFailure: (_) => null,
      );
      if (record == null) {
        return;
      }

      final ReminderPlan plan = _planner.plan(
        now: _clock(),
        observed: observed,
        record: record,
      );

      await notifications.cancelAllReminders();
      for (final ScheduledReminder reminder in plan.schedule) {
        await notifications.scheduleReminder(
          id: reminder.id,
          title: AppStrings.tr(reminder.titleKey),
          body: reminder.needsCounts
              ? AppStrings.tr(reminder.bodyKey, <String, String>{
                  'photos': '${observed.waitingPhotos}',
                  'videos': '${observed.waitingVideos}',
                })
              : AppStrings.tr(reminder.bodyKey),
          fireAt: reminder.fireAt,
        );
      }
      await reminderStore.save(plan.record);
    } catch (_) {
      // A reminder refresh must never crash or block the host
      // screen (splash, Settings, lifecycle). The next launch,
      // pause or toggle retries.
    }
  }

  /// Gathers the observation, or null when any read failed (the
  /// caller then keeps the previous schedule).
  Future<ReminderObservation?> _observe() async {
    final Result<List<DeckSession>> sessionsResult = await local.listSessions();
    final List<DeckSession>? sessions = sessionsResult.fold(
      onSuccess: (List<DeckSession> value) => value,
      onFailure: (_) => null,
    );
    if (sessions == null) {
      return null;
    }
    final Result<List<TrashEntry>> trashResult = await local.loadTrashEntries();
    final List<TrashEntry>? trashEntries = trashResult.fold(
      onSuccess: (List<TrashEntry> value) => value,
      onFailure: (_) => null,
    );
    if (trashEntries == null) {
      return null;
    }
    final Result<List<HistoryRecord>> historyResult = await local.loadHistory();
    final List<HistoryRecord>? history = historyResult.fold(
      onSuccess: (List<HistoryRecord> value) => value,
      onFailure: (_) => null,
    );
    if (history == null) {
      return null;
    }
    final Result<List<DateTime>> daysResult = await local.loadCompletionDays();
    final List<DateTime>? completionDays = daysResult.fold(
      onSuccess: (List<DateTime> value) => value,
      onFailure: (_) => null,
    );
    if (completionDays == null) {
      return null;
    }

    bool everSwiped = false;
    final Set<String> deleteIds = <String>{};
    for (final DeckSession session in sessions) {
      if (session.marks.isNotEmpty) {
        everSwiped = true;
      }
      if (session.filterKey == _duplicatesSessionKey) {
        // Not part of the waiting set (see the file header):
        // the Trash-tab union never shows this session, so its
        // marks must not start the waiting state or feed the
        // counted message. They still count as swipes above.
        continue;
      }
      for (final MapEntry<String, DeckMark> mark in session.marks.entries) {
        if (mark.value == DeckMark.delete) {
          deleteIds.add(mark.key);
        }
      }
    }
    final Set<String> trashedIds = trashEntries
        .map((TrashEntry entry) => entry.assetId)
        .toSet();
    deleteIds.removeAll(trashedIds);

    int waitingPhotos = 0;
    int waitingVideos = 0;
    if (deleteIds.isNotEmpty) {
      final Result<List<MediaAsset>> assetsResult = await media.getAssetsByIds(
        deleteIds.toList(),
      );
      final List<MediaAsset>? assets = assetsResult.fold(
        onSuccess: (List<MediaAsset> value) => value,
        onFailure: (_) => null,
      );
      if (assets == null) {
        return null;
      }
      for (final MediaAsset asset in assets) {
        if (asset.type == MediaAssetType.video) {
          waitingVideos++;
        } else {
          waitingPhotos++;
        }
      }
    }

    // Permission only decides the never-swiped state; a failed
    // or denied read simply leaves that state false.
    bool mediaGranted = false;
    if (!everSwiped) {
      final Result<MediaPermission> permissionResult = await media
          .requestPermission();
      mediaGranted = permissionResult.fold(
        onSuccess: (MediaPermission value) => value != MediaPermission.denied,
        onFailure: (_) => false,
      );
    }

    return ReminderObservation(
      waitingPhotos: waitingPhotos,
      waitingVideos: waitingVideos,
      finishedDeck: completionDays.isNotEmpty,
      everDeleted: trashEntries.isNotEmpty || history.isNotEmpty,
      everSwiped: everSwiped,
      mediaGranted: mediaGranted,
    );
  }
}
