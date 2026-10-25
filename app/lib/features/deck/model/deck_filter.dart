import '../../../services/media/media_asset.dart';

// Phase 1 deck filters only (requirements §7): All, one album/folder,
// or one month. Smart decks (Screenshots, WhatsApp, Downloads, Videos,
// Large, Old, Bursts) are Phase 2 and must not be added here.
//
// One filter at a time: picking a month clears an album pick and vice
// versa, so a session key always names exactly one filter.

enum DeckFilterKind { all, album, month }

class DeckFilter {
  const DeckFilter.all()
    : kind = DeckFilterKind.all,
      albumId = null,
      monthKey = null;

  const DeckFilter.album(this.albumId)
    : kind = DeckFilterKind.album,
      monthKey = null;

  const DeckFilter.month(this.monthKey)
    : kind = DeckFilterKind.month,
      albumId = null;

  final DeckFilterKind kind;
  final String? albumId;
  final String? monthKey;

  /// Session key (LocalService): `all`, `album:<id>` or `month:<key>`.
  /// Changing the filter starts a fresh queue under a new key.
  String get filterKey {
    switch (kind) {
      case DeckFilterKind.all:
        return 'all';
      case DeckFilterKind.album:
        return 'album:$albumId';
      case DeckFilterKind.month:
        return 'month:$monthKey';
    }
  }

  bool get isAll => kind == DeckFilterKind.all;

  @override
  bool operator ==(Object other) {
    return other is DeckFilter &&
        other.kind == kind &&
        other.albumId == albumId &&
        other.monthKey == monthKey;
  }

  @override
  int get hashCode => Object.hash(kind, albumId, monthKey);
}

/// Display label for a `yyyy-MM` month key, e.g. `2026-10` -> "Oct 2026".
/// An unparseable key is returned unchanged, never crashed on.
String monthLabel(String monthKey) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final List<String> parts = monthKey.split('-');
  if (parts.length != 2) {
    return monthKey;
  }
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return monthKey;
  }
  return '${months[month - 1]} $year';
}

/// Month keys (`yyyy-MM`) present in [assets], newest first. Pure
/// helper so the controller stays under its line budget.
List<String> monthKeysFor(List<MediaAsset> assets) {
  final Set<String> keys = <String>{};
  for (final MediaAsset asset in assets) {
    final DateTime date = asset.createDate;
    keys.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
  }
  final List<String> sorted = keys.toList()
    ..sort((String a, String b) => b.compareTo(a));
  return sorted;
}
