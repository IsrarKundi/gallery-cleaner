// Pure deck-model tests: swipe mapping, filter keys, month labels
// and the three-state meter helper (no services, no widgets).

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/deck/model/deck_filter.dart';
import 'package:klara/features/deck/model/space_meter.dart';
import 'package:klara/features/deck/model/swipe_direction.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/trash/trash_entry.dart';

void main() {
  group('markForDrag (requirements §3: locked mapping)', () {
    test('left keep, right delete, up maybe, down favourite', () {
      expect(markForDrag(-100, 0, 80), DeckMark.keep);
      expect(markForDrag(100, 0, 80), DeckMark.delete);
      expect(markForDrag(0, -100, 80), DeckMark.maybe);
      expect(markForDrag(0, 100, 80), DeckMark.favourite);
    });

    test('dominant axis wins on diagonals', () {
      expect(markForDrag(-120, 50, 80), DeckMark.keep);
      expect(markForDrag(40, 120, 80), DeckMark.favourite);
    });

    test('below threshold in both axes is not a swipe', () {
      expect(markForDrag(10, 10, 80), isNull);
      expect(markForDrag(-79, 0, 80), isNull);
    });
  });

  group('DeckFilter', () {
    test('session keys name exactly one filter', () {
      expect(const DeckFilter.all().filterKey, 'all');
      expect(const DeckFilter.album('cam').filterKey, 'album:cam');
      expect(const DeckFilter.month('2026-10').filterKey, 'month:2026-10');
    });

    test('month labels render and bad keys pass through', () {
      expect(monthLabel('2026-10'), 'Oct 2026');
      expect(monthLabel('2025-01'), 'Jan 2025');
      expect(monthLabel('nonsense'), 'nonsense');
      expect(monthLabel('2026-13'), '2026-13');
    });

    test('monthKeysFor sorts newest first', () {
      final List<MediaAsset> assets = <MediaAsset>[
        MediaAsset(
          id: 'a',
          type: MediaAssetType.image,
          width: 1,
          height: 1,
          sizeBytes: 1,
          createDate: DateTime(2025, 1, 1),
          title: 'a',
          albumName: 'X',
        ),
        MediaAsset(
          id: 'b',
          type: MediaAssetType.image,
          width: 1,
          height: 1,
          sizeBytes: 1,
          createDate: DateTime(2026, 10, 1),
          title: 'b',
          albumName: 'X',
        ),
      ];
      expect(monthKeysFor(assets), <String>['2026-10', '2025-01']);
    });
  });

  group('computeSpaceMeter', () {
    test('trashed MB is never counted as freed', () {
      final MediaAsset asset = MediaAsset(
        id: 'a1',
        type: MediaAssetType.image,
        width: 1,
        height: 1,
        sizeBytes: 2000000,
        createDate: DateTime(2026, 10, 1),
        title: 'a1',
        albumName: 'X',
      );
      final SpaceMeterTotals totals = computeSpaceMeter(
        marks: <String, DeckMark>{'a1': DeckMark.delete},
        assetsById: <String, MediaAsset>{'a1': asset},
        trashEntries: <TrashEntry>[
          TrashEntry(
            assetId: 't',
            typeInt: 1,
            width: 1,
            height: 1,
            sizeBytes: 9000000,
            trashedAt: DateTime(2026, 10, 1),
          ),
        ],
        history: <HistoryRecord>[
          HistoryRecord(
            date: DateTime(2026, 10, 2),
            count: 1,
            mbTrashed: 9,
            mbFreed: 0,
          ),
        ],
      );
      expect(totals.markedBytes, 2000000);
      expect(totals.inTrashBytes, 9000000);
      expect(totals.freedBytes, 0);
      expect(totals.recoverableUntil, DateTime(2026, 10, 31));
    });
  });
}
