import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../core/record_utils.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/record_inputs/record_date_time_pickers.dart';
import '../../widgets/record_inputs/record_edit_action_bar.dart';
import '../../widgets/record_inputs/record_input_style.dart';
import '../../widgets/record_inputs/record_picker_sheet.dart';

class RoutineCreateScreen extends ConsumerStatefulWidget {
  final Routine? editingRoutine;

  const RoutineCreateScreen({super.key, this.editingRoutine});

  @override
  ConsumerState<RoutineCreateScreen> createState() =>
      _RoutineCreateScreenState();
}

class RoutineEditScreen extends ConsumerWidget {
  final String routineId;

  const RoutineEditScreen({super.key, required this.routineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ref
        .watch(petProvider)
        .routines
        .where((item) => item.id == routineId)
        .firstOrNull;
    if (routine == null) {
      return const Scaffold(body: Center(child: Text('루틴을 찾을 수 없습니다.')));
    }
    return RoutineCreateScreen(editingRoutine: routine);
  }
}

class _RoutineCreateScreenState extends ConsumerState<RoutineCreateScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  _RoutineTypeOption? _selectedType;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _repeatType = 'daily';
  final _days = <int>{};
  late DateTime _startDate;
  DateTime? _endDate;
  bool _notificationEnabled = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    final routine = widget.editingRoutine;
    _startDate = _dateOnly(
      routine == null ? DateTime.now() : DateTime.parse(routine.startDate),
    );
    _endDate = routine?.endDate == null
        ? null
        : _dateOnly(DateTime.parse(routine!.endDate!));
    _notificationEnabled = routine?.notificationEnabled ?? true;
    if (routine == null) return;
    _selectedType = _routineTypeOptions.firstWhere(
      (option) => option.typeId == routine.typeId,
      orElse: () => _routineTypeOptions.first,
    );
    _nameController.text = routine.label;
    _noteController.text = routine.note ?? '';
    _repeatType = routine.repeatType;
    _days.addAll(routine.days);
    if (routine.times.isNotEmpty) {
      final parts = routine.times.first.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        _time = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: widget.editingRoutine == null ? '루틴 추가' : '루틴 수정',
        showBackButton: true,
        centerTitle: true,
        onBack: _goBack,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormSection(
                label: '카테고리',
                child: Row(
                  children: _routineTypeOptions
                      .map(
                        (option) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: option == _routineTypeOptions.last ? 0 : 8,
                            ),
                            child: _RoutineCategoryButton(
                              option: option,
                              selected: _selectedType == option,
                              onTap: () => _selectType(option),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '루틴 제목',
                child: TextField(
                  key: const Key('routine-name-field'),
                  controller: _nameController,
                  decoration: _inputDecoration('루틴 제목을 입력해 주세요'),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '기간',
                child: Column(
                  children: [
                    _RoutineDateField(
                      fieldKey: const Key('routine-start-date-field'),
                      label: '시작일',
                      value: _formatDate(_startDate),
                      onTap: _pickStartDate,
                    ),
                    const SizedBox(height: 10),
                    _RoutineDateField(
                      fieldKey: const Key('routine-end-date-field'),
                      label: '종료일',
                      value: _endDate == null
                          ? '종료일 없음'
                          : _formatDate(_endDate!),
                      onTap: _pickEndDate,
                      onClear: _endDate == null ? null : _clearEndDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '시간',
                child: InkWell(
                  key: const Key('routine-time-field'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickTime,
                  child: _ValueField(value: _formatTime(_time)),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '반복',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _repeatOptions.entries
                          .map(
                            (entry) => ChoiceChip(
                              label: AppText(
                                entry.value,
                                color: _repeatType == entry.key
                                    ? AppColors.white
                                    : AppColors.text,
                              ),
                              selected: _repeatType == entry.key,
                              showCheckmark: false,
                              backgroundColor: AppColors.white,
                              selectedColor: AppColors.primary,
                              side: BorderSide(
                                color: _repeatType == entry.key
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              onSelected: (_) => _changeRepeatType(entry.key),
                            ),
                          )
                          .toList(),
                    ),
                    if (_usesDays(_repeatType)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: List.generate(
                          _weekDays.length,
                          (index) => ChoiceChip(
                            key: Key('routine-day-$index'),
                            label: AppText(_weekDays[index]),
                            selected: _days.contains(index),
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.22,
                            ),
                            onSelected: (_) => _toggleDay(index),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '알림',
                child: InkWell(
                  key: const Key('routine-notification-button'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickNotification,
                  child: _ValueField(
                    value: _notificationEnabled ? '알림 사용' : '알림 없음',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                label: '메모',
                child: TextField(
                  key: const Key('routine-note-field'),
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('복용량, 사료명 등을 입력해 주세요'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(_error!, fontSize: 12, color: Colors.redAccent),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _canSave ? _saveRoutine : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: _saving
                        ? AppColors.primary
                        : AppColors.surfaceSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: AppText(
                    _saving ? '저장 중' : '저장',
                    color: _canSave ? AppColors.white : AppColors.muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.editingRoutine != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('routine-delete-button'),
                    onPressed: _saving ? null : _deleteRoutine,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const AppText(
                      '루틴 삭제',
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSave {
    if (_saving || _selectedType == null) return false;
    if (_nameController.text.trim().isEmpty) return false;
    return !_usesDays(_repeatType) || _days.isNotEmpty;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _selectType(_RoutineTypeOption option) {
    setState(() {
      _selectedType = option;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _routineTypeLabel(option.typeId);
      }
      _error = null;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = _dateOnly(picked);
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = _dateOnly(picked));
    }
  }

  void _clearEndDate() => setState(() => _endDate = null);

  void _changeRepeatType(String repeatType) {
    setState(() {
      _repeatType = repeatType;
      if (_usesDays(repeatType) && _days.isEmpty) {
        _days.add(DateTime.now().weekday % 7);
      }
    });
  }

  void _toggleDay(int day) {
    setState(() {
      if (!_days.remove(day)) _days.add(day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showRecordTimePickerSheet(context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Map<String, dynamic> _buildPayload() {
    final selectedType = _selectedType!;
    final label = _nameController.text.trim().isEmpty
        ? recordTypeLabel(selectedType.typeId)
        : _nameController.text.trim();
    final note = _noteController.text.trim();
    final days = _usesDays(_repeatType) ? (_days.toList()..sort()) : <int>[];
    return {
      'label': label,
      'typeId': selectedType.typeId,
      'repeatType': _repeatType,
      'times': [_formatTime(_time)],
      'days': days,
      'startDate': _isoDate(_startDate),
      if (_endDate != null) 'endDate': _isoDate(_endDate!),
      'notificationEnabled': _notificationEnabled,
      if (_repeatType == 'monthly') 'monthlyInterval': 1,
      if (note.isNotEmpty) 'note': note,
    };
  }

  Future<void> _saveRoutine() async {
    if (!_canSave) return;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.editingRoutine == null) {
        await ref.read(petProvider.notifier).addRoutine(_buildPayload());
      } else {
        await ref
            .read(petProvider.notifier)
            .updateRoutine(widget.editingRoutine!.id, _buildPayload());
      }
      if (mounted) {
        if (widget.editingRoutine == null) {
          context.go('/routine?tab=routines');
        } else {
          context.go('/routine/${widget.editingRoutine!.id}');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '저장에 실패했어요. 잠시 후 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickNotification() async {
    final picked = await showRecordPickerSheet<bool>(
      context,
      builder: (context) => _NotificationPickerSheet(
        initialValue: _notificationEnabled,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _notificationEnabled = picked);
    }
  }

  Future<void> _deleteRoutine() async {
    final routine = widget.editingRoutine;
    if (routine == null || _saving) return;
    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: '루틴을 삭제할까요?',
      message: '삭제한 루틴과 완료 기록은 다시 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      confirmKey: const Key('routine-delete-confirm-button'),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(petProvider.notifier).deleteRoutine(routine.id);
      if (mounted) context.go('/routine?tab=routines');
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '삭제에 실패했어요. 잠시 후 다시 시도해 주세요.';
        });
      }
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/routine');
    }
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
      child: AppText(value, fontSize: 14, color: AppColors.text),
    );
  }
}

class _NotificationPickerSheet extends StatefulWidget {
  final bool initialValue;

  const _NotificationPickerSheet({required this.initialValue});

  @override
  State<_NotificationPickerSheet> createState() =>
      _NotificationPickerSheetState();
}

class _NotificationPickerSheetState extends State<_NotificationPickerSheet> {
  late int _index;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _index = widget.initialValue ? 0 : 1;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['알림 사용', '알림 없음'];
    return RecordPickerSheet<bool>(
      value: () => _index == 0,
      child: SizedBox(
        height: 180,
        child: CupertinoPicker.builder(
          key: const Key('routine-notification-wheel'),
          scrollController: _controller,
          itemExtent: RecordInputStyle.pickerItemExtent,
          onSelectedItemChanged: (index) => setState(() => _index = index),
          childCount: labels.length,
          itemBuilder: (context, index) => Center(
            child: AppText(
              labels[index],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineCategoryButton extends StatelessWidget {
  final _RoutineTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RoutineCategoryButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('routine-category-${option.typeId}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppVisual(
              id: recordTypeVisualId(option.typeId),
              size: 22,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 5),
            AppText(
              _routineTypeLabel(option.typeId),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineDateField extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _RoutineDateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: AppText(label, fontSize: 12, color: AppColors.textSecondary),
        ),
        Expanded(
          child: InkWell(
            key: fieldKey,
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: _ValueField(value: value),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: '종료일 제거',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ],
    );
  }
}

class _RoutineTypeOption {
  final String typeId;
  final Color color;

  const _RoutineTypeOption({required this.typeId, required this.color});
}

const _routineTypeOptions = [
  _RoutineTypeOption(typeId: 'medicine', color: Color(0xFF5E9F7B)),
  _RoutineTypeOption(typeId: 'meal', color: Color(0xFFE29B45)),
  _RoutineTypeOption(typeId: 'vet', color: Color(0xFFD4667A)),
];

const _repeatOptions = {
  'daily': '매일',
  'weekly': '매주',
  'biweekly': '격주',
  'monthly': '매월',
};

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

bool _usesDays(String repeatType) =>
    repeatType == 'weekly' || repeatType == 'biweekly';

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _routineTypeLabel(String typeId) => switch (typeId) {
  'medicine' => '투약',
  'meal' => '급식',
  'vet' => '병원 관리',
  _ => recordTypeLabel(typeId),
};

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
