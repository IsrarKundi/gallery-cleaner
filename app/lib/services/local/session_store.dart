// Per-row deck sessions over Drift (solutions 6.1; schema v2
// split by fix plan Stage 3, ADR-018).
//
// A session is three small things now, not one blob:
// - the resume position (one [Sessions] row per filter),
// - one [Marks] row per swipe mark,
// - one [SessionFavourites] row per favourited asset.
//
// [save] keeps the interface's whole-session overwrite
// semantics, but writes only the DELTA: it diffs the incoming
// session against a mirror of what this store has persisted
// (loaded from the database on first touch of a filter) and,
// in one transaction, upserts the changed mark rows, deletes
// the removed ones, and touches the progress row only when
// the index moved. One swipe therefore costs one small mark
// row (+ the tiny progress row when the index moved) — never
// a re-encode of the session's whole marks map, which is what
// the v1 blob row paid per swipe (audit F-08's shape inside
// the database). Saves are serialised on one future chain, so
// the deck's unawaited per-mark saves cannot interleave and
// overwrite each other.
//
// The mirror is a write-diff cache only: [load] and [listAll]
// always read the database itself. Every production write
// flows through the single bound LocalService, so the mirror
// cannot drift from the database in the app; a second store
// instance over the same database starts cold and re-reads
// before its first diff.

import 'package:drift/drift.dart';
import 'package:klara/services/local/local_service.dart';

import 'klara_database.dart';

/// What this store believes the database holds for one
/// filter: the diff baseline for [SessionStore.save].
class _StoredSession {
  _StoredSession({
    required this.exists,
    required this.currentIndex,
    required this.marks,
    required this.favourites,
  });

  /// Whether a progress row exists for the filter.
  final bool exists;
  final int currentIndex;
  final Map<String, DeckMark> marks;
  final Set<String> favourites;
}

class SessionStore {
  SessionStore(this._db);

  final KlaraDatabase _db;

  /// Row writes performed by [save], per table (test
  /// observability, the [JsonFileStore.diskWrites] precedent:
  /// a one-mark save must show one mark row, not N).
  int markRowsWritten = 0;
  int favouriteRowsWritten = 0;
  int sessionRowsWritten = 0;

  Future<void> _writeChain = Future<void>.value();
  final Map<String, _StoredSession> _mirror = <String, _StoredSession>{};

  /// Overwrites the session for its filter key, writing only
  /// the rows that changed (see file doc). Serialised behind
  /// any in-flight save; a failure reaches the caller and
  /// leaves the mirror untouched, so the next save re-diffs
  /// against the database's actual state.
  Future<void> save(DeckSession session) {
    final Future<void> run = _writeChain.then((_) => _saveInner(session));
    // The chain itself never breaks on a failed save; the
    // returned future still reports it to the awaiting caller.
    _writeChain = run.catchError((Object _) {});
    return run;
  }

  Future<void> _saveInner(DeckSession session) async {
    final String filterKey = session.filterKey;
    _StoredSession stored = _mirror[filterKey] ?? await _readStored(filterKey);
    int markWrites = 0;
    int favouriteWrites = 0;
    int sessionWrites = 0;
    await _db.transaction(() async {
      if (!stored.exists || stored.currentIndex != session.currentIndex) {
        await _db
            .into(_db.sessions)
            .insert(
              SessionsCompanion.insert(
                filterKey: filterKey,
                currentIndex: session.currentIndex,
              ),
              mode: InsertMode.insertOrReplace,
            );
        sessionWrites++;
      }
      for (final MapEntry<String, DeckMark> entry in session.marks.entries) {
        if (stored.marks[entry.key] != entry.value) {
          await _db
              .into(_db.marks)
              .insert(
                MarksCompanion.insert(
                  filterKey: filterKey,
                  assetId: entry.key,
                  mark: entry.value.name,
                ),
                mode: InsertMode.insertOrReplace,
              );
          markWrites++;
        }
      }
      for (final String id in stored.marks.keys) {
        if (!session.marks.containsKey(id)) {
          await (_db.delete(_db.marks)..where(
                (Marks t) =>
                    t.filterKey.equals(filterKey) & t.assetId.equals(id),
              ))
              .go();
          markWrites++;
        }
      }
      for (final String id in session.favouriteIds) {
        if (!stored.favourites.contains(id)) {
          await _db
              .into(_db.sessionFavourites)
              .insert(
                SessionFavouritesCompanion.insert(
                  filterKey: filterKey,
                  assetId: id,
                ),
                mode: InsertMode.insertOrReplace,
              );
          favouriteWrites++;
        }
      }
      for (final String id in stored.favourites) {
        if (!session.favouriteIds.contains(id)) {
          await (_db.delete(_db.sessionFavourites)..where(
                (SessionFavourites t) =>
                    t.filterKey.equals(filterKey) & t.assetId.equals(id),
              ))
              .go();
          favouriteWrites++;
        }
      }
    });
    markRowsWritten += markWrites;
    favouriteRowsWritten += favouriteWrites;
    sessionRowsWritten += sessionWrites;
    _mirror[filterKey] = _StoredSession(
      exists: true,
      currentIndex: session.currentIndex,
      marks: Map<String, DeckMark>.of(session.marks),
      favourites: Set<String>.of(session.favouriteIds),
    );
  }

  /// The session for [filterKey], or null when none exists.
  Future<DeckSession?> load(String filterKey) async {
    final Session? row = await (_db.select(
      _db.sessions,
    )..where((Sessions t) => t.filterKey.equals(filterKey))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return DeckSession(
      filterKey: row.filterKey,
      currentIndex: row.currentIndex,
      marks: await _readMarks(filterKey),
      favouriteIds: await _readFavourites(filterKey),
    );
  }

  /// Every saved session, in no guaranteed order.
  Future<List<DeckSession>> listAll() async {
    final List<Session> rows = await _db.select(_db.sessions).get();
    if (rows.isEmpty) {
      return <DeckSession>[];
    }
    final Map<String, Map<String, DeckMark>> marksByFilter =
        <String, Map<String, DeckMark>>{};
    for (final Mark row in await _db.select(_db.marks).get()) {
      (marksByFilter[row.filterKey] ??= <String, DeckMark>{})[row.assetId] =
          _parseMark(row.mark);
    }
    final Map<String, Set<String>> favouritesByFilter = <String, Set<String>>{};
    for (final SessionFavourite row
        in await _db.select(_db.sessionFavourites).get()) {
      (favouritesByFilter[row.filterKey] ??= <String>{}).add(row.assetId);
    }
    return <DeckSession>[
      for (final Session row in rows)
        DeckSession(
          filterKey: row.filterKey,
          currentIndex: row.currentIndex,
          marks: marksByFilter[row.filterKey] ?? <String, DeckMark>{},
          favouriteIds: favouritesByFilter[row.filterKey] ?? <String>{},
        ),
    ];
  }

  Future<int> count() async {
    final Expression<int> countExpr = _db.sessions.filterKey.count();
    final TypedResult row = await (_db.selectOnly(
      _db.sessions,
    )..addColumns(<Expression<int>>[countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// The diff baseline for [filterKey], read from the
  /// database (used on a filter's first save through this
  /// store instance).
  Future<_StoredSession> _readStored(String filterKey) async {
    final Session? row = await (_db.select(
      _db.sessions,
    )..where((Sessions t) => t.filterKey.equals(filterKey))).getSingleOrNull();
    final _StoredSession stored = _StoredSession(
      exists: row != null,
      currentIndex: row?.currentIndex ?? 0,
      marks: await _readMarks(filterKey),
      favourites: await _readFavourites(filterKey),
    );
    _mirror[filterKey] = stored;
    return stored;
  }

  Future<Map<String, DeckMark>> _readMarks(String filterKey) async {
    final List<Mark> rows = await (_db.select(
      _db.marks,
    )..where((Marks t) => t.filterKey.equals(filterKey))).get();
    return <String, DeckMark>{
      for (final Mark row in rows) row.assetId: _parseMark(row.mark),
    };
  }

  Future<Set<String>> _readFavourites(String filterKey) async {
    final List<SessionFavourite> rows = await (_db.select(
      _db.sessionFavourites,
    )..where((SessionFavourites t) => t.filterKey.equals(filterKey))).get();
    return <String>{for (final SessionFavourite row in rows) row.assetId};
  }

  /// The one mark-name rule (mirrors [DeckSession.fromJson]):
  /// an unknown name reads as keep, never as an error.
  DeckMark _parseMark(String name) {
    return DeckMark.values.firstWhere(
      (DeckMark m) => m.name == name,
      orElse: () => DeckMark.keep,
    );
  }
}
