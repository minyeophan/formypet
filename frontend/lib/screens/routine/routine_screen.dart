import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/record_utils.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'routine_calendar_values.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

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
    final now = _dateOnly(DateTime.now());
    _selectedDate = now;
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final routines =
        state.routines
            .where((routine) => routineAppliesOn(routine, _selectedDate))
            .toList()
          ..sort(_routineTimeCompare);
    final accentColor = _accentColorFromHex(
      state.activePet?.accentColor,
      AppColors.primary,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: '케어 캘린더'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppText(
                  '반복 루틴과 중요한 일정을 함께 확인해요',
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
                  careDates: routineDatesForMonth(
                    state.routines,
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
                    onAddRoutine: () => context.push('/routine/new'),
                    onAddSchedule: () => context.push('/routine/schedule/new'),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SelectedDateCareList(
                    selectedDate: _selectedDate,
                    routines: routines,
                    completions: state.routineCompletions,
                    accentColor: accentColor,
                    onToggle: (routineId) => ref
                        .read(petProvider.notifier)
                        .toggleRoutineCompletion(
                          routineId,
                          _isoDate(_selectedDate),
                        ),
                    onDelete: (routineId) =>
                        ref.read(petProvider.notifier).deleteRoutine(routineId),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduleList(accentColor: accentColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
  final VoidCallback onAddRoutine;
  final VoidCallback onAddSchedule;

  const _AddButtons({required this.onAddRoutine, required this.onAddSchedule});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AddButton(
            key: const Key('routine-add-button'),
            icon: Icons.add_rounded,
            label: '루틴 추가',
            onTap: onAddRoutine,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AddButton(
            key: const Key('schedule-add-button'),
            icon: Icons.event_available_rounded,
            label: '일정 추가',
            onTap: onAddSchedule,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 18),
      label: AppText(label, fontSize: 13, fontWeight: FontWeight.bold),
    );
  }
}

class _SelectedDateCareList extends StatelessWidget {
  final DateTime selectedDate;
  final List<Routine> routines;
  final Map<String, CompletionStatus> completions;
  final Color accentColor;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

  const _SelectedDateCareList({
    required this.selectedDate,
    required this.routines,
    required this.completions,
    required this.accentColor,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const _EmptyCareState();
    final selectedIso = _isoDate(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${DateFormat('M월 d일').format(selectedDate)} 케어',
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        ...routines.map((routine) {
          final key = '${routine.id}:$selectedIso';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RoutineItemTile(
              routine: routine,
              status: completions[key] ?? CompletionStatus.pending,
              accentColor: accentColor,
              onToggle: () => onToggle(routine.id),
              onDelete: () => onDelete(routine.id),
            ),
          );
        }),
      ],
    );
  }
}

class _RoutineItemTile extends StatelessWidget {
  final Routine routine;
  final CompletionStatus status;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RoutineItemTile({
    required this.routine,
    required this.status,
    required this.accentColor,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = status == CompletionStatus.completed;
    final note = routine.note?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? AppColors.surfaceSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(recordTypeIcon(routine.typeId), color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _routineTitle(routine),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: completed ? AppColors.textSecondary : AppColors.text,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  AppText(note, fontSize: 12, color: AppColors.textSecondary),
                ],
                const SizedBox(height: 3),
                AppText(
                  '${routine.times.join(', ')}  ${_repeatLabel(routine.repeatType)}',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('routine-complete-${routine.id}'),
            onPressed: onToggle,
            icon: Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: completed ? accentColor : AppColors.muted,
            ),
            tooltip: '완료',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: AppText('삭제')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final Color accentColor;

  const _ScheduleList({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _sampleSchedules
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
  final _SampleSchedule schedule;
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
            child: Icon(schedule.icon, color: accentColor),
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
                    const _SampleBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                AppText(
                  '${schedule.dateText}  ${schedule.place}',
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

class _SampleBadge extends StatelessWidget {
  const _SampleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const AppText(
        '샘플',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
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
            '아직 등록된 케어가 없어요',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          AppText(
            '반복 루틴이나 병원 일정을 추가해 보세요',
            fontSize: 12,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SampleSchedule {
  final String title;
  final String dateText;
  final String place;
  final IconData icon;

  const _SampleSchedule({
    required this.title,
    required this.dateText,
    required this.place,
    required this.icon,
  });
}

enum _RoutineMainTab { calendar, scheduleList }

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

const _sampleSchedules = [
  _SampleSchedule(
    title: '예방접종 예약',
    dateText: '6월 3일 오전 10:00',
    place: '동네동물병원',
    icon: Icons.vaccines_rounded,
  ),
  _SampleSchedule(
    title: '미용 예약',
    dateText: '6월 8일 오후 2:00',
    place: '포근한 미용실',
    icon: Icons.content_cut_rounded,
  ),
];

const _repeatOptions = {
  'daily': '매일',
  'weekly': '매주',
  'biweekly': '2주마다',
  'monthly': '매월',
};

String _routineTitle(Routine routine) {
  final label = routine.label.trim();
  return label.isEmpty ? recordTypeLabel(routine.typeId) : label;
}

int _routineTimeCompare(Routine a, Routine b) {
  final aTime = a.times.isEmpty ? '' : a.times.first;
  final bTime = b.times.isEmpty ? '' : b.times.first;
  return aTime.compareTo(bTime);
}

String _repeatLabel(String repeatType) =>
    _repeatOptions[repeatType] ?? repeatType;

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
