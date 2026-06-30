import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/screens/routine/routine_calendar_values.dart';

void main() {
  test('routineDayNumber maps Sunday through Saturday to zero through six', () {
    expect(routineDayNumber(DateTime(2026, 5, 31)), 0);
    expect(routineDayNumber(DateTime(2026, 6, 1)), 1);
    expect(routineDayNumber(DateTime(2026, 6, 6)), 6);
  });

  test('weekly routine only applies on selected weekdays', () {
    final routine = _routine(repeatType: 'weekly', days: const [1, 3]);

    expect(routineAppliesOn(routine, DateTime(2026, 6, 1)), isTrue);
    expect(routineAppliesOn(routine, DateTime(2026, 6, 2)), isFalse);
    expect(routineAppliesOn(routine, DateTime(2026, 6, 3)), isTrue);
  });

  test('biweekly routine uses even week offsets from start date', () {
    final routine = _routine(repeatType: 'biweekly', days: const [1]);

    expect(routineAppliesOn(routine, DateTime(2026, 6, 1)), isTrue);
    expect(routineAppliesOn(routine, DateTime(2026, 6, 8)), isFalse);
    expect(routineAppliesOn(routine, DateTime(2026, 6, 15)), isTrue);
  });

  test(
    'monthly routine keeps start day and interval without clamping day 31',
    () {
      final routine = _routine(
        repeatType: 'monthly',
        startDate: '2026-01-31',
        monthlyInterval: 2,
      );

      expect(routineAppliesOn(routine, DateTime(2026, 3, 31)), isTrue);
      expect(routineAppliesOn(routine, DateTime(2026, 2, 28)), isFalse);
      expect(routineAppliesOn(routine, DateTime(2026, 4, 30)), isFalse);
    },
  );

  test('routine month dates exclude inactive and out of range routines', () {
    final dates = routineDatesForMonth([
      _routine(repeatType: 'weekly', days: const [1]),
      _routine(id: 'inactive', active: false),
      _routine(id: 'future', startDate: '2026-07-01'),
    ], DateTime(2026, 6));

    expect(dates, {
      '2026-06-01',
      '2026-06-08',
      '2026-06-15',
      '2026-06-22',
      '2026-06-29',
    });
  });
}

Routine _routine({
  String id = 'routine',
  String repeatType = 'daily',
  List<int> days = const [],
  String startDate = '2026-06-01',
  String? endDate,
  int monthlyInterval = 1,
  bool active = true,
}) => Routine(
  id: id,
  petId: 'pet',
  label: '루틴',
  typeId: 'medicine',
  repeatType: repeatType,
  times: const ['08:00'],
  days: days,
  startDate: startDate,
  endDate: endDate,
  monthlyInterval: monthlyInterval,
  active: active,
);
