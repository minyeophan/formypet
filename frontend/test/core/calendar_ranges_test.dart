import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/calendar_ranges.dart';

void main() {
  group('calendar ranges', () {
    test('uses 1950 as the shared first date', () {
      expect(calendarFirstDate, DateTime(1950, 1, 1));
    });

    test('record last date is the end of the current year', () {
      final now = DateTime(2026, 5, 26);

      expect(recordCalendarLastDate(now), DateTime(2026, 12, 31));
    });

    test('birthday last date is today', () {
      final now = DateTime(2026, 5, 26, 14, 30);

      expect(birthdayCalendarLastDate(now), DateTime(2026, 5, 26));
    });

    test('clamps dates to the provided range', () {
      final first = DateTime(1950, 1, 1);
      final last = DateTime(2026, 12, 31);

      expect(clampCalendarDate(DateTime(1949, 12, 31), first, last), first);
      expect(clampCalendarDate(DateTime(2027, 1, 1), first, last), last);
      expect(
        clampCalendarDate(DateTime(2026, 5, 26, 14, 30), first, last),
        DateTime(2026, 5, 26),
      );
    });
  });
}
