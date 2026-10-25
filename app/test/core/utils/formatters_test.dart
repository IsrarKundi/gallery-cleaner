import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/formatters.dart';

void main() {
  group('Formatters.formatBytes', () {
    test('formats bytes, kilobytes, megabytes and gigabytes', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(512), '512 B');
      expect(Formatters.formatBytes(1024), '1 KB');
      expect(Formatters.formatBytes(1536), '1.5 KB');
      expect(Formatters.formatBytes(1048576), '1 MB');
      expect(Formatters.formatBytes(3355443), '3.2 MB');
      expect(Formatters.formatBytes(1073741824), '1 GB');
    });

    test('clamps negative input to zero', () {
      expect(Formatters.formatBytes(-5), '0 B');
    });
  });

  group('Formatters.formatCount', () {
    test('groups thousands with commas', () {
      expect(Formatters.formatCount(0), '0');
      expect(Formatters.formatCount(999), '999');
      expect(Formatters.formatCount(1243), '1,243');
      expect(Formatters.formatCount(1234567), '1,234,567');
    });
  });

  group('Formatters.formatDate', () {
    test('formats as day, short month and year', () {
      expect(Formatters.formatDate(DateTime(2025, 3, 12)), '12 Mar 2025');
      expect(Formatters.formatDate(DateTime(2026, 10, 25)), '25 Oct 2026');
    });
  });
}
