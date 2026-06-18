import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../models/care_schedule.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';
import '../../widgets/record_inputs/record_date_time_pickers.dart';
import '../../widgets/record_inputs/record_input_style.dart';
import '../../widgets/record_inputs/record_picker_sheet.dart';
import 'routine_schedule_values.dart';

class RoutineScheduleCreateScreen extends ConsumerStatefulWidget {
  final CareSchedule? editingSchedule;

  const RoutineScheduleCreateScreen({super.key, this.editingSchedule});

  @override
  ConsumerState<RoutineScheduleCreateScreen> createState() =>
      _RoutineScheduleCreateScreenState();
}

class _RoutineScheduleCreateScreenState
    extends ConsumerState<RoutineScheduleCreateScreen> {
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _memoController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  _ScheduleCategory? _selectedCategory;
  String _reminder = _reminders.first;
  bool _allDay = false;
  bool _rangeAdjusted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingSchedule;
    if (editing == null) {
      final today = _dateOnly(DateTime.now());
      _startDate = today;
      _endDate = today;
    } else {
      _selectedCategory = _categoryFor(editing.categoryId);
      _titleController.text = editing.title;
      _allDay = editing.allDay;
      _startDate = _parseIsoDate(editing.startDate);
      _endDate = _parseIsoDate(editing.endDate);
      _startTime =
          _parseScheduleTime(editing.startTime) ??
          const TimeOfDay(hour: 0, minute: 0);
      _endTime =
          _parseScheduleTime(editing.endTime) ??
          const TimeOfDay(hour: 23, minute: 59);
      _placeController.text = editing.place ?? '';
      _memoController.text = editing.memo ?? '';
      _reminder = _reminders.contains(editing.reminder)
          ? editing.reminder
          : _reminders.first;
    }
    _titleController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _placeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: widget.editingSchedule == null ? '일정 추가' : '일정 수정',
        showBackButton: true,
        centerTitle: true,
        onBack: _goBack,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              _FormSection(
                label: '카테고리',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _categories.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.3,
                          ),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _CategoryButton(
                          category: category,
                          selected: category == _selectedCategory,
                          onTap: () => setState(() {
                            _selectedCategory = category;
                            _error = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AppText(
                      _selectedCategory?.description ?? '카테고리를 선택하면 설명이 표시돼요',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '일정 제목',
                child: TextField(
                  key: const Key('schedule-title-field'),
                  controller: _titleController,
                  decoration: _inputDecoration('일정 제목을 입력해 주세요'),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '일시',
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            '종일',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Switch(
                          key: const Key('schedule-all-day-switch'),
                          value: _allDay,
                          onChanged: (value) =>
                              _applyRangeChange(allDay: value),
                        ),
                      ],
                    ),
                    _DateTimeRow(
                      label: '시작',
                      date: _startDate,
                      time: _startTime,
                      allDay: _allDay,
                      dateKey: const Key('schedule-start-date-button'),
                      timeKey: const Key('schedule-start-time-button'),
                      onPickDate: () => _pickDate(isStart: true),
                      onPickTime: () => _pickTime(isStart: true),
                    ),
                    const SizedBox(height: 8),
                    _DateTimeRow(
                      label: '종료',
                      date: _endDate,
                      time: _endTime,
                      allDay: _allDay,
                      dateKey: const Key('schedule-end-date-button'),
                      timeKey: const Key('schedule-end-time-button'),
                      onPickDate: () => _pickDate(isStart: false),
                      onPickTime: () => _pickTime(isStart: false),
                    ),
                    if (_rangeAdjusted) ...[
                      const SizedBox(height: 8),
                      const AppText(
                        '종료 일시는 시작 일시보다 빠를 수 없어요. 시작 일시에 맞게 조정했어요.',
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '장소',
                child: Column(
                  children: [
                    TextField(
                      controller: _placeController,
                      decoration: _inputDecoration('장소를 직접 입력하거나 검색하세요'),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showPreparingToast(context),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const AppText(
                          '지도에서 찾기',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '메모',
                child: TextField(
                  controller: _memoController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('메모를 입력해 주세요'),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '알림 시점',
                child: InkWell(
                  key: const Key('schedule-reminder-button'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickReminder,
                  child: _ValueField(value: _reminder),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(
                  _error!,
                  fontSize: 12,
                  color: Colors.redAccent,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('schedule-save-button'),
                  onPressed: _canSave && !_saving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.surfaceSoft,
                    disabledForegroundColor: AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : AppText(
                          '저장',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _canSave ? AppColors.white : AppColors.muted,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSave =>
      _selectedCategory != null && _titleController.text.trim().isNotEmpty;

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final now = DateTime.now();
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: initialDate,
      firstDate: _schedulePickerFirstDate(now, widget.editingSchedule),
      lastDate: _schedulePickerLastDate(now, widget.editingSchedule),
    );
    if (picked == null || !mounted) return;
    _applyRangeChange(
      startDate: isStart ? picked : null,
      endDate: isStart ? null : picked,
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showRecordTimePickerSheet(
      context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null || !mounted) return;
    _applyRangeChange(
      startTime: isStart ? picked : null,
      endTime: isStart ? null : picked,
    );
  }

  Future<void> _pickReminder() async {
    final picked = await showRecordPickerSheet<String>(
      context,
      builder: (context) => _ReminderPickerSheet(initialValue: _reminder),
    );
    if (picked != null && mounted) setState(() => _reminder = picked);
  }

  void _applyRangeChange({
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? allDay,
  }) {
    final nextStartDate = startDate ?? _startDate;
    final nextStartTime = startTime ?? _startTime;
    final range = normalizeScheduleRange(
      startDate: nextStartDate,
      startTime: nextStartTime,
      endDate: endDate ?? _endDate,
      endTime: endTime ?? _endTime,
      allDay: allDay ?? _allDay,
    );
    setState(() {
      _error = null;
      _startDate = _dateOnly(nextStartDate);
      _startTime = nextStartTime;
      _endDate = range.endDate;
      _endTime = range.endTime;
      _allDay = allDay ?? _allDay;
      _rangeAdjusted = range.wasAdjusted;
    });
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = ref.read(petProvider);
      final petId = state.activePetId;
      if (petId == null) throw StateError('Active pet is required');
      final now = DateTime.now();
      final editing = widget.editingSchedule;
      final schedule = CareSchedule(
        id: editing?.id ?? 'local-${now.microsecondsSinceEpoch}',
        petId: editing?.petId ?? petId,
        categoryId: _selectedCategory!.id,
        title: _titleController.text.trim(),
        startDate: _isoDate(_startDate),
        startTime: _allDay ? null : _formatTime(_startTime),
        endDate: _isoDate(_endDate),
        endTime: _allDay ? null : _formatTime(_endTime),
        allDay: _allDay,
        place: _emptyToNull(_placeController.text),
        memo: _emptyToNull(_memoController.text),
        reminder: _reminder,
        createdAt: editing?.createdAt ?? now.toIso8601String(),
      );
      if (editing == null) {
        await ref.read(petProvider.notifier).addCareSchedule(schedule);
      } else {
        await ref.read(petProvider.notifier).updateCareSchedule(schedule);
      }
      if (!mounted) return;
      if (editing == null) {
        context.go('/routine?date=${schedule.startDate}');
      } else {
        context.go('/routine/schedule/${schedule.id}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '저장에 실패했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      final editing = widget.editingSchedule;
      context.go(
        editing == null ? '/routine' : '/routine/schedule/${editing.id}',
      );
    }
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final TimeOfDay time;
  final bool allDay;
  final Key dateKey;
  final Key timeKey;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.allDay,
    required this.dateKey,
    required this.timeKey,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: AppText(
            label,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: _ValueButton(
            key: dateKey,
            value: DateFormat('yyyy.MM.dd').format(date),
            onTap: onPickDate,
          ),
        ),
        if (!allDay) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _ValueButton(
              key: timeKey,
              value: _formatTime(time),
              onTap: onPickTime,
            ),
          ),
        ],
      ],
    );
  }
}

class _ValueButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _ValueButton({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _ValueField(value: value),
    );
  }
}

class _ValueField extends StatelessWidget {
  final String value;

  const _ValueField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AppText(value, fontSize: 13, color: AppColors.text),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final _ScheduleCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.14)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? category.color : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(category.icon, size: 18, color: category.color),
            const SizedBox(width: 7),
            Expanded(
              child: AppText(
                category.label,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
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

class _ReminderPickerSheet extends StatefulWidget {
  final String initialValue;

  const _ReminderPickerSheet({required this.initialValue});

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late int _index;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _index = _reminders.indexOf(widget.initialValue);
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RecordPickerSheet<String>(
      value: () => _reminders[_index],
      child: SizedBox(
        height: 220,
        child: CupertinoPicker.builder(
          key: const Key('schedule-reminder-wheel'),
          scrollController: _controller,
          itemExtent: RecordInputStyle.pickerItemExtent,
          onSelectedItemChanged: (index) => setState(() => _index = index),
          childCount: _reminders.length,
          itemBuilder: (context, index) => Center(
            child: AppText(
              _reminders[index],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCategory {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _ScheduleCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const _categories = [
  _ScheduleCategory(
    id: 'grooming',
    label: '미용',
    description: '목욕, 미용, 발톱 관리 일정을 기록해요.',
    icon: Icons.content_cut_rounded,
    color: Color(0xFFD4779B),
  ),
  _ScheduleCategory(
    id: 'hospital',
    label: '병원 예약',
    description: '진료와 예방접종 예약을 잊지 않게 챙겨요.',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFF5B8DEF),
  ),
  _ScheduleCategory(
    id: 'travel',
    label: '여행숙박',
    description: '함께 떠나는 여행과 숙박 일정을 기록해요.',
    icon: Icons.luggage_rounded,
    color: Color(0xFF8D7A64),
  ),
  _ScheduleCategory(
    id: 'hotel',
    label: '호텔링',
    description: '돌봄과 호텔링 일정을 미리 확인해요.',
    icon: Icons.home_work_rounded,
    color: Color(0xFF5E9F7B),
  ),
  _ScheduleCategory(
    id: 'outing',
    label: '카페외출',
    description: '카페와 외출 약속을 기록해요.',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFE29B45),
  ),
  _ScheduleCategory(
    id: 'event',
    label: '행사이벤트',
    description: '행사와 이벤트 일정을 모아봐요.',
    icon: Icons.celebration_rounded,
    color: Color(0xFF8D6CCF),
  ),
  _ScheduleCategory(
    id: 'etc',
    label: '기타',
    description: '그 밖의 중요한 일정을 기록해요.',
    icon: Icons.event_note_rounded,
    color: Color(0xFF7A8491),
  ),
];

const _reminders = ['하루 전', '2시간 전', '1시간 전', '30분 전', '알림 없음'];

_ScheduleCategory _categoryFor(String categoryId) => _categories.firstWhere(
  (category) => category.id == categoryId,
  orElse: () => _categories.last,
);

DateTime _schedulePickerFirstDate(DateTime now, CareSchedule? editingSchedule) {
  final base = scheduleFirstDate(now);
  if (editingSchedule == null) return base;
  return [
    base,
    _parseIsoDate(editingSchedule.startDate),
    _parseIsoDate(editingSchedule.endDate),
  ].reduce((a, b) => a.isBefore(b) ? a : b);
}

DateTime _schedulePickerLastDate(DateTime now, CareSchedule? editingSchedule) {
  final base = scheduleLastDate(now);
  if (editingSchedule == null) return base;
  return [
    base,
    _parseIsoDate(editingSchedule.startDate),
    _parseIsoDate(editingSchedule.endDate),
  ].reduce((a, b) => a.isAfter(b) ? a : b);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _parseIsoDate(String value) {
  final parsed = DateTime.parse(value);
  return _dateOnly(parsed);
}

TimeOfDay? _parseScheduleTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

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
