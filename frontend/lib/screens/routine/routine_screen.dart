import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/record_utils.dart';
import '../../models/care_schedule.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import 'routine_schedule_values.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialTab;

  const RoutineScreen({super.key, this.initialDate, this.initialTab});

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
    _tab = switch (widget.initialTab) {
      'schedules' => _RoutineMainTab.scheduleList,
      'routines' => _RoutineMainTab.routines,
      _ => _RoutineMainTab.calendar,
    };
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
    final routineAccentColor = _accentColorFromHex(
      state.activePet?.accentColor,
      AppColors.primary,
    );
    final calendarAccentColor = AppColors.primary;

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _RoutineMonthCalendar(
                    visibleMonth: _visibleMonth,
                    selectedDate: _selectedDate,
                    careDates: _scheduleDatesForMonth(
                      state.schedules,
                      _visibleMonth,
                    ),
                    accentColor: calendarAccentColor,
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
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AddButtons(
                    onAddSchedule: () => context.push('/routine/schedule/new'),
                    onAddRoutine: () => context.push('/routine/new'),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SelectedDateCareList(
                    selectedDate: _selectedDate,
                    schedules: selectedSchedules,
                    accentColor: routineAccentColor,
                  ),
                ),
              ] else if (_tab == _RoutineMainTab.scheduleList)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduleList(
                    schedules: allSchedules,
                    accentColor: routineAccentColor,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _RoutineList(routines: state.routines),
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
          _SegmentButton(
            label: '루틴',
            selected: selected == _RoutineMainTab.routines,
            onTap: () => onChanged(_RoutineMainTab.routines),
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
  final VoidCallback onAddRoutine;

  const _AddButtons({required this.onAddSchedule, required this.onAddRoutine});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AddButton(
            key: const Key('schedule-add-button'),
            label: '일정 등록',
            onTap: onAddSchedule,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AddButton(
            key: const Key('routine-add-button'),
            label: '루틴 등록',
            onTap: onAddRoutine,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.white,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: AppText(
        label,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      ),
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

class _RoutineList extends StatelessWidget {
  final List<Routine> routines;

  const _RoutineList({required this.routines});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const _EmptyRoutineState();
    final today = _dateOnly(DateTime.now());
    final active = routines
        .where((routine) => !_routineEnded(routine, today))
        .toList();
    final ended = routines
        .where((routine) => _routineEnded(routine, today))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isNotEmpty) ...[
          ...active.map((routine) => _RoutineTile(routine: routine)),
        ],
        if (ended.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: 18),
          const AppText(
            '지난 루틴',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          ...ended.map(
            (routine) => _RoutineTile(routine: routine, ended: true),
          ),
        ],
      ],
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final Routine routine;
  final bool ended;

  const _RoutineTile({required this.routine, this.ended = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: Key('routine-item-${routine.id}'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push('/routine/${routine.id}'),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AppVisual(
                    id: recordTypeVisualId(routine.typeId),
                    size: 24,
                    color: ended ? AppColors.muted : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        routine.label,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      const SizedBox(height: 3),
                      AppText(
                        _routineSubtitle(routine),
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRoutineState extends StatelessWidget {
  const _EmptyRoutineState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.repeat_rounded, color: AppColors.muted, size: 36),
          SizedBox(height: 10),
          AppText(
            '아직 등록된 루틴이 없어요',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final CareSchedule schedule;
  final Color accentColor;

  const _ScheduleTile({required this.schedule, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: Key('schedule-detail-button-${schedule.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/routine/schedule/${schedule.id}'),
        child: Ink(
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
                child: AppVisual(
                  id: scheduleVisualId(schedule.categoryId),
                  size: 24,
                  color: accentColor,
                ),
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
              const SizedBox(width: 10),
              const _ScheduleDetailButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleDetailButton extends StatelessWidget {
  const _ScheduleDetailButton();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.muted,
      size: 22,
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

enum _RoutineMainTab { calendar, scheduleList, routines }

bool _routineEnded(Routine routine, DateTime today) {
  final value = routine.endDate;
  return value != null && _dateOnly(DateTime.parse(value)).isBefore(today);
}

String _routineSubtitle(Routine routine) {
  final repeat = switch (routine.repeatType) {
    'weekly' => '매주',
    'biweekly' => '격주',
    'monthly' => '매월',
    _ => '매일',
  };
  final time = routine.times.isEmpty ? '시간 없음' : routine.times.first;
  final period = routine.endDate == null
      ? '계속 반복'
      : '${_shortDate(routine.startDate)}~${_shortDate(routine.endDate!)}';
  return '$repeat · $time · $period';
}

String _shortDate(String value) {
  final date = DateTime.parse(value);
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';
}

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

String _scheduleSubtitle(CareSchedule schedule) {
  final startTime = schedule.startTime?.trim();
  final endTime = schedule.endTime?.trim();
  final timeText = schedule.allDay
      ? '종일'
      : switch ((startTime?.isNotEmpty == true, endTime?.isNotEmpty == true)) {
          (true, true) => startTime == endTime
              ? startTime!
              : '$startTime~$endTime',
          (true, false) => startTime!,
          (false, true) => endTime!,
          _ => '',
        };
  final place = schedule.place?.trim();
  return [
    if (timeText.isNotEmpty) timeText,
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
