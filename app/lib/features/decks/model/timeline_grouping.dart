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

/// Builds one month summary. Shared by [groupAssetsByMonth] (batch)
/// and the hub's incremental accumulation (solutions 4.3), so both
/// paths produce identical summaries. [coverAsset] is the first
/// asset seen for the month in scan order (newest first).
MonthSummary monthSummaryFor({
  required int year,
  required int month,
  required int count,
  required int totalBytes,
  required MediaAsset? coverAsset,
}) {
  return MonthSummary(
    monthKey: '$year-${month.toString().padLeft(2, '0')}',
    monthName: _monthNames[month - 1],
    year: year,
    count: count,
    totalBytes: totalBytes,
    coverAsset: coverAsset,
  );
}

/// Phase 4.3 incremental timeline state: total bytes, years, and
/// per-month accumulators, built one asset at a time as scan
/// pages arrive — never recomputed over the whole library in
/// build(). A hub rebuild then costs O(months), not O(library).
/// Summaries produced here are identical to [groupAssetsByMonth]
/// over the full list (see the equivalence test): scan order is
/// newest first, so the first asset added for a month is that
/// month's cover, as in the batch grouping.
class TimelineAccumulator {
  int totalBytes = 0;
  final Set<int> _years = <int>{};
  final Map<int, Map<int, _MonthAccum>> _months =
      <int, Map<int, _MonthAccum>>{};

  /// Adds one scanned asset (call once per asset, in scan order).
  void add(MediaAsset asset) {
    totalBytes += asset.sizeBytes;
    _years.add(asset.createDate.year);
    final Map<int, _MonthAccum> yearMap = _months.putIfAbsent(
      asset.createDate.year,
      () => <int, _MonthAccum>{},
    );
    final _MonthAccum monthAcc = yearMap.putIfAbsent(
      asset.createDate.month,
      () => _MonthAccum(),
    );
    monthAcc.count++;
    monthAcc.bytes += asset.sizeBytes;
    monthAcc.cover ??= asset;
  }

  /// Resets all accumulated state (a fresh scan starts empty).
  void clear() {
    totalBytes = 0;
    _years.clear();
    _months.clear();
  }

  /// Years present in the accumulated library, newest first
  /// (current year when nothing is accumulated yet, matching the
  /// old batch behaviour for the empty state).
  List<int> get years {
    if (_years.isEmpty) {
      return <int>[DateTime.now().year];
    }
    final List<int> sorted = _years.toList()
      ..sort((int a, int b) => b.compareTo(a));
    return sorted;
  }

  /// Month summaries for [year] from the accumulators — O(months).
  List<MonthSummary> monthsForYear(int year, {bool ascending = false}) {
    final Map<int, _MonthAccum>? byMonth = _months[year];
    if (byMonth == null) {
      return <MonthSummary>[];
    }
    final List<int> months = byMonth.keys.toList()
      ..sort((int a, int b) => ascending ? a.compareTo(b) : b.compareTo(a));
    return months.map((int m) {
      final _MonthAccum acc = byMonth[m]!;
      return monthSummaryFor(
        year: year,
        month: m,
        count: acc.count,
        totalBytes: acc.bytes,
        coverAsset: acc.cover,
      );
    }).toList();
  }
}

/// Per-month accumulator. [cover] is the first asset added for
/// the month in scan order.
class _MonthAccum {
  int count = 0;
  int bytes = 0;
  MediaAsset? cover;
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
    return monthSummaryFor(
      year: targetYear,
      month: m,
      count: list.length,
      totalBytes: bytes,
      coverAsset: list.firstOrNull,
    );
  }).toList();
}
