import '../../models/routine.dart';

String routineRepeatLabel(Routine routine) {
  if (routine.repeatType == 'monthly' && routine.monthlyInterval < 1) {
    return '반복 간격 확인 필요';
  }
  final base = routine.repeatType == 'monthly'
      ? (routine.monthlyInterval <= 1 ? '매월' : '매 ${routine.monthlyInterval}개월')
      : switch (routine.repeatType) {
          'daily' => '매일',
          'weekly' => '매주',
          'biweekly' => '격주',
          _ => routine.repeatType,
        };
  if (routine.repeatType == 'weekly' || routine.repeatType == 'biweekly') {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final selected = routine.days
        .where((day) => day >= 0 && day < 7)
        .map((day) => weekdays[day])
        .join(', ');
    if (selected.isNotEmpty) return '$base · $selected';
  }
  return base;
}

String routineTimeSummary(Routine routine) {
  if (routine.times.isEmpty) return '시간 없음';
  final times = [...routine.times]..sort();
  return times.length == 1
      ? times.first
      : '${times.first} 외 ${times.length - 1}개';
}

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
