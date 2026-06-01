import '../../models/routine.dart';

bool routineAppliesOn(Routine routine, DateTime date) {
  if (!routine.active) return false;
  final target = _dateOnly(date);
  final start = _tryParseDate(routine.startDate);
  if (start == null || target.isBefore(start)) return false;
  final end = routine.endDate == null ? null : _tryParseDate(routine.endDate!);
  if (end != null && target.isAfter(end)) return false;

  return switch (routine.repeatType) {
    'daily' => true,
    'weekly' => routine.days.contains(routineDayNumber(target)),
    'biweekly' =>
      routine.days.contains(routineDayNumber(target)) &&
          target.difference(start).inDays ~/ 7 % 2 == 0,
    'monthly' =>
      target.day == start.day &&
          _monthDifference(start, target) %
                  (routine.monthlyInterval < 1 ? 1 : routine.monthlyInterval) ==
              0,
    _ => false,
  };
}

Set<String> routineDatesForMonth(List<Routine> routines, DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0);
  final dates = <String>{};
  for (
    var day = DateTime(month.year, month.month);
    !day.isAfter(last);
    day = day.add(const Duration(days: 1))
  ) {
    if (routines.any((routine) => routineAppliesOn(routine, day))) {
      dates.add(_isoDate(day));
    }
  }
  return dates;
}

int routineDayNumber(DateTime date) => date.weekday % 7;

int _monthDifference(DateTime start, DateTime target) =>
    (target.year - start.year) * 12 + target.month - start.month;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime? _tryParseDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? null : _dateOnly(parsed);
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
