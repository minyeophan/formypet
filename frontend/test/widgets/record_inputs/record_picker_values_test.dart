import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/record_inputs/record_inputs.dart';

void main() {
  group('record date picker values', () {
    test('clamps initial dates into range', () {
      final first = DateTime(2020, 1, 1);
      final last = DateTime(2100, 12, 31);

      expect(
        clampRecordDate(DateTime(2019, 12, 31), first, last),
        DateTime(2020, 1, 1),
      );
      expect(
        clampRecordDate(DateTime(2101, 1, 1), first, last),
        DateTime(2100, 12, 31),
      );
      expect(
        clampRecordDate(DateTime(2026, 5, 23), first, last),
        DateTime(2026, 5, 23),
      );
    });

    test('clamps day when year or month changes', () {
      expect(clampRecordDay(year: 2026, month: 2, day: 31), 28);
      expect(clampRecordDay(year: 2024, month: 2, day: 31), 29);
      expect(clampRecordDay(year: 2026, month: 4, day: 31), 30);
    });
  });

  group('record time picker values', () {
    test('converts 24 hour time into period wheel values', () {
      expect(recordTimeWheelValues(const TimeOfDay(hour: 0, minute: 0)), (
        periodIndex: 0,
        hour12: 12,
        minute: 0,
      ));
      expect(recordTimeWheelValues(const TimeOfDay(hour: 11, minute: 59)), (
        periodIndex: 0,
        hour12: 11,
        minute: 59,
      ));
      expect(recordTimeWheelValues(const TimeOfDay(hour: 12, minute: 0)), (
        periodIndex: 1,
        hour12: 12,
        minute: 0,
      ));
      expect(recordTimeWheelValues(const TimeOfDay(hour: 23, minute: 59)), (
        periodIndex: 1,
        hour12: 11,
        minute: 59,
      ));
    });

    test('converts period wheel values into 24 hour time', () {
      expect(
        recordTimeFromWheelValues(periodIndex: 0, hour12: 12, minute: 0),
        const TimeOfDay(hour: 0, minute: 0),
      );
      expect(
        recordTimeFromWheelValues(periodIndex: 0, hour12: 11, minute: 59),
        const TimeOfDay(hour: 11, minute: 59),
      );
      expect(
        recordTimeFromWheelValues(periodIndex: 1, hour12: 12, minute: 0),
        const TimeOfDay(hour: 12, minute: 0),
      );
      expect(
        recordTimeFromWheelValues(periodIndex: 1, hour12: 11, minute: 59),
        const TimeOfDay(hour: 23, minute: 59),
      );
    });
  });

  group('record number picker values', () {
    test('integer mode ignores decimal point', () {
      final next = applyRecordNumberKey(
        '',
        '.',
        mode: RecordNumberInputMode.integer,
      );

      expect(next, '');
    });

    test('decimal mode allows one point and two decimal places', () {
      var value = '';
      for (final key in ['.', '5', '.', '1', '2', '3']) {
        value = applyRecordNumberKey(
          value,
          key,
          mode: RecordNumberInputMode.decimal,
          maxDecimalPlaces: 2,
        );
      }

      expect(value, '0.51');
    });

    test('backspace removes the last character', () {
      expect(
        applyRecordNumberKey(
          '12.3',
          'backspace',
          mode: RecordNumberInputMode.decimal,
        ),
        '12.',
      );
    });

    test('normalizes completed number input', () {
      expect(normalizeRecordNumberInput(''), '');
      expect(normalizeRecordNumberInput('.'), '');
      expect(normalizeRecordNumberInput('0.'), '0');
      expect(normalizeRecordNumberInput('1.'), '1');
      expect(normalizeRecordNumberInput('0.5'), '0.5');
    });
  });
}
