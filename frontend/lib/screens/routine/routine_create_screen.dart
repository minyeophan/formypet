import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/keyboard_utils.dart';
import '../../core/record_utils.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/record_inputs/record_date_time_pickers.dart';

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
    final routine = ref.watch(petProvider).routines
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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final routine = widget.editingRoutine;
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
      if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        _time = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '루틴 추가',
        showBackButton: true,
        centerTitle: true,
        onBack: _goBack,
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
                  time: _time,
                  repeatType: _repeatType,
                  days: _days,
                  saving: _saving,
                  error: _error,
                  onBackToTypes: () => setState(() => _selectedType = null),
                  onPickTime: _pickTime,
                  onRepeatChanged: _changeRepeatType,
                  onToggleDay: _toggleDay,
                  onSave: _canSave ? _saveRoutine : null,
                ),
        ),
      ),
    );
  }

  bool get _canSave {
    if (_saving || _selectedType == null) return false;
    return !_usesDays(_repeatType) || _days.isNotEmpty;
  }

  void _selectType(_RoutineTypeOption option) {
    setState(() {
      _selectedType = option;
      _error = null;
    });
  }

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
      'startDate': widget.editingRoutine?.startDate ?? todayString(),
      'notificationEnabled': widget.editingRoutine?.notificationEnabled ?? true,
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
        await ref.read(petProvider.notifier).updateRoutine(
          widget.editingRoutine!.id,
          _buildPayload(),
        );
      }
      if (mounted) context.go('/routine');
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
            child: InkWell(
              key: Key('routine-type-${option.typeId}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(option),
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
                      child: AppVisual(
                        id: recordTypeVisualId(option.typeId),
                        size: 24,
                        color: option.color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppText(
                        recordTypeLabel(option.typeId),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineDetailStep extends StatelessWidget {
  final _RoutineTypeOption selectedType;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final TimeOfDay time;
  final String repeatType;
  final Set<int> days;
  final bool saving;
  final String? error;
  final VoidCallback onBackToTypes;
  final VoidCallback onPickTime;
  final ValueChanged<String> onRepeatChanged;
  final ValueChanged<int> onToggleDay;
  final VoidCallback? onSave;

  const _RoutineDetailStep({
    required this.selectedType,
    required this.nameController,
    required this.noteController,
    required this.time,
    required this.repeatType,
    required this.days,
    required this.saving,
    required this.error,
    required this.onBackToTypes,
    required this.onPickTime,
    required this.onRepeatChanged,
    required this.onToggleDay,
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
            decoration: _inputDecoration(recordTypeLabel(selectedType.typeId)),
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
          child: InkWell(
            key: const Key('routine-time-field'),
            borderRadius: BorderRadius.circular(14),
            onTap: onPickTime,
            child: _ValueField(value: _formatTime(time)),
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
                        label: AppText(entry.value),
                        selected: repeatType == entry.key,
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.22,
                        ),
                        onSelected: (_) => onRepeatChanged(entry.key),
                      ),
                    )
                    .toList(),
              ),
              if (_usesDays(repeatType)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: List.generate(
                    _weekDays.length,
                    (index) => ChoiceChip(
                      key: Key('routine-day-$index'),
                      label: AppText(_weekDays[index]),
                      selected: days.contains(index),
                      selectedColor: AppColors.primary.withValues(alpha: 0.22),
                      onSelected: (_) => onToggleDay(index),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AppText(error!, fontSize: 12, color: Colors.redAccent),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
