import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/calendar_ranges.dart';
import 'record_input_style.dart';
import 'record_picker_sheet.dart';
import 'record_picker_values.dart';

Future<DateTime?> showRecordDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? calendarFirstDate;
  final last = lastDate ?? recordCalendarLastDate(DateTime.now());
  return showRecordPickerSheet<DateTime>(
    context,
    builder: (context) => _RecordDatePickerSheet(
      initialDate: clampCalendarDate(initialDate, first, last),
      firstDate: first,
      lastDate: last,
    ),
  );
}

Future<TimeOfDay?> showRecordTimePickerSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showRecordPickerSheet<TimeOfDay>(
    context,
    builder: (context) => _RecordTimePickerSheet(initialTime: initialTime),
  );
}

class _RecordDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _RecordDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_RecordDatePickerSheet> createState() => _RecordDatePickerSheetState();
}

class _RecordDatePickerSheetState extends State<_RecordDatePickerSheet> {
  late int _year;
  late int _month;
  late int _day;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  int get _yearCount => widget.lastDate.year - widget.firstDate.year + 1;

  @override
  void initState() {
    super.initState();
    final initial = clampRecordDate(
      widget.initialDate,
      widget.firstDate,
      widget.lastDate,
    );
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _yearController = FixedExtentScrollController(
      initialItem: _year - widget.firstDate.year,
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RecordPickerSheet<DateTime>(
      value: () => clampRecordDate(
        DateTime(_year, _month, _day),
        widget.firstDate,
        widget.lastDate,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RecordInputStyle.sheetHorizontalPadding,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Wheel(
                key: const Key('record-date-year-wheel'),
                controller: _yearController,
                childCount: _yearCount,
                labelBuilder: (index) => '${widget.firstDate.year + index}년',
                onSelectedItemChanged: (index) {
                  setState(() {
                    _year = widget.firstDate.year + index;
                    _clampDay();
                  });
                },
              ),
            ),
            Expanded(
              child: _Wheel(
                key: const Key('record-date-month-wheel'),
                controller: _monthController,
                childCount: 12,
                labelBuilder: (index) => '${index + 1}월',
                onSelectedItemChanged: (index) {
                  setState(() {
                    _month = index + 1;
                    _clampDay();
                  });
                },
              ),
            ),
            Expanded(
              child: _Wheel(
                key: const Key('record-date-day-wheel'),
                controller: _dayController,
                childCount: DateUtils.getDaysInMonth(_year, _month),
                labelBuilder: (index) => '${index + 1}일',
                onSelectedItemChanged: (index) => setState(() {
                  _day = index + 1;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clampDay() {
    final nextDay = clampRecordDay(year: _year, month: _month, day: _day);
    if (nextDay != _day) {
      _day = nextDay;
      _dayController.jumpToItem(_day - 1);
    }
  }
}

class _RecordTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;

  const _RecordTimePickerSheet({required this.initialTime});

  @override
  State<_RecordTimePickerSheet> createState() => _RecordTimePickerSheetState();
}

class _RecordTimePickerSheetState extends State<_RecordTimePickerSheet> {
  late int _periodIndex;
  late int _hour12;
  late int _minute;
  late FixedExtentScrollController _periodController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final initial = recordTimeWheelValues(widget.initialTime);
    _periodIndex = initial.periodIndex;
    _hour12 = initial.hour12;
    _minute = initial.minute;
    _periodController = FixedExtentScrollController(initialItem: _periodIndex);
    _hourController = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _periodController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RecordPickerSheet<TimeOfDay>(
      value: () => recordTimeFromWheelValues(
        periodIndex: _periodIndex,
        hour12: _hour12,
        minute: _minute,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RecordInputStyle.sheetHorizontalPadding,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Wheel(
                key: const Key('record-time-period-wheel'),
                controller: _periodController,
                childCount: 2,
                labelBuilder: (index) => index == 0 ? '오전' : '오후',
                onSelectedItemChanged: (index) =>
                    setState(() => _periodIndex = index),
              ),
            ),
            Expanded(
              child: _Wheel(
                key: const Key('record-time-hour-wheel'),
                controller: _hourController,
                childCount: 12,
                labelBuilder: (index) => '${index + 1}시',
                onSelectedItemChanged: (index) =>
                    setState(() => _hour12 = index + 1),
              ),
            ),
            Expanded(
              child: _Wheel(
                key: const Key('record-time-minute-wheel'),
                controller: _minuteController,
                childCount: 60,
                labelBuilder: (index) => index.toString().padLeft(2, '0'),
                onSelectedItemChanged: (index) =>
                    setState(() => _minute = index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int childCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  const _Wheel({
    super.key,
    required this.controller,
    required this.childCount,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: RecordInputStyle.pickerItemExtent,
      magnification: 1.04,
      squeeze: 1.1,
      useMagnifier: true,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      ),
      onSelectedItemChanged: onSelectedItemChanged,
      childCount: childCount,
      itemBuilder: (context, index) => Center(
        child: Text(
          labelBuilder(index),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
