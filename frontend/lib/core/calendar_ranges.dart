final DateTime calendarFirstDate = DateTime(1950, 1, 1);

DateTime recordCalendarLastDate(DateTime now) {
  return DateTime(now.year, 12, 31);
}

DateTime birthdayCalendarLastDate(DateTime now) {
  return DateTime(now.year, now.month, now.day);
}

DateTime clampCalendarDate(
  DateTime value,
  DateTime firstDate,
  DateTime lastDate,
) {
  final dateOnly = DateTime(value.year, value.month, value.day);
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  if (dateOnly.isBefore(first)) return first;
  if (dateOnly.isAfter(last)) return last;
  return dateOnly;
}
