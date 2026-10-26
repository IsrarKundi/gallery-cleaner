// Small string key/value rows over Drift (solutions 6.2).
//
// Holds the migration marker and the schema guard — never
// user data, never in a JSON file.

import 'package:drift/drift.dart';

import 'klara_database.dart';

class MetaStore {
  MetaStore(this._db);

  final KlaraDatabase _db;

  /// The value for [key], or null when absent.
  Future<String?> get(String key) async {
    final MetaEntry? row = await (_db.select(
      _db.metaEntries,
    )..where((MetaEntries t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Upserts [key] to [value].
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.metaEntries)
        .insert(
          MetaEntriesCompanion.insert(key: key, value: value),
          mode: InsertMode.insertOrReplace,
        );
  }
}
