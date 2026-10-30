// JSON-file implementation of [ReviewAskStore], via a
// [JsonFileStore] over its own file in the app documents
// directory (atomic tmp+sync+rename writes — the Stage 3 store
// pattern). A separate file, NOT a key in an existing store's
// file: a JsonFileStore owns its file's snapshot, so a second
// store over the same file could overwrite the other owner's
// keys from a stale snapshot.

import 'package:path_provider/path_provider.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../review_ask/review_ask.dart';
import 'json_file_store.dart';
import 'review_ask_store.dart';

class ReviewAskStoreImpl implements ReviewAskStore {
  ReviewAskStoreImpl({DirectoryResolver? directoryResolver})
    : _store = JsonFileStore(
        fileName: _fileName,
        directoryResolver:
            directoryResolver ?? getApplicationDocumentsDirectory,
      );

  static const String _fileName = 'klara_review_ask.json';

  final JsonFileStore _store;

  static const AppFailure _failure = AppFailure(
    messageKey: AppStrings.errorLocal,
  );

  @override
  Future<Result<ReviewAskState>> load() async {
    try {
      final Map<String, dynamic> map = await _store.readMap();
      if (map.isEmpty) {
        return const Success<ReviewAskState>(ReviewAskState());
      }
      return Success<ReviewAskState>(ReviewAskState.fromJson(map));
    } catch (_) {
      return const Failure<ReviewAskState>(_failure);
    }
  }

  @override
  Future<Result<void>> save(ReviewAskState state) async {
    try {
      // JsonFileStore contract: mutate the live snapshot, then
      // write. The record IS the whole file, so replace it.
      final Map<String, dynamic> map = await _store.readMap();
      map
        ..clear()
        ..addAll(state.toJson());
      await _store.writeNow();
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(_failure);
    }
  }
}
