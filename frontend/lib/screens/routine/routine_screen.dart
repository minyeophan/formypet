import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../models/care_schedule.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const RoutineScreen({super.key, this.initialDate});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  _RoutineMainTab _tab = _RoutineMainTab.calendar;

  @override
  void initState() {
    super.initState();
    final initial = _dateOnly(widget.initialDate ?? DateTime.now());
    _selectedDate = initial;
    _visibleMonth = DateTime(initial.year, initial.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final selectedSchedules =
        state.schedules
            .where((schedule) => _scheduleAppliesOn(schedule, _selectedDate))
            .toList()
          ..sort(_scheduleCompare);
    final allSchedules = [...state.schedules]..sort(_scheduleCompare);
    final accentColor = _accentColorFromHex(
      state.activePet?.accentColor,
      AppColors.primary,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '케어 캘린더',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppText(
                  '중요한 케어 일정을 한눈에 확인해요',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MainTabSwitch(
                  selected: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
              const SizedBox(height: 12),
              if (_tab == _RoutineMainTab.calendar) ...[
                _RoutineMonthCalendar(
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  careDates: _scheduleDatesForMonth(
                    state.schedules,
                    _visibleMonth,
                  ),
                  accentColor: accentColor,
                  onPreviousMonth: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  onNextMonth: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                  onSelectDate: (date) => setState(() {
                    _selectedDate = _dateOnly(date);
                    _visibleMonth = DateTime(date.year, date.month);
                  }),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AddButtons(
                    onAddSchedule: () => context.push('/routine/schedule/new'),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SelectedDateCareList(
                    selectedDate: _selectedDate,
                    schedules: selectedSchedules,
                    accentColor: accentColor,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduleList(
                    schedules: allSchedules,
                    accentColor: accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/home');
}

class _MainTabSwitch extends StatelessWidget {
  final _RoutineMainTab selected;
  final ValueChanged<_RoutineMainTab> onChanged;

  const _MainTabSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: '캘린더',
            selected: selected == _RoutineMainTab.calendar,
            onTap: () => onChanged(_RoutineMainTab.calendar),
          ),
          _SegmentButton(
            label: '일정 목록',
            selected: selected == _RoutineMainTab.scheduleList,
            onTap: () => onChanged(_RoutineMainTab.scheduleList),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.text : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RoutineMonthCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Set<String> careDates;
  final Color accentColor;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  const _RoutineMonthCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.careDates,
    required this.accentColor,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final calendarDays = getCalendarDays(visibleMonth.year, visibleMonth.month);
    return Container(
      key: const Key('routine-month-calendar'),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: AppText(
                  DateFormat('yyyy년 M월').format(visibleMonth),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  textAlign: TextAlign.center,
                ),
              ),
              _CalendarNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _WeekdayHeader(),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final date = calendarDays[index];
              final iso = _isoDate(date);
              return _RoutineCalendarDayCell(
                date: date,
                isoDate: iso,
                inMonth: date.month == visibleMonth.month,
                isToday: _sameDate(date, DateTime.now()),
                isSelected: _sameDate(date, selectedDate),
                hasCare: careDates.contains(iso),
                accentColor: accentColor,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.textSecondary,
      tooltip: '월 이동',
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _weekDays
          .map(
            (day) => Expanded(
              child: AppText(
                day,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.muted,
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RoutineCalendarDayCell extends StatelessWidget {
  final DateTime date;
  final String isoDate;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool hasCare;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoutineCalendarDayCell({
    required this.date,
    required this.isoDate,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.hasCare,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? AppColors.white
        : inMonth
        ? AppColors.text
        : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isToday && !isSelected
                  ? Border.all(color: accentColor)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  '${date.day}',
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: textColor,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: hasCare
                      ? Container(
                          key: Key('routine-date-dot-$isoDate'),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.white : accentColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButtons extends StatelessWidget {
  final VoidCallback onAddSchedule;

  const _AddButtons({required this.onAddSchedule});

  @override
  Widget build(BuildContext context) {
    return _AddButton(
      key: const Key('schedule-add-button'),
      label: '일정 등록',
      onTap: onAddSchedule,
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: AppText(label, fontSize: 13, fontWeight: FontWeight.bold),
    );
  }
}

class _SelectedDateCareList extends StatelessWidget {
  final DateTime selectedDate;
  final List<CareSchedule> schedules;
  final Color accentColor;

  const _SelectedDateCareList({
    required this.selectedDate,
    required this.schedules,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) return const _EmptyCareState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${DateFormat('M월 d일').format(selectedDate)} 일정',
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        ...schedules.map(
          (schedule) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ScheduleTile(schedule: schedule, accentColor: accentColor),
          ),
        ),
      ],
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<CareSchedule> schedules;
  final Color accentColor;

  const _ScheduleList({required this.schedules, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) return const _EmptyCareState();
    return Column(
      children: schedules
          .map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScheduleTile(
                schedule: schedule,
                accentColor: accentColor,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final CareSchedule schedule;
  final Color accentColor;

  const _ScheduleTile({required this.schedule, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_scheduleIcon(schedule.categoryId), color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        schedule.title,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AppText(
                  _scheduleSubtitle(schedule),
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCareState extends StatelessWidget {
  const _EmptyCareState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.event_note_rounded, color: AppColors.muted, size: 36),
          SizedBox(height: 10),
          AppText(
            '아직 등록된 일정이 없어요',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          AppText(
            '병원, 미용, 외출 일정을 추가해 보세요',
            fontSize: 12,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _RoutineMainTab { calendar, scheduleList }

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

Set<String> _scheduleDatesForMonth(
  List<CareSchedule> schedules,
  DateTime visibleMonth,
) {
  final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
  final monthEnd = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
  final dates = <String>{};
  for (final schedule in schedules) {
    var current = _dateOnly(DateTime.parse(schedule.startDate));
    final end = _dateOnly(DateTime.parse(schedule.endDate));
    while (!current.isAfter(end)) {
      if (!current.isBefore(monthStart) && !current.isAfter(monthEnd)) {
        dates.add(_isoDate(current));
      }
      current = current.add(const Duration(days: 1));
    }
  }
  return dates;
}

bool _scheduleAppliesOn(CareSchedule schedule, DateTime date) {
  final selected = _dateOnly(date);
  final start = _dateOnly(DateTime.parse(schedule.startDate));
  final end = _dateOnly(DateTime.parse(schedule.endDate));
  return !selected.isBefore(start) && !selected.isAfter(end);
}

int _scheduleCompare(CareSchedule a, CareSchedule b) {
  final dateCompare = a.startDate.compareTo(b.startDate);
  if (dateCompare != 0) return dateCompare;
  return (a.startTime ?? '').compareTo(b.startTime ?? '');
}

IconData _scheduleIcon(String categoryId) => switch (categoryId) {
  'grooming' => Icons.content_cut_rounded,
  'hospital' => Icons.local_hospital_rounded,
  'travel' => Icons.luggage_rounded,
  'hotel' => Icons.home_work_rounded,
  'outing' => Icons.local_cafe_rounded,
  'event' => Icons.celebration_rounded,
  _ => Icons.event_note_rounded,
};

String _scheduleSubtitle(CareSchedule schedule) {
  final date = DateTime.parse(schedule.startDate);
  final dateText = DateFormat('M월 d일').format(date);
  final timeText = schedule.allDay ? '종일' : schedule.startTime;
  final place = schedule.place?.trim();
  return [
    if (timeText != null && timeText.isNotEmpty)
      '$dateText $timeText'
    else
      dateText,
    if (place != null && place.isNotEmpty) place,
  ].join('  ');
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _accentColorFromHex(String? value, Color fallback) {
  if (value == null || value.isEmpty) return fallback;
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
  );
}
