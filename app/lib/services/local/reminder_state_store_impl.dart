// JSON-file implementation of [ReminderStateStore], via a
// [JsonFileStore] over its own file in the app documents
// directory (the LocalServiceImpl pattern: atomic writes,
// in-memory snapshot, injectable directory for tests).
//
// A separate file — NOT a key in klara_settings.json — because
// a JsonFileStore owns its file's snapshot: a second store over
// the settings file could overwrite the settings keys from a
// stale snapshot, and vice versa.

import 'package:path_provider/path_provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../notifications/reminder.dart';
import 'json_file_store.dart';
import 'reminder_state_store.dart';

class ReminderStateStoreImpl implements ReminderStateStore {
  ReminderStateStoreImpl({DirectoryResolver? directoryResolver})
    : _store = JsonFileStore(
        fileName: _fileName,
        directoryResolver:
            directoryResolver ?? getApplicationDocumentsDirectory,
      );

  static const String _fileName = 'klara_reminder_state.json';

  final JsonFileStore _store;

  static const AppFailure _failure = AppFailure(
    messageKey: AppStrings.errorLocal,
  );

  @override
  Future<Result<ReminderRecord>> load() async {
    try {
      final Map<String, dynamic> map = await _store.readMap();
      if (map.isEmpty) {
        return const Success<ReminderRecord>(ReminderRecord());
      }
      return Success<ReminderRecord>(ReminderRecord.fromJson(map));
    } catch (_) {
      return const Failure<ReminderRecord>(_failure);
    }
  }

  @override
  Future<Result<void>> save(ReminderRecord record) async {
    try {
      // JsonFileStore contract: mutate the live snapshot, then
      // write. The record IS the whole file, so replace it.
      final Map<String, dynamic> map = await _store.readMap();
      map
        ..clear()
        ..addAll(record.toJson());
      await _store.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(_failure);
    }
  }
}
