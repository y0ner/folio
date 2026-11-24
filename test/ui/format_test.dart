import 'package:flutter_test/flutter_test.dart';
import 'package:folio/ui/format.dart';

void main() {
  group('formatBytes', () {
    test('formatea bytes, kilobytes, megabytes y gigabytes en español', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(850), '850 B');
      expect(formatBytes(12288), '12 KB');
      expect(formatBytes((3.4 * 1024 * 1024).round()), '3,4 MB');
      expect(formatBytes((1.2 * 1024 * 1024 * 1024).round()), '1,2 GB');
    });
  });

  group('formatOpenedAt', () {
    final now = DateTime(2026, 11, 24, 15, 30);

    test('formatea hoy con hora', () {
      expect(
        formatOpenedAt(DateTime(2026, 11, 24, 14, 5), now: now),
        'Hoy, 14:05',
      );
    });

    test('formatea ayer con hora incluso cerca de medianoche', () {
      expect(
        formatOpenedAt(DateTime(2026, 11, 23, 9, 30), now: now),
        'Ayer, 09:30',
      );
      expect(
        formatOpenedAt(DateTime(2026, 11, 23, 23, 59), now: now),
        'Ayer, 23:59',
      );
    });

    test('formatea fechas del mismo año sin año', () {
      expect(
        formatOpenedAt(DateTime(2026, 11, 12, 10, 0), now: now),
        '12 nov',
      );
      expect(
        formatOpenedAt(DateTime(2026, 1, 5, 8, 15), now: now),
        '5 ene',
      );
    });

    test('formatea fechas de otro año incluyendo el año', () {
      expect(
        formatOpenedAt(DateTime(2025, 11, 12, 18, 0), now: now),
        '12 nov 2025',
      );
    });
  });
}
