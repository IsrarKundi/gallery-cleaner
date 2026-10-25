/// Pure formatting helpers (AGENTS.md: core/utils holds pure formatters).
///
/// No dependencies: dates are hand-rolled month names and counts are
/// grouped by hand, so no new package is needed. Nothing here touches
/// photo content, storage or the network.
class Formatters {
  Formatters._();

  static const List<String> _units = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  static const List<String> _months = <String>[
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

  static const List<String> _fullMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Short month name (e.g. 1 -> "Jan", 10 -> "Oct").
  static String formatMonth(int month) {
    if (month < 1 || month > 12) return '';
    return _months[month - 1];
  }

  /// Full month name (e.g. 10 -> "October").
  static String formatFullMonth(int month) {
    if (month < 1 || month > 12) return '';
    return _fullMonths[month - 1];
  }

  /// Formats a byte count in 1024-based units with at most one decimal,
  /// e.g. 512 -> "512 B", 1536 -> "1.5 KB", 1048576 -> "1 MB".
  static String formatBytes(int bytes) {
    final int value = bytes < 0 ? 0 : bytes;
    if (value < 1024) {
      return '$value ${_units[0]}';
    }
    double size = value.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < _units.length - 1) {
      size /= 1024;
      unit++;
    }
    final String text = size % 1 == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$text ${_units[unit]}';
  }

  /// Formats an MB value (as stored on [HistoryRecord]) with at most
  /// one decimal, e.g. 12.0 -> "12 MB", 12.5 -> "12.5 MB".
  static String formatMb(double mb) {
    final double value = mb < 0 ? 0 : mb;
    final String text = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text MB';
  }

  /// Groups a count with commas, e.g. 1243 -> "1,243".
  static String formatCount(int count) {
    final String digits = count.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    final String grouped = buffer.toString();
    return count < 0 ? '-$grouped' : grouped;
  }

  /// Formats a date as "12 Mar 2025".
  static String formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}
