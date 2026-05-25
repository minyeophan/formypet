import 'dart:math' as math;

import 'package:flutter/material.dart';

enum RecordNumberInputMode { integer, decimal }

DateTime clampRecordDate(
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

int clampRecordDay({required int year, required int month, required int day}) {
  return math.min(day, DateUtils.getDaysInMonth(year, month));
}

({int periodIndex, int hour12, int minute}) recordTimeWheelValues(
  TimeOfDay time,
) {
  final periodIndex = time.hour < 12 ? 0 : 1;
  final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return (periodIndex: periodIndex, hour12: hour12, minute: time.minute);
}

TimeOfDay recordTimeFromWheelValues({
  required int periodIndex,
  required int hour12,
  required int minute,
}) {
  final hour = switch ((periodIndex, hour12)) {
    (0, 12) => 0,
    (1, 12) => 12,
    (0, _) => hour12,
    _ => hour12 + 12,
  };
  return TimeOfDay(hour: hour, minute: minute);
}

String applyRecordNumberKey(
  String current,
  String key, {
  required RecordNumberInputMode mode,
  int maxDecimalPlaces = 2,
}) {
  if (key == 'backspace') {
    if (current.isEmpty) return current;
    return current.substring(0, current.length - 1);
  }
  if (key == '.') {
    if (mode == RecordNumberInputMode.integer || current.contains('.')) {
      return current;
    }
    return current.isEmpty ? '0.' : '$current.';
  }
  if (!RegExp(r'^\d$').hasMatch(key)) return current;
  if (mode == RecordNumberInputMode.decimal && current.contains('.')) {
    final decimalLength = current.length - current.indexOf('.') - 1;
    if (decimalLength >= maxDecimalPlaces) return current;
  }
  return '$current$key';
}

String normalizeRecordNumberInput(String value) {
  if (value.isEmpty || value == '.') return '';
  if (value.endsWith('.')) return value.substring(0, value.length - 1);
  return value;
}
