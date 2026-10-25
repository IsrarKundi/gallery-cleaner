import '../../../services/media/media_asset.dart';

/// Summary metadata for a single calendar month's photos.
class MonthSummary {
  const MonthSummary({
    required this.monthKey,
    required this.monthName,
    required this.year,
    required this.count,
    required this.totalBytes,
    required this.coverAsset,
    this.progress = 0.0,
  });

  /// `yyyy-MM` key, e.g. `2026-10`.
  final String monthKey;

  /// 3-letter month uppercase, e.g. `OCT`.
  final String monthName;

  final int year;
  final int count;
  final int totalBytes;
  final MediaAsset? coverAsset;
  final double progress;
}

const List<String> _monthNames = <String>[
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// Extracts unique years from [assets], newest first.
List<int> availableYearsFor(List<MediaAsset> assets) {
  if (assets.isEmpty) {
    return <int>[DateTime.now().year];
  }
  final Set<int> years = <int>{};
  for (final MediaAsset asset in assets) {
    years.add(asset.createDate.year);
  }
  final List<int> sorted = years.toList()
    ..sort((int a, int b) => b.compareTo(a));
  return sorted;
}

/// Groups [assets] for [targetYear] into calendar months.
List<MonthSummary> groupAssetsByMonth({
  required List<MediaAsset> assets,
  required int targetYear,
  bool ascending = false,
}) {
  final Map<int, List<MediaAsset>> byMonth = <int, List<MediaAsset>>{};
  for (final MediaAsset asset in assets) {
    if (asset.createDate.year == targetYear) {
      byMonth
          .putIfAbsent(asset.createDate.month, () => <MediaAsset>[])
          .add(asset);
    }
  }

  final List<int> months = byMonth.keys.toList()
    ..sort((int a, int b) => ascending ? a.compareTo(b) : b.compareTo(a));

  return months.map((int m) {
    final List<MediaAsset> list = byMonth[m]!;
    final int bytes = list.fold<int>(
      0,
      (int s, MediaAsset a) => s + a.sizeBytes,
    );
    final String monthKey = '$targetYear-${m.toString().padLeft(2, '0')}';
    return MonthSummary(
      monthKey: monthKey,
      monthName: _monthNames[m - 1],
      year: targetYear,
      count: list.length,
      totalBytes: bytes,
      coverAsset: list.firstOrNull,
    );
  }).toList();
}
