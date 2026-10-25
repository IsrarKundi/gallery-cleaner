// Phase 4.4: the pure page-0 merge — new photos prepend, gone
// page-0 photos drop, the current card stays current, marks are
// never touched here (the caller owns them).
import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/deck/model/deck_queue.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(String id, [DateTime? date]) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: date ?? DateTime(2026, 10, 1),
    title: id,
    albumName: 'All',
  );
}

List<MediaAsset> _ids(List<String> ids) =>
    ids.map((String id) => _asset(id)).toList();

List<String> _names(List<MediaAsset> assets) =>
    assets.map((MediaAsset a) => a.id).toList();

void main() {
  test('prepends new photos, keeps order and index', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 'c']),
      freshPageZero: _ids(<String>['n1', 'n2', 'a', 'b', 'c']),
      oldPageZero: _ids(<String>['a', 'b', 'c']),
      pageSize: 50,
      index: 1,
    );
    expect(_names(merged.queue), <String>['n1', 'n2', 'a', 'b', 'c']);
    expect(merged.index, 3); // same card 'b'
  });

  test('drops gone page-0 photos and adjusts the index', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 'c', 'd']),
      freshPageZero: _ids(<String>['a', 'c', 'd']),
      oldPageZero: _ids(<String>['a', 'b', 'c', 'd']),
      pageSize: 50,
      index: 3, // 'd'
    );
    expect(_names(merged.queue), <String>['a', 'c', 'd']);
    expect(merged.index, 2); // same card 'd'
  });

  test('a deleted current card yields the next card', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 'c']),
      freshPageZero: _ids(<String>['a', 'c']),
      oldPageZero: _ids(<String>['a', 'b', 'c']),
      pageSize: 50,
      index: 1, // 'b' is gone
    );
    expect(_names(merged.queue), <String>['a', 'c']);
    expect(merged.index, 1); // 'c' becomes current
  });

  test('deletions beyond page 0 are not detected', () {
    // 'z' was never in page 0, so its absence from the fresh
    // page 0 says nothing — it stays (full reload corrects it).
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 'z']),
      freshPageZero: _ids(<String>['a', 'b']),
      oldPageZero: _ids(<String>['a', 'b']),
      pageSize: 50,
      index: 2,
    );
    expect(_names(merged.queue), <String>['a', 'b', 'z']);
    expect(merged.index, 2);
  });

  test('empty fresh page drops only the old page 0', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 't']),
      freshPageZero: <MediaAsset>[],
      oldPageZero: _ids(<String>['a', 'b']),
      pageSize: 50,
      index: 2, // 't'
    );
    expect(_names(merged.queue), <String>['t']);
    expect(merged.index, 0);
  });

  test('empty old page 0 only ever prepends', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b']),
      freshPageZero: _ids(<String>['n1', 'a', 'b']),
      oldPageZero: _ids(<String>[]),
      pageSize: 50,
      index: 0,
    );
    expect(_names(merged.queue), <String>['n1', 'a', 'b']);
    expect(merged.index, 1); // same card 'a'
  });

  test('empty queue fills from the fresh page', () {
    final merged = mergePageZero(
      queue: <MediaAsset>[],
      freshPageZero: _ids(<String>['n1', 'n2']),
      oldPageZero: _ids(<String>[]),
      pageSize: 50,
      index: 0,
    );
    expect(_names(merged.queue), <String>['n1', 'n2']);
    expect(merged.index, 0);
  });

  test('finished deck with new photos points at the first new card', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b']),
      freshPageZero: _ids(<String>['n1', 'a', 'b']),
      oldPageZero: _ids(<String>['a', 'b']),
      pageSize: 50,
      index: 2, // finished sentinel
    );
    expect(_names(merged.queue), <String>['n1', 'a', 'b']);
    expect(merged.index, 0);
  });

  test('finished deck with only a removal keeps the sentinel', () {
    final merged = mergePageZero(
      queue: _ids(<String>['a', 'b', 'c']),
      freshPageZero: _ids(<String>['b', 'c']),
      oldPageZero: _ids(<String>['a', 'b', 'c']),
      pageSize: 50,
      index: 3, // finished sentinel
    );
    expect(_names(merged.queue), <String>['b', 'c']);
    expect(merged.index, 2); // still finished
  });

  test('full page: displaced tail members are kept, newer deletions drop', () {
    // Page size 3, newest first. Old page 0: a (Oct 5), b (Oct 4),
    // c (Oct 3). Fresh page 0: n1 (Oct 6), a (Oct 5), d (Oct 3
    // 12:00, new). Window end = d, Oct 3 12:00. Member b (Oct 4)
    // is absent AND newer than the window end — a present b
    // would sort inside the window, so b is provably deleted.
    // Member c (Oct 3) is older than the window end, so it may
    // merely have been displaced past the window by n1/d — kept.
    final List<MediaAsset> old = <MediaAsset>[
      _asset('a', DateTime(2026, 10, 5)),
      _asset('b', DateTime(2026, 10, 4)),
      _asset('c', DateTime(2026, 10, 3)),
    ];
    final List<MediaAsset> fresh = <MediaAsset>[
      _asset('n1', DateTime(2026, 10, 6)),
      _asset('a', DateTime(2026, 10, 5)),
      _asset('d', DateTime(2026, 10, 3, 12)),
    ];
    final merged = mergePageZero(
      queue: old,
      freshPageZero: fresh,
      oldPageZero: old,
      pageSize: 3,
      index: 0, // 'a'
    );
    // n1, d prepend; b drops (deleted); c stays (displaced).
    expect(_names(merged.queue), <String>['n1', 'd', 'a', 'c']);
    expect(merged.index, 2); // same card 'a'
  });

  test('full page: tie-date members are kept, not assumed deleted', () {
    // Fresh window end and the absent member share one date:
    // order among ties is unspecified, so the member may sit
    // just past the window — kept.
    final DateTime d = DateTime(2026, 10, 3);
    final List<MediaAsset> old = <MediaAsset>[
      _asset('a', d.add(const Duration(days: 1))),
      _asset('b', d),
      _asset('c', d),
    ];
    final List<MediaAsset> fresh = <MediaAsset>[
      _asset('n1', d.add(const Duration(days: 2))),
      _asset('a', d.add(const Duration(days: 1))),
      _asset('b', d),
    ];
    final merged = mergePageZero(
      queue: old,
      freshPageZero: fresh,
      oldPageZero: old,
      pageSize: 3,
      index: 1, // 'b'
    );
    expect(_names(merged.queue), <String>['n1', 'a', 'b', 'c']);
    expect(merged.index, 2); // same card 'b'
  });
}
