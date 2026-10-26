// Per-row deck sessions over Drift (solutions 6.1).
//
// Marks and favourites are stored as the same JSON the file
// store used, so [DeckSession.fromJson] parses them identically
// (unknown mark names still default to keep; a row that fails
// to parse is skipped exactly as a bad file entry was).

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:klara/services/local/local_service.dart';

import 'klara_database.dart';

class SessionStore {
  SessionStore(this._db);

  final KlaraDatabase _db;

  /// Overwrites the session for its filter key.
  Future<void> save(DeckSession session) async {
    final Map<String, dynamic> json = session.toJson();
    await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            filterKey: session.filterKey,
            currentIndex: session.currentIndex,
            marksJson: jsonEncode(json['marks']),
            favouritesJson: jsonEncode(json['favouriteIds']),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// The session for [filterKey], or null when none exists or
  /// its row fails to parse (mirrors file-store salvage).
  Future<DeckSession?> load(String filterKey) async {
    final Session? row = await (_db.select(
      _db.sessions,
    )..where((Sessions t) => t.filterKey.equals(filterKey))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _fromRow(row);
  }

  /// Every saved session, in no guaranteed order. Bad rows are
  /// skipped, never fatal.
  Future<List<DeckSession>> listAll() async {
    final List<Session> rows = await _db.select(_db.sessions).get();
    final List<DeckSession> sessions = <DeckSession>[];
    for (final Session row in rows) {
      final DeckSession? session = _fromRow(row);
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.sessions.filterKey.count();
    final TypedResult row = await (_db.selectOnly(
      _db.sessions,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  DeckSession? _fromRow(Session row) {
    try {
      return DeckSession.fromJson(<String, dynamic>{
        'filterKey': row.filterKey,
        'currentIndex': row.currentIndex,
        'marks': jsonDecode(row.marksJson) as Map<String, dynamic>,
        'favouriteIds': jsonDecode(row.favouritesJson) as List<dynamic>,
      });
    } catch (_) {
      return null;
    }
  }
}
