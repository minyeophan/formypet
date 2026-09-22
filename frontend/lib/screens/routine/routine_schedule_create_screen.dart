import 'dart:convert';

import '../../core/app_interaction_style.dart';
import '../../widgets/app_ink_well.dart';
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
import '../../widgets/app_visual.dart';
import '../../widgets/draft_exit_guard.dart';
import '../../widgets/record_inputs/record_inputs.dart';
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
    extends ConsumerState<RoutineScheduleCreateScreen>
    with DraftExitGuardMixin<RoutineScheduleCreateScreen> {
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _memoController = TextEditingController();
  late DateTime _startDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  _ScheduleCategory? _selectedCategory;
  String _reminder = _reminders.first;
  bool _saving = false;
  bool _deleting = false;
  bool _confirmingDelete = false;
  bool _categoryChanged = false;
  bool _timeChanged = false;
  late (int, int, String?) _draftOwner;
  late String _initialDraft;
  String? _error;

  String get _draft => jsonEncode([
    _titleController.text,
    _placeController.text,
    _memoController.text,
    _isoDate(_startDate),
    _formatTime(_startTime),
    _selectedCategory?.id,
    _reminder,
  ]);

  @override
  bool get hasUnsavedChanges => _ownerCurrent && _draft != _initialDraft;
  @override
  bool get isDraftBusy => _saving || _deleting;
  bool get _ownerCurrent =>
      ref.read(petProvider.notifier).isRoutineContextCurrent(_draftOwner);

  @override
  void initState() {
    super.initState();
    _draftOwner = ref.read(petProvider.notifier).routineContext;
    final editing = widget.editingSchedule;
    if (editing == null) {
      final today = _dateOnly(DateTime.now());
      _startDate = today;
    } else {
      _selectedCategory = _categoryFor(editing.categoryId);
      _titleController.text = editing.title;
      _startDate = _parseIsoDate(editing.startDate);
      _startTime = editing.allDay
          ? const TimeOfDay(hour: 0, minute: 0)
          : _parseScheduleTime(editing.startTime) ??
                const TimeOfDay(hour: 0, minute: 0);
      _placeController.text = editing.place ?? '';
      _memoController.text = editing.memo ?? '';
      _reminder = editing.reminder;
    }
    _initialDraft = _draft;
    _titleController.addListener(_refresh);
    _placeController.addListener(_refresh);
    _memoController.addListener(_refresh);
    ref.listenManual(petProvider, (_, _) {
      if (mounted && !_ownerCurrent) {
        setState(() {
          _saving = false;
          _deleting = false;
          _error = '계정 또는 반려동물이 변경됐어요. 목록으로 돌아가 다시 열어 주세요.';
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _placeController
      ..removeListener(_refresh)
      ..dispose();
    _memoController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return protectDraft(
      onExit: _goBack,
      child: Scaffold(
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale =
                              MediaQuery.textScalerOf(context).scale(12) / 12;
                          final columns =
                              constraints.maxWidth / 2 >= 120 * scale ? 2 : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _categories.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: 32 + 20 * scale,
                                ),
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              return _CategoryButton(
                                category: category,
                                selected: category == _selectedCategory,
                                onTap: () => setState(() {
                                  _categoryChanged = true;
                                  _selectedCategory = category;
                                  _error = null;
                                }),
                              );
                            },
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
                    enabled: !isDraftBusy && _ownerCurrent,
                    decoration: _inputDecoration('일정 제목을 입력해 주세요'),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _DateTimeRow(
                        date: _startDate,
                        time: _startTime,
                        dateKey: const Key('schedule-start-date-button'),
                        timeKey: const Key('schedule-start-time-button'),
                        onPickDate: _pickDate,
                        onPickTime: _pickTime,
                        allDay: widget.editingSchedule?.allDay ?? false,
                      ),
                      if (widget.editingSchedule != null) ...[
                        const SizedBox(height: 8),
                        AppText(
                          '종료: ${_preservedEnd(widget.editingSchedule).$1}'
                          '${widget.editingSchedule!.allDay ? " (종일)" : " ${_preservedEnd(widget.editingSchedule).$2 ?? ""}"}\n'
                          '시작 일시를 바꾸면 기존 기간을 유지해요.',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: '장소',
                  child: TextField(
                    controller: _placeController,
                    enabled: !isDraftBusy && _ownerCurrent,
                    decoration: _inputDecoration('장소를 직접 입력해 주세요'),
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: '메모',
                  child: TextField(
                    controller: _memoController,
                    enabled: !isDraftBusy && _ownerCurrent,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _inputDecoration('메모를 입력해 주세요'),
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: '알림 시점',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: AppInkWell(
                      key: const Key('schedule-reminder-button'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickReminder,
                      child: _ValueField(value: _reminder),
                    ),
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
                if (!_canSave) ...[
                  const AppText(
                    '카테고리와 일정 제목을 입력하면 저장할 수 있어요.',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.editingSchedule == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('schedule-save-button'),
                      onPressed: _canSave && !_saving && !_deleting
                          ? _save
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: _saving
                            ? AppColors.primary
                            : AppColors.surfaceSoft,
                        disabledForegroundColor: _saving
                            ? AppColors.white
                            : AppColors.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : AppText(
                              '저장',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _canSave
                                  ? AppColors.white
                                  : AppColors.muted,
                            ),
                    ),
                  )
                else
                  RecordEditActionBar(
                    enabled: _canSave,
                    isSaving: _saving,
                    isDeleting: _deleting,
                    onSave: _save,
                    onDelete: _delete,
                    saveKey: const Key('schedule-save-button'),
                    deleteKey: const Key('schedule-delete-button'),
                    saveLabel: '저장',
                    savingLabel: '저장 중...',
                    deleteLabel: '일정 삭제',
                    deletingLabel: '삭제 중...',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSave =>
      _ownerCurrent &&
      _selectedCategory != null &&
      _titleController.text.trim().isNotEmpty;

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    if (isDraftBusy || !_ownerCurrent) return;
    final now = DateTime.now();
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: _startDate,
      firstDate: _schedulePickerFirstDate(now, widget.editingSchedule),
      lastDate: _schedulePickerLastDate(now, widget.editingSchedule),
    );
    if (picked == null || !mounted || isDraftBusy || !_ownerCurrent) return;
    setState(() {
      _error = null;
      _startDate = _dateOnly(picked);
    });
  }

  Future<void> _pickTime() async {
    if (isDraftBusy ||
        !_ownerCurrent ||
        widget.editingSchedule?.allDay == true) {
      return;
    }
    final picked = await showRecordTimePickerSheet(
      context,
      initialTime: _startTime,
    );
    if (picked == null || !mounted || isDraftBusy || !_ownerCurrent) return;
    setState(() {
      _error = null;
      _timeChanged = true;
      _startTime = picked;
    });
  }

  Future<void> _pickReminder() async {
    if (isDraftBusy || !_ownerCurrent) return;
    final picked = await showRecordPickerSheet<String>(
      context,
      builder: (context) => _ReminderPickerSheet(initialValue: _reminder),
    );
    if (picked != null && mounted && !isDraftBusy && _ownerCurrent) {
      setState(() => _reminder = picked);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving || _deleting) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(petProvider.notifier);
    final owner = notifier.routineContext;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (!notifier.isRoutineContextCurrent(owner)) {
      setState(() => _saving = false);
      return;
    }
    try {
      final state = ref.read(petProvider);
      final petId = state.activePetId;
      if (petId == null) throw StateError('Active pet is required');
      final now = DateTime.now();
      final editing = widget.editingSchedule;
      final end = _preservedEnd(editing);
      final schedule = CareSchedule(
        id: editing?.id ?? 'local-${now.microsecondsSinceEpoch}',
        petId: editing?.petId ?? petId,
        categoryId: editing != null && !_categoryChanged
            ? editing.categoryId
            : _selectedCategory!.id,
        title: _titleController.text.trim(),
        startDate: _isoDate(_startDate),
        startTime: editing != null && (editing.allDay || !_timeChanged)
            ? editing.startTime
            : _formatTime(_startTime),
        endDate: end.$1,
        endTime: end.$2,
        allDay: editing?.allDay ?? false,
        place: _emptyToNull(_placeController.text),
        memo: _emptyToNull(_memoController.text),
        reminder: _reminder,
        createdAt: editing?.createdAt ?? now.toIso8601String(),
      );
      final saved = editing == null
          ? await ref.read(petProvider.notifier).addCareSchedule(schedule)
          : await ref.read(petProvider.notifier).updateCareSchedule(schedule);
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      await allowDraftExit();
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      if (editing == null) {
        context.go('/routine?date=${saved.startDate}&tab=schedules');
      } else {
        context.go('/routine/schedule/${saved.id}');
      }
    } catch (_) {
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      setState(() {
        _saving = false;
        _error = '저장에 실패했어요. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final editing = widget.editingSchedule;
    if (editing == null ||
        !_ownerCurrent ||
        _saving ||
        _deleting ||
        _confirmingDelete) {
      return;
    }
    final notifier = ref.read(petProvider.notifier);
    final owner = notifier.routineContext;
    _confirmingDelete = true;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted || !notifier.isRoutineContextCurrent(owner)) {
      _confirmingDelete = false;
      return;
    }
    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: '일정을 삭제할까요?',
      message: '삭제한 일정은 다시 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      confirmKey: const Key('schedule-delete-confirm-button'),
    );
    _confirmingDelete = false;
    if (confirmed != true ||
        !mounted ||
        !notifier.isRoutineContextCurrent(owner)) {
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(petProvider.notifier).deleteCareSchedule(editing.id);
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      await allowDraftExit();
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      context.go('/routine?date=${editing.startDate}');
    } catch (_) {
      if (!mounted || !notifier.isRoutineContextCurrent(owner)) return;
      setState(() {
        _deleting = false;
        _error = '삭제에 실패했어요. 잠시 뒤 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _goBack() async {
    if (!await confirmDraftExit() || !mounted) return;
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

  (String, String?) _preservedEnd(CareSchedule? editing) {
    if (editing == null) return (_isoDate(_startDate), _formatTime(_startTime));
    final oldDate = _parseIsoDate(editing.startDate);
    final dayShift = DateTime.utc(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    ).difference(DateTime.utc(oldDate.year, oldDate.month, oldDate.day));
    if (editing.allDay) {
      final endDate = _parseIsoDate(editing.endDate);
      return (
        _isoDate(
          DateTime.utc(endDate.year, endDate.month, endDate.day).add(dayShift),
        ),
        editing.endTime,
      );
    }
    final oldTime = _parseScheduleTime(editing.startTime);
    final endTime = _parseScheduleTime(editing.endTime);
    if (endTime == null) {
      final endDate = _parseIsoDate(editing.endDate);
      return (
        _isoDate(
          DateTime.utc(endDate.year, endDate.month, endDate.day).add(dayShift),
        ),
        null,
      );
    }
    final minuteShift = oldTime == null
        ? 0
        : (_startTime.hour - oldTime.hour) * 60 +
              _startTime.minute -
              oldTime.minute;
    if (dayShift == Duration.zero && minuteShift == 0) {
      return (editing.endDate, editing.endTime);
    }
    final endDate = _parseIsoDate(editing.endDate);
    final shiftedEnd = DateTime.utc(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    ).add(dayShift + Duration(minutes: minuteShift));
    return (
      _isoDate(shiftedEnd),
      _formatTime(TimeOfDay.fromDateTime(shiftedEnd)),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final bool allDay;
  final DateTime date;
  final TimeOfDay time;
  final Key dateKey;
  final Key timeKey;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    this.allDay = false,
    required this.date,
    required this.time,
    required this.dateKey,
    required this.timeKey,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateButton = _ValueButton(
      key: dateKey,
      value: DateFormat('yyyy.MM.dd').format(date),
      onTap: onPickDate,
    );
    final timeButton = allDay
        ? const _ValueField(value: '종일')
        : _ValueButton(
            key: timeKey,
            value: _formatTime(time),
            onTap: onPickTime,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
        const label = AppText(
          '일시',
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        );
        if (constraints.maxWidth < 280 * scale) {
          if (scale <= 1) {
            return Row(
              children: [
                label,
                const SizedBox(width: 8),
                Expanded(flex: 3, child: dateButton),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: timeButton),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              const SizedBox(height: 6),
              dateButton,
              const SizedBox(height: 6),
              timeButton,
            ],
          );
        }
        return Row(
          children: [
            label,
            const SizedBox(width: 8),
            Expanded(flex: 3, child: dateButton),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: timeButton),
          ],
        );
      },
    );
  }
}

class _ValueButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _ValueButton({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: AppInkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: AppText(value, fontSize: 13, color: AppColors.text),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueField extends StatelessWidget {
  final String value;

  const _ValueField({required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AppText(value, fontSize: 13, color: AppColors.text),
      ),
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
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: AppInkWell(
          key: Key('schedule-category-${category.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AppVisual(
                  id: scheduleVisualId(category.id),
                  size: 32,
                  color: category.color,
                ),
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
  late List<String> _choices;
  late int _index;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _choices = _reminders.contains(widget.initialValue)
        ? _reminders
        : [widget.initialValue, ..._reminders];
    _index = _choices.indexOf(widget.initialValue);
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
      value: () => _choices[_index],
      child: SizedBox(
        height: 220,
        child: CupertinoPicker.builder(
          key: const Key('schedule-reminder-wheel'),
          scrollController: _controller,
          itemExtent: RecordInputStyle.pickerItemExtent,
          onSelectedItemChanged: (index) => setState(() => _index = index),
          childCount: _choices.length,
          itemBuilder: (context, index) => Center(
            child: AppText(
              _choices[index],
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
  final Color color;

  const _ScheduleCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.color,
  });
}

const _categories = [
  _ScheduleCategory(
    id: 'grooming',
    label: '미용',
    description: '목욕, 미용, 발톱 관리 일정을 기록해요.',
    color: Color(0xFFD4779B),
  ),
  _ScheduleCategory(
    id: 'hospital',
    label: '병원 예약',
    description: '진료와 예방접종 예약을 잊지 않게 챙겨요.',
    color: Color(0xFF5B8DEF),
  ),
  _ScheduleCategory(
    id: 'travel',
    label: '여행숙박',
    description: '함께 떠나는 여행과 숙박 일정을 기록해요.',
    color: Color(0xFF8D7A64),
  ),
  _ScheduleCategory(
    id: 'hotel',
    label: '호텔링',
    description: '돌봄과 호텔링 일정을 미리 확인해요.',
    color: Color(0xFF5E9F7B),
  ),
  _ScheduleCategory(
    id: 'outing',
    label: '카페외출',
    description: '카페와 외출 약속을 기록해요.',
    color: Color(0xFFE29B45),
  ),
  _ScheduleCategory(
    id: 'event',
    label: '행사이벤트',
    description: '행사와 이벤트 일정을 모아봐요.',
    color: Color(0xFF8D6CCF),
  ),
  _ScheduleCategory(
    id: 'etc',
    label: '기타',
    description: '그 밖의 중요한 일정을 기록해요.',
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
    fillColor: AppInteractionStyle.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
