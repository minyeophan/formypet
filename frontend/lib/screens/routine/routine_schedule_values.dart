import 'package:flutter/material.dart';

class ScheduleRange {
  final DateTime endDate;
  final TimeOfDay endTime;
  final bool wasAdjusted;

  const ScheduleRange({
    required this.endDate,
    required this.endTime,
    required this.wasAdjusted,
  });
}

DateTime scheduleFirstDate(DateTime now) => DateTime(now.year);

DateTime scheduleLastDate(DateTime now) => DateTime(now.year + 1, 12, 31);

ScheduleRange normalizeScheduleRange({
  required DateTime startDate,
  required TimeOfDay startTime,
  required DateTime endDate,
  required TimeOfDay endTime,
  required bool allDay,
}) {
  final normalizedStartDate = _dateOnly(startDate);
  final normalizedEndDate = _dateOnly(endDate);
  if (allDay) {
    if (normalizedEndDate.isBefore(normalizedStartDate)) {
      return ScheduleRange(
        endDate: normalizedStartDate,
        endTime: endTime,
        wasAdjusted: true,
      );
    }
    return ScheduleRange(
      endDate: normalizedEndDate,
      endTime: endTime,
      wasAdjusted: false,
    );
  }

  final start = _combine(normalizedStartDate, startTime);
  final end = _combine(normalizedEndDate, endTime);
  if (end.isBefore(start)) {
    return ScheduleRange(
      endDate: normalizedStartDate,
      endTime: startTime,
      wasAdjusted: true,
    );
  }
  return ScheduleRange(
    endDate: normalizedEndDate,
    endTime: endTime,
    wasAdjusted: false,
  );
}

DateTime _combine(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
