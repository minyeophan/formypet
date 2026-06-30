import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/routine/routine_schedule_values.dart';

void main() {
  test('schedule date picker range spans current and next calendar year', () {
    final now = DateTime(2026, 6, 1, 12);

    expect(scheduleFirstDate(now), DateTime(2026, 1, 1));
    expect(scheduleLastDate(now), DateTime(2027, 12, 31));
  });

  test(
    'timed range moves end date and time up to start when it is earlier',
    () {
      final range = normalizeScheduleRange(
        startDate: DateTime(2026, 6, 2),
        startTime: const TimeOfDay(hour: 10, minute: 30),
        endDate: DateTime(2026, 6, 1),
        endTime: const TimeOfDay(hour: 9, minute: 0),
        allDay: false,
      );

      expect(range.endDate, DateTime(2026, 6, 2));
      expect(range.endTime, const TimeOfDay(hour: 10, minute: 30));
      expect(range.wasAdjusted, isTrue);
    },
  );

  test('all day range preserves hidden end time while moving end date', () {
    final range = normalizeScheduleRange(
      startDate: DateTime(2026, 6, 2),
      startTime: const TimeOfDay(hour: 10, minute: 30),
      endDate: DateTime(2026, 6, 1),
      endTime: const TimeOfDay(hour: 23, minute: 59),
      allDay: true,
    );

    expect(range.endDate, DateTime(2026, 6, 2));
    expect(range.endTime, const TimeOfDay(hour: 23, minute: 59));
    expect(range.wasAdjusted, isTrue);
  });
}
