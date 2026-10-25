import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/trash/trash_entry.dart';

void main() {
  group('TrashEntry', () {
    test('recoverableUntil is exactly trashedAt plus 30 days', () {
      final TrashEntry entry = TrashEntry(
        assetId: '42',
        typeInt: 1,
        width: 100,
        height: 200,
        sizeBytes: 12345,
        trashedAt: _trashedAt,
      );
      expect(entry.recoverableUntil, DateTime(2026, 11, 24, 10, 30));
    });

    test('JSON round trip preserves every field', () {
      final TrashEntry entry = TrashEntry(
        assetId: '7',
        typeInt: 2,
        width: 1920,
        height: 1080,
        sizeBytes: 999999,
        trashedAt: _trashedAt,
      );
      final TrashEntry back = TrashEntry.fromJson(entry.toJson());
      expect(back.assetId, '7');
      expect(back.typeInt, 2);
      expect(back.width, 1920);
      expect(back.height, 1080);
      expect(back.sizeBytes, 999999);
      expect(back.trashedAt, _trashedAt);
      expect(back.recoverableUntil, entry.recoverableUntil);
    });
  });
}

final DateTime _trashedAt = DateTime(2026, 10, 25, 10, 30);
