import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/keyboard_utils.dart';
import '../../core/record_utils.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_text.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  _RoutineMainTab _tab = _RoutineMainTab.calendar;
  _RoutineCalendarMode _mode = _RoutineCalendarMode.month;

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
            .where((routine) => _routineAppliesOn(routine, _selectedDate))
            .toList()
          ..sort(_routineTimeCompare);
    final allRoutineDates = _routineDatesForMonth(
      state.routines,
      _visibleMonth,
    );
    final hasCare = state.routines.isNotEmpty;
    final accentColor = _accentColorFromHex(
      state.activePet?.accentColor,
      AppColors.primary,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            children: [
              _RoutineHeader(
                onAddRoutine: () => context.push('/routine/new'),
                onAddSchedule: () => context.push('/routine/schedule/new'),
              ),
              const SizedBox(height: 14),
              _MainTabSwitch(
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 12),
              if (_tab == _RoutineMainTab.calendar) ...[
                _CalendarModeSwitch(
                  selected: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: 12),
                if (_mode == _RoutineCalendarMode.month)
                  _RoutineMonthCalendar(
                    visibleMonth: _visibleMonth,
                    selectedDate: _selectedDate,
                    careDates: allRoutineDates,
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
                  )
                else
                  _RoutineWeekCalendar(
                    selectedDate: _selectedDate,
                    careDates: allRoutineDates,
                    accentColor: accentColor,
                    onSelectDate: (date) => setState(() {
                      _selectedDate = _dateOnly(date);
                      _visibleMonth = DateTime(date.year, date.month);
                    }),
                  ),
                const SizedBox(height: 14),
                _SelectedDateCareList(
                  selectedDate: _selectedDate,
                  routines: routines,
                  completions: state.routineCompletions,
                  accentColor: accentColor,
                  showSampleSchedules: hasCare,
                  onToggle: (routineId) => ref
                      .read(petProvider.notifier)
                      .toggleRoutineCompletion(
                        routineId,
                        _isoDate(_selectedDate),
                      ),
                  onDelete: (routineId) =>
                      ref.read(petProvider.notifier).deleteRoutine(routineId),
                ),
              ] else
                _ScheduleList(hasCare: hasCare, accentColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineCreateScreen extends ConsumerStatefulWidget {
  const RoutineCreateScreen({super.key});

  @override
  ConsumerState<RoutineCreateScreen> createState() =>
      _RoutineCreateScreenState();
}

class _RoutineCreateScreenState extends ConsumerState<RoutineCreateScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _timeController = TextEditingController(text: '08:00');
  _RoutineTypeOption? _selectedType;
  String _repeatType = 'daily';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppText('루틴 추가', fontWeight: FontWeight.bold),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: _selectedType == null
              ? _RoutineTypeStep(onSelect: _selectType)
              : _RoutineDetailStep(
                  selectedType: _selectedType!,
                  nameController: _nameController,
                  noteController: _noteController,
                  timeController: _timeController,
                  repeatType: _repeatType,
                  saving: _saving,
                  onRepeatChanged: (value) => setState(() {
                    _repeatType = value;
                  }),
                  onBackToTypes: () => setState(() {
                    _selectedType = null;
                  }),
                  onSave: _saveRoutine,
                ),
        ),
      ),
    );
  }

  void _selectType(_RoutineTypeOption option) {
    setState(() {
      _selectedType = option;
      if (_nameController.text.isEmpty) {
        _nameController.text = option.label;
      }
    });
  }

  Future<void> _saveRoutine() async {
    final selectedType = _selectedType;
    if (selectedType == null || _saving) return;

    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    setState(() => _saving = true);
    final label = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : selectedType.label;
    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : label;

    await ref.read(petProvider.notifier).addRoutine({
      'label': label,
      'typeId': selectedType.typeId,
      'repeatType': _repeatType,
      'times': [_timeController.text.trim()],
      'days': <int>[],
      'startDate': todayString(),
      'note': note,
    });

    if (mounted) {
      context.go('/routine');
    }
  }
}

class RoutineScheduleCreateScreen extends StatefulWidget {
  const RoutineScheduleCreateScreen({super.key});

  @override
  State<RoutineScheduleCreateScreen> createState() =>
      _RoutineScheduleCreateScreenState();
}

class _RoutineScheduleCreateScreenState
    extends State<RoutineScheduleCreateScreen> {
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _companionController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _companionController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppText('일정 추가', fontWeight: FontWeight.bold),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              const _ScheduleCategoryPicker(),
              const SizedBox(height: 12),
              _FormSection(
                label: '제목',
                child: TextField(
                  controller: _titleController,
                  decoration: _inputDecoration('일정 이름'),
                ),
              ),
              const SizedBox(height: 12),
              const _DateTimePreviewSection(),
              const SizedBox(height: 12),
              _FormSection(
                label: '장소',
                child: TextField(
                  controller: _placeController,
                  decoration: _inputDecoration('병원, 미용실 등'),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '동반자',
                child: TextField(
                  controller: _companionController,
                  decoration: _inputDecoration('함께 가는 사람'),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '메모',
                child: TextField(
                  controller: _memoController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('준비물이나 요청사항'),
                ),
              ),
              const SizedBox(height: 12),
              const _ReminderSection(),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: AppText('준비중')));
                  },
                  child: const AppText(
                    '저장',
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineHeader extends StatelessWidget {
  final VoidCallback onAddRoutine;
  final VoidCallback onAddSchedule;

  const _RoutineHeader({
    required this.onAddRoutine,
    required this.onAddSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                '케어 캘린더',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              SizedBox(height: 4),
              AppText(
                '반복 루틴과 중요한 일정을 함께 확인해요',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _SmallActionButton(
          icon: Icons.add_rounded,
          label: '루틴 추가',
          onTap: onAddRoutine,
        ),
        const SizedBox(width: 6),
        _SmallActionButton(
          icon: Icons.event_available_rounded,
          label: '일정 추가',
          onTap: onAddSchedule,
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.text),
            const SizedBox(width: 4),
            AppText(label, fontSize: 12, fontWeight: FontWeight.bold),
          ],
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
    return _SegmentedSurface(
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
    );
  }
}

class _CalendarModeSwitch extends StatelessWidget {
  final _RoutineCalendarMode selected;
  final ValueChanged<_RoutineCalendarMode> onChanged;

  const _CalendarModeSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SegmentedSurface(
      compact: true,
      children: [
        _SegmentButton(
          label: '월간',
          selected: selected == _RoutineCalendarMode.month,
          onTap: () => onChanged(_RoutineCalendarMode.month),
        ),
        _SegmentButton(
          label: '주간',
          selected: selected == _RoutineCalendarMode.week,
          onTap: () => onChanged(_RoutineCalendarMode.week),
        ),
      ],
    );
  }
}

class _SegmentedSurface extends StatelessWidget {
  final List<Widget> children;
  final bool compact;

  const _SegmentedSurface({required this.children, this.compact = false});

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
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: children,
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

class _RoutineWeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Set<String> careDates;
  final Color accentColor;
  final ValueChanged<DateTime> onSelectDate;

  const _RoutineWeekCalendar({
    required this.selectedDate,
    required this.careDates,
    required this.accentColor,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );
    final weekDays = List.generate(
      7,
      (index) => _dateOnly(start.add(Duration(days: index))),
    );

    return Container(
      key: const Key('routine-week-calendar'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          AppText(
            '${DateFormat('M월 d일').format(weekDays.first)} - ${DateFormat('M월 d일').format(weekDays.last)}',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 12),
          const _WeekdayHeader(),
          const SizedBox(height: 6),
          Row(
            children: weekDays
                .map(
                  (date) => Expanded(
                    child: _RoutineCalendarDayCell(
                      date: date,
                      isoDate: _isoDate(date),
                      inMonth: true,
                      isToday: _sameDate(date, DateTime.now()),
                      isSelected: _sameDate(date, selectedDate),
                      hasCare: careDates.contains(_isoDate(date)),
                      accentColor: accentColor,
                      onTap: () => onSelectDate(date),
                    ),
                  ),
                )
                .toList(),
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

class _SelectedDateCareList extends StatelessWidget {
  final DateTime selectedDate;
  final List<Routine> routines;
  final Map<String, CompletionStatus> completions;
  final Color accentColor;
  final bool showSampleSchedules;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

  const _SelectedDateCareList({
    required this.selectedDate,
    required this.routines,
    required this.completions,
    required this.accentColor,
    required this.showSampleSchedules,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIso = _isoDate(selectedDate);
    if (routines.isEmpty && !showSampleSchedules) {
      return const _EmptyCareState();
    }

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
        if (routines.isEmpty)
          const _SoftInfoPanel(text: '선택한 날짜에 표시할 루틴이 없어요')
        else
          ...routines.map((routine) {
            final key = '${routine.id}:$selectedIso';
            final status = completions[key] ?? CompletionStatus.pending;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoutineItemTile(
                routine: routine,
                status: status,
                accentColor: accentColor,
                onToggle: () => onToggle(routine.id),
                onDelete: () => onDelete(routine.id),
              ),
            );
          }),
        if (showSampleSchedules) ...[
          const SizedBox(height: 8),
          const AppText(
            '일정',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 10),
          ..._sampleSchedules.map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScheduleTile(
                schedule: schedule,
                accentColor: accentColor,
              ),
            ),
          ),
        ],
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
    final label = routine.note?.trim().isNotEmpty == true
        ? routine.note!.trim()
        : recordTypeLabel(routine.typeId);

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
                  label,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: completed ? AppColors.textSecondary : AppColors.text,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  children: [
                    AppText(
                      routine.times.join(', '),
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    AppText(
                      _repeatLabel(routine.repeatType),
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
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
              if (value == 'delete') {
                onDelete();
              }
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
  final bool hasCare;
  final Color accentColor;

  const _ScheduleList({required this.hasCare, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (!hasCare) {
      return const _EmptyCareState();
    }

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
                AppText(
                  schedule.title,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
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

class _EmptyCareState extends StatelessWidget {
  const _EmptyCareState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
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

class _SoftInfoPanel extends StatelessWidget {
  final String text;

  const _SoftInfoPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AppText(text, fontSize: 13, color: AppColors.textSecondary),
    );
  }
}

class _RoutineTypeStep extends StatelessWidget {
  final ValueChanged<_RoutineTypeOption> onSelect;

  const _RoutineTypeStep({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          '루틴 유형 선택',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 6),
        const AppText(
          '자주 반복되는 케어 종류를 먼저 골라 주세요',
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 16),
        ..._routineTypeOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoutineTypeCard(
              option: option,
              onTap: () => onSelect(option),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineTypeCard extends StatelessWidget {
  final _RoutineTypeOption option;
  final VoidCallback onTap;

  const _RoutineTypeCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(option.icon, color: option.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AppText(
                option.label,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _RoutineDetailStep extends StatelessWidget {
  final _RoutineTypeOption selectedType;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final TextEditingController timeController;
  final String repeatType;
  final bool saving;
  final ValueChanged<String> onRepeatChanged;
  final VoidCallback onBackToTypes;
  final VoidCallback onSave;

  const _RoutineDetailStep({
    required this.selectedType,
    required this.nameController,
    required this.noteController,
    required this.timeController,
    required this.repeatType,
    required this.saving,
    required this.onRepeatChanged,
    required this.onBackToTypes,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBackToTypes,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const AppText('유형 다시 선택'),
        ),
        const SizedBox(height: 6),
        const AppText(
          '루틴 정보',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 14),
        _FormSection(
          label: '루틴 이름',
          child: TextField(
            key: const Key('routine-name-field'),
            controller: nameController,
            decoration: _inputDecoration(selectedType.label),
          ),
        ),
        const SizedBox(height: 12),
        _FormSection(
          label: '메모',
          child: TextField(
            key: const Key('routine-note-field'),
            controller: noteController,
            decoration: _inputDecoration('복용량, 사료명 등'),
          ),
        ),
        const SizedBox(height: 12),
        _FormSection(
          label: '시간',
          child: TextField(
            key: const Key('routine-time-field'),
            controller: timeController,
            decoration: _inputDecoration('08:00'),
          ),
        ),
        const SizedBox(height: 12),
        _FormSection(
          label: '반복',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _repeatOptions.entries
                .map(
                  (entry) => ChoiceChip(
                    label: AppText(entry.value),
                    selected: repeatType == entry.key,
                    selectedColor: AppColors.primary.withValues(alpha: 0.22),
                    onSelected: (_) => onRepeatChanged(entry.key),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: saving ? null : onSave,
            child: AppText(
              saving ? '저장 중' : '저장',
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ScheduleCategoryPicker extends StatelessWidget {
  const _ScheduleCategoryPicker();

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      label: '카테고리',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _StaticChip(label: '병원', selected: true),
          _StaticChip(label: '미용'),
          _StaticChip(label: '돌봄'),
          _StaticChip(label: '기타'),
        ],
      ),
    );
  }
}

class _DateTimePreviewSection extends StatelessWidget {
  const _DateTimePreviewSection();

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      label: '일시',
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18),
          const SizedBox(width: 8),
          AppText(
            '${formatDate(DateTime.now())}  오전 10:00',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection();

  @override
  Widget build(BuildContext context) {
    return const _FormSection(
      label: '알림 시점',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StaticChip(label: '없음'),
          _StaticChip(label: '1시간 전', selected: true),
          _StaticChip(label: '하루 전'),
        ],
      ),
    );
  }
}

class _StaticChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _StaticChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: AppText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: selected ? AppColors.text : AppColors.textSecondary,
      ),
    );
  }
}

class _RoutineTypeOption {
  final String label;
  final String typeId;
  final IconData icon;
  final Color color;

  const _RoutineTypeOption({
    required this.label,
    required this.typeId,
    required this.icon,
    required this.color,
  });
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

enum _RoutineCalendarMode { month, week }

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

const _routineTypeOptions = [
  _RoutineTypeOption(
    label: '투약',
    typeId: 'medicine',
    icon: Icons.medication_rounded,
    color: Color(0xFF5E9F7B),
  ),
  _RoutineTypeOption(
    label: '급식',
    typeId: 'meal',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFE29B45),
  ),
  _RoutineTypeOption(
    label: '건강체크',
    typeId: 'checkup',
    icon: Icons.health_and_safety_rounded,
    color: Color(0xFF5B8DEF),
  ),
  _RoutineTypeOption(
    label: '특별케어',
    typeId: 'vet',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFD4667A),
  ),
  _RoutineTypeOption(
    label: '커스텀',
    typeId: 'play',
    icon: Icons.tune_rounded,
    color: Color(0xFF8D7A64),
  ),
];

const _repeatOptions = {
  'daily': '매일',
  'weekly': '매주',
  'biweekly': '2주마다',
  'monthly': '매월',
};

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

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
  );
}

Set<String> _routineDatesForMonth(List<Routine> routines, DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0);
  final dates = <String>{};
  for (
    var day = DateTime(month.year, month.month, 1);
    !day.isAfter(last);
    day = day.add(const Duration(days: 1))
  ) {
    if (routines.any((routine) => _routineAppliesOn(routine, day))) {
      dates.add(_isoDate(day));
    }
  }
  return dates;
}

bool _routineAppliesOn(Routine routine, DateTime date) {
  if (!routine.active) return false;
  final target = _dateOnly(date);
  final start = _tryParseDate(routine.startDate);
  if (start != null && target.isBefore(start)) return false;
  final endDate = routine.endDate;
  final end = endDate == null ? null : _tryParseDate(endDate);
  if (end != null && target.isAfter(end)) return false;
  return switch (routine.repeatType) {
    'daily' => true,
    'weekly' || 'biweekly' || 'monthly' => true,
    _ => true,
  };
}

int _routineTimeCompare(Routine a, Routine b) {
  final aTime = a.times.isEmpty ? '' : a.times.first;
  final bTime = b.times.isEmpty ? '' : b.times.first;
  return aTime.compareTo(bTime);
}

String _repeatLabel(String repeatType) {
  return _repeatOptions[repeatType] ?? repeatType;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime? _tryParseDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? null : _dateOnly(parsed);
}

String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _accentColorFromHex(String? value, Color fallback) {
  if (value == null || value.isEmpty) return fallback;
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
