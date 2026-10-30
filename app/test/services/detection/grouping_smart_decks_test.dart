// Smart-deck predicate + burst tests (requirements §7,
// Phase 2A; Stage 4 updates: screenshots follow the pass
// marking, and blurry/dark left the per-asset predicates —
// they are scan memberships now, covered by
// grouping_stage4_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/detection/smart_decks.dart';
import 'package:klara/services/media/media_asset.dart';

MediaAsset _asset(
  String id, {
  int size = 1000,
  DateTime? date,
  String album = 'Camera',
  MediaAssetType type = MediaAssetType.image,
  bool screenshot = false,
}) {
  return MediaAsset(
    id: id,
    type: type,
    width: 10,
    height: 10,
    sizeBytes: size,
    createDate: date ?? DateTime(2026, 10, 20),
    title: '$id.jpg',
    albumName: album,
    isScreenshot: screenshot,
  );
}

void main() {
  group('decksForAsset', () {
    final DateTime now = DateTime(2026, 10, 25);

    test('screenshots follow the Stage 2 marking, not the album', () {
      // Marked, in an ordinary folder: joins.
      expect(
        decksForAsset(_asset('a', screenshot: true), now),
        contains(SmartDeckId.screenshots),
      );
      // In a folder NAMED Screenshots but not marked: does NOT
      // join anymore (Stage 4 item 8 — the old album rule).
      expect(
        decksForAsset(_asset('b', album: 'Screenshots'), now),
        isNot(contains(SmartDeckId.screenshots)),
      );
    });

    test('missing or empty album names never match name decks', () {
      final Set<SmartDeckId> decks = decksForAsset(_asset('a', album: ''), now);
      expect(decks, isNot(contains(SmartDeckId.whatsapp)));
      expect(decks, isNot(contains(SmartDeckId.downloads)));
    });

    test('whatsapp and downloads match by folder name', () {
      expect(
        decksForAsset(_asset('a', album: 'WhatsApp Images'), now),
        contains(SmartDeckId.whatsapp),
      );
      expect(
        decksForAsset(_asset('a', album: 'Download'), now),
        contains(SmartDeckId.downloads),
      );
    });

    test('videos, large and old predicates', () {
      final Set<SmartDeckId> video = decksForAsset(
        _asset('v', type: MediaAssetType.video),
        now,
      );
      expect(video, contains(SmartDeckId.videos));
      final Set<SmartDeckId> large = decksForAsset(
        _asset('l', size: 10 * 1024 * 1024),
        now,
      );
      expect(large, contains(SmartDeckId.large));
      final Set<SmartDeckId> justUnder = decksForAsset(
        _asset('s', size: 10 * 1024 * 1024 - 1),
        now,
      );
      expect(justUnder, isNot(contains(SmartDeckId.large)));
      final Set<SmartDeckId> old = decksForAsset(
        _asset('o', date: DateTime(2026, 7, 1)),
        now,
      );
      expect(old, contains(SmartDeckId.old));
      final Set<SmartDeckId> recent = decksForAsset(
        _asset('r', date: DateTime(2026, 10, 20)),
        now,
      );
      expect(recent, isNot(contains(SmartDeckId.old)));
    });

    test('blurry and dark are NOT per-asset predicates anymore', () {
      // Stage 4: no asset ever earns blurry/dark from
      // decksForAsset — those decks come from scan memberships.
      final Set<SmartDeckId> decks = decksForAsset(_asset('a'), now);
      expect(decks, isNot(contains(SmartDeckId.blurry)));
      expect(decks, isNot(contains(SmartDeckId.dark)));
    });
  });

  group('burstAssetIds', () {
    test('3+ photos within 5s gaps form a burst', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 3)),
        _asset('c', date: DateTime(2026, 10, 20, 12, 0, 5)),
        _asset('d', date: DateTime(2026, 10, 20, 13, 0, 0)),
      ];
      expect(burstAssetIds(assets), <String>{'a', 'b', 'c'});
    });

    test('a 6s gap splits the run and pairs are dropped', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 6)),
        _asset('c', date: DateTime(2026, 10, 20, 12, 0, 7)),
      ];
      expect(burstAssetIds(assets), isEmpty);
    });

    test('videos never join a burst', () {
      final List<MediaAsset> assets = <MediaAsset>[
        _asset('a', date: DateTime(2026, 10, 20, 12, 0, 0)),
        _asset(
          'v',
          date: DateTime(2026, 10, 20, 12, 0, 1),
          type: MediaAssetType.video,
        ),
        _asset('b', date: DateTime(2026, 10, 20, 12, 0, 2)),
      ];
      // Only two photos remain in the run: below the burst minimum.
      expect(burstAssetIds(assets), isEmpty);
    });
  });
}
