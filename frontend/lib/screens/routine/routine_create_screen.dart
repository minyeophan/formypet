import '../../core/app_interaction_style.dart';
import '../../widgets/app_ink_well.dart';
import '../../widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/api_client.dart';
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

class RoutineEditScreen extends ConsumerStatefulWidget {
  final String routineId;

  const RoutineEditScreen({super.key, required this.routineId});

  @override
  ConsumerState<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends ConsumerState<RoutineEditScreen> {
  Routine? _baseline;
  String? _error;
  bool _loading = true;
  bool _started = false;
  bool _waitedForInitialLoad = false;
  bool _exiting = false;
  (int, int, String?)? _owner;
  @override
  void initState() {
    super.initState();
    _waitedForInitialLoad = ref.read(petProvider).isLoading;
  }

  Future<void> _load() async {
    final notifier = ref.read(petProvider.notifier);
    final token = notifier.routineContext;
    _owner ??= token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reused = _waitedForInitialLoad;
      if (!_waitedForInitialLoad) await notifier.reloadRoutines();
      _waitedForInitialLoad = false;
      if (!mounted || !notifier.isRoutineContextCurrent(token)) return;
      final state = ref.read(petProvider);
      setState(() {
        _baseline = state.routines
            .where(
              (r) => r.id == widget.routineId && r.petId == state.activePetId,
            )
            .firstOrNull;
        _loading = false;
        _error = reused ? state.dataErrorText : null;
      });
    } catch (error) {
      if (!mounted || !notifier.isRoutineContextCurrent(token)) return;
      final api = error is DioException ? parseApiError(error) : error;
      setState(() {
        _loading = false;
        _error = api is ApiException && api.statusCode == 403
            ? '이 루틴에 접근할 수 없어요.'
            : '루틴을 불러오지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    if (_owner != null &&
        !ref.read(petProvider.notifier).isRoutineContextCurrent(_owner!)) {
      if (!_exiting &&
          state.activePetId != null &&
          ref.read(petProvider.notifier).routineContext.$1 == _owner!.$1) {
        _exiting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/routine?tab=routines');
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_started && !state.isLoading) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (_baseline != null) {
      return RoutineCreateScreen(
        key: ValueKey((_owner, widget.routineId)),
        editingRoutine: _baseline,
      );
    }
    return Scaffold(
      appBar: AppHeader(
        title: '루틴 수정',
        showBackButton: true,
        onBack: () => context.go('/routine?tab=routines'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '루틴을 찾을 수 없습니다.'),
                  if (_error != null)
                    TextButton(onPressed: _load, child: const Text('다시 시도')),
                  TextButton(
                    onPressed: () => context.go('/routine?tab=routines'),
                    child: const Text('목록으로'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoutineCreateScreenState extends ConsumerState<RoutineCreateScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  _RoutineTypeOption? _selectedType;
  final _monthlyIntervalController = TextEditingController(text: '1');
  List<String> _times = ['08:00'];
  List<int> _timeIds = [0];
  int _nextTimeId = 1;
  bool _pickingTime = false;
  bool _missing = false;
  late final (int, int, String?) _editContext;
  _RoutineTypeOption? _originalType;
  String _repeatType = 'daily';
  final _days = <int>{};
  late DateTime _startDate;
  DateTime? _endDate;
  bool _notificationEnabled = true;
  bool _saving = false;
  bool _nameEdited = false;
  bool _confirming = false;
  bool _leaving = false;
  String? _error;
  String? _initialLabel;
  String? _initialTypeId;
  String? _initialRepeatType;
  List<int> _initialDays = const [];
  String? _initialStartDate;
  String? _initialEndDate;
  List<String> _initialTimes = const [];
  String? _initialNote;
  bool? _initialNotificationEnabled;
  int _initialMonthlyInterval = 1;

  @override
  void initState() {
    super.initState();
    _editContext = ref.read(petProvider.notifier).routineContext;
    _nameController.addListener(_refresh);
    _noteController.addListener(_refresh);
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
      orElse: () =>
          _RoutineTypeOption(typeId: routine.typeId, color: AppColors.primary),
    );
    _nameController.text = routine.label;
    _originalType = _selectedType;
    _noteController.text = routine.note ?? '';
    _repeatType = routine.repeatType;
    _days.addAll(routine.days);
    _times = [...routine.times]..sort();
    _timeIds = List.generate(_times.length, (_) => _nextTimeId++);
    _monthlyIntervalController.text = routine.monthlyInterval.toString();
    _initialLabel = routine.label;
    _initialTypeId = routine.typeId;
    _initialRepeatType = routine.repeatType;
    _initialDays = [...routine.days]..sort();
    _initialStartDate = routine.startDate;
    _initialEndDate = routine.endDate;
    _initialTimes = [...routine.times]..sort();
    _initialNote = routine.note;
    _initialNotificationEnabled = routine.notificationEnabled;
    _initialMonthlyInterval = routine.monthlyInterval;
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _noteController.removeListener(_refresh);
    _noteController.dispose();
    _monthlyIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(petProvider, (previous, next) {
      final notifier = ref.read(petProvider.notifier);
      if (_leaving || notifier.isRoutineContextCurrent(_editContext)) return;
      _leaving = true;
      if (next.activePetId != null &&
          notifier.routineContext.$1 == _editContext.$1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/routine?tab=routines');
        });
      }
    });
    if (_missing) {
      return Scaffold(
        appBar: AppHeader(
          title: '루틴 수정',
          showBackButton: true,
          onBack: () => context.go('/routine?tab=routines'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('루틴을 찾을 수 없습니다.'),
              TextButton(
                onPressed: () => context.go('/routine?tab=routines'),
                child: const Text('목록으로'),
              ),
            ],
          ),
        ),
      );
    }
    final chipShape =
        ChipTheme.of(context).shape ??
        (Theme.of(context).useMaterial3
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              )
            : const StadiumBorder());
    return PopScope(
      canPop: _leaving || (!_saving && !_hasChanges),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppHeader(
          title: widget.editingRoutine == null ? '루틴 추가' : '루틴 수정',
          showBackButton: true,
          centerTitle: true,
          onBack: _goBack,
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _saving || _confirming,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormSection(
                    label: '카테고리',
                    child: Row(
                      children: _availableTypeOptions
                          .map(
                            (option) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: option == _availableTypeOptions.last
                                      ? 0
                                      : 8,
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
                      enabled: !_saving && !_confirming,
                      onChanged: (_) => setState(() => _nameEdited = true),
                      decoration: _inputDecoration('루틴 제목을 입력해 주세요').copyWith(
                        errorText: _nameController.text.trim().runes.length > 30
                            ? '제목은 30자 이내로 입력해 주세요'
                            : (_nameEdited &&
                                      _nameController.text.trim().isEmpty
                                  ? '제목을 입력해 주세요'
                                  : null),
                      ),
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
                    child: Column(
                      children: [
                        for (var index = 0; index < _times.length; index++)
                          Padding(
                            key: ValueKey(_timeIds[index]),
                            padding: EdgeInsets.only(
                              bottom: index == _times.length - 1 ? 0 : 8,
                            ),
                            child: _TimeRow(
                              key: index == 0
                                  ? const Key('routine-time-field')
                                  : Key('routine-time-$index'),
                              value: _times[index],
                              onTap: () => _pickTime(index),
                              onDelete: () => _removeTime(index),
                              canDelete:
                                  _times.length > 1 ||
                                  (widget.editingRoutine != null &&
                                      _initialTimes.isEmpty),
                            ),
                          ),
                        if (_times.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: AppText(
                              '등록된 시간이 없어 예약 알림이 발송되지 않아요.',
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        if (_times.any((time) => !_validTime(time)))
                          const Text(
                            '잘못된 시간을 수정하거나 삭제해 주세요.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('routine-add-time-button'),
                            onPressed: _saving ? null : () => _pickTime(null),
                            icon: const Icon(Icons.add),
                            label: const Text('시간 추가'),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            '시간별로 알림을 받아요. 완료는 하루 단위로 기록해요.',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
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
                                (entry) => AppFocusIndicator(
                                  filled: _repeatType == entry.key,
                                  shape: chipShape,
                                  child: ChoiceChip(
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
                                    color: WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.disabled)
                                          ? AppColors.surfaceSoft
                                          : states.contains(
                                              WidgetState.selected,
                                            )
                                          ? AppColors.primary
                                          : AppColors.white,
                                    ),
                                    side: BorderSide(
                                      color: _repeatType == entry.key
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                    onSelected: (_) =>
                                        _changeRepeatType(entry.key),
                                  ),
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
                              (index) => AppFocusIndicator(
                                filled: false,
                                shape: chipShape,
                                child: ChoiceChip(
                                  key: Key('routine-day-$index'),
                                  label: AppText(_weekDays[index]),
                                  selected: _days.contains(index),
                                  color: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.disabled)
                                        ? AppColors.surfaceSoft
                                        : states.contains(WidgetState.selected)
                                        ? AppColors.primary.withValues(
                                            alpha: 0.22,
                                          )
                                        : AppColors.white,
                                  ),
                                  selectedColor: AppColors.primary.withValues(
                                    alpha: 0.22,
                                  ),
                                  onSelected: (_) => _toggleDay(index),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_repeatType == 'monthly') ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('routine-monthly-interval-field'),
                            controller: _monthlyIntervalController,
                            enabled: !_saving && !_confirming,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('몇 개월마다 반복할까요?')
                                .copyWith(
                                  labelText: '반복 간격 (개월)',
                                  helperText: '해당 날짜가 없는 달은 건너뜁니다.',
                                  errorText: _monthlyIntervalError,
                                ),
                            onChanged: (_) => _refresh(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormSection(
                    label: '알림',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: AppInkWell(
                        key: const Key('routine-notification-button'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickNotification,
                        child: _ValueField(
                          value: _notificationEnabled ? '알림 사용' : '알림 없음',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormSection(
                    label: '메모',
                    child: TextField(
                      key: const Key('routine-note-field'),
                      controller: _noteController,
                      enabled: !_saving && !_confirming,
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
                        style:
                            OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ).copyWith(
                              overlayColor: AppInteractionStyle.overlay(
                                danger: true,
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
        ),
      ),
    );
  }

  bool get _canSave {
    if (_leaving ||
        !ref.read(petProvider.notifier).isRoutineContextCurrent(_editContext)) {
      return false;
    }
    if (_pickingTime) return false;
    if (_saving || _confirming || _selectedType == null) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_nameController.text.trim().runes.length > 30) return false;
    if (_repeatType == 'monthly' && !_validMonthlyInterval) return false;
    if (_times.any((value) => !_validTime(value))) return false;
    if (widget.editingRoutine != null && !_hasChanges) return false;
    return !_usesDays(_repeatType) || _days.isNotEmpty;
  }

  bool get _hasChanges {
    if (widget.editingRoutine == null) {
      return _repeatType != 'daily' ||
          !_listEquals(_times, const ['08:00']) ||
          _endDate != null ||
          !_notificationEnabled ||
          _selectedType != null ||
          _nameController.text.isNotEmpty ||
          _noteController.text.isNotEmpty;
    }
    final days = [..._days]..sort();
    final times = [..._times]..sort();
    final note = _noteController.text;
    final startDate = _isoDate(_startDate);
    final endDate = _endDate == null ? null : _isoDate(_endDate!);
    final interval = int.tryParse(_monthlyIntervalController.text.trim()) ?? 0;
    return _nameController.text.trim() != _initialLabel ||
        _selectedType?.typeId != _initialTypeId ||
        _repeatType != _initialRepeatType ||
        (_usesDays(_repeatType) && !_listEquals(days, _initialDays)) ||
        !_listEquals(times, _initialTimes) ||
        startDate != _initialStartDate ||
        endDate != _initialEndDate ||
        note != (_initialNote ?? '') ||
        _notificationEnabled != _initialNotificationEnabled ||
        (_repeatType == 'monthly' && interval != _initialMonthlyInterval);
  }

  List<_RoutineTypeOption> get _availableTypeOptions {
    final selected = _originalType;
    if (selected == null ||
        _routineTypeOptions.any((option) => option.typeId == selected.typeId)) {
      return _routineTypeOptions;
    }
    return [..._routineTypeOptions, selected];
  }

  bool get _validMonthlyInterval {
    final value = int.tryParse(_monthlyIntervalController.text.trim());
    return value != null && value >= 1 && value <= 2147483647;
  }

  String? get _monthlyIntervalError {
    if (_validMonthlyInterval) return null;
    final value = BigInt.tryParse(_monthlyIntervalController.text.trim());
    return value != null && value > BigInt.from(2147483647)
        ? '입력값이 너무 커요'
        : '1 이상의 정수를 입력해 주세요';
  }

  bool _validTime(String value) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return false;
    final parts = value.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour < 24 &&
        minute >= 0 &&
        minute < 60;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _selectType(_RoutineTypeOption option) {
    if (_saving || _confirming || _leaving) return;
    setState(() {
      _selectedType = option;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _routineTypeLabel(option.typeId);
      }
      _error = null;
    });
  }

  Future<void> _pickStartDate() async {
    if (_saving || _confirming || _leaving) return;
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted || _leaving) return;
    setState(() {
      _startDate = _dateOnly(picked);
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
        _error = '종료일을 시작일에 맞춰 변경했어요.';
      }
    });
  }

  Future<void> _pickEndDate() async {
    if (_saving || _confirming || _leaving) return;
    final picked = await showRecordDatePickerSheet(
      context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted && !_leaving) {
      setState(() => _endDate = _dateOnly(picked));
    }
  }

  void _clearEndDate() {
    if (!_saving && !_confirming && !_leaving) setState(() => _endDate = null);
  }

  void _changeRepeatType(String repeatType) {
    if (_saving || _confirming || _leaving) return;
    setState(() {
      _repeatType = repeatType;
      if (_usesDays(repeatType) && _days.isEmpty) {
        _days.add(DateTime.now().weekday % 7);
      }
    });
  }

  void _toggleDay(int day) {
    if (_saving || _confirming || _leaving) return;
    setState(() {
      if (!_days.remove(day)) _days.add(day);
    });
  }

  Future<void> _pickTime(int? index) async {
    if (_saving || _confirming || _pickingTime) return;
    setState(() => _pickingTime = true);
    final existing = index == null || index >= _times.length
        ? '08:00'
        : _times[index];
    final parts = existing.split(':');
    final initial = TimeOfDay(
      hour: _validTime(existing) ? int.parse(parts[0]) : 8,
      minute: _validTime(existing) ? int.parse(parts[1]) : 0,
    );
    final picked = await showRecordTimePickerSheet(
      context,
      initialTime: initial,
    );
    if (!mounted) return;
    setState(() => _pickingTime = false);
    if (picked == null || _leaving) return;
    final value = _formatTime(picked);
    if (index != null && _times[index] == value) return;
    final duplicate = _times.asMap().entries.any(
      (entry) => entry.key != index && entry.value == value,
    );
    if (duplicate) {
      setState(() => _error = '이미 등록된 시간이에요.');
      return;
    }
    setState(() {
      if (index == null) {
        _times.add(value);
        _timeIds.add(_nextTimeId++);
      } else {
        _times[index] = value;
      }
      final entries = List.generate(
        _times.length,
        (i) => (_times[i], _timeIds[i]),
      )..sort((a, b) => a.$1.compareTo(b.$1));
      _times = entries.map((e) => e.$1).toList();
      _timeIds = entries.map((e) => e.$2).toList();
      _error = null;
    });
  }

  void _removeTime(int index) {
    if (_saving || _confirming) return;
    if (_times.length == 1 &&
        (widget.editingRoutine == null || _initialTimes.isNotEmpty)) {
      return;
    }
    setState(() {
      _times = [..._times]..removeAt(index);
      _timeIds.removeAt(index);
    });
  }

  Map<String, dynamic> _buildPayload() {
    final selectedType = _selectedType!;
    final label = _nameController.text.trim().isEmpty
        ? recordTypeLabel(selectedType.typeId)
        : _nameController.text.trim();
    final note = _noteController.text;
    final days = _usesDays(_repeatType) ? (_days.toList()..sort()) : <int>[];
    final full = {
      'label': label,
      'typeId': selectedType.typeId,
      'repeatType': _repeatType,
      'times': [..._times]..sort(),
      'days': days,
      'startDate': _isoDate(_startDate),
      if (_endDate != null) 'endDate': _isoDate(_endDate!),
      if (_endDate == null && widget.editingRoutine != null)
        'clearEndDate': true,
      'notificationEnabled': _notificationEnabled,
      if (_repeatType == 'monthly')
        'monthlyInterval': int.parse(_monthlyIntervalController.text.trim()),
      if (note.isNotEmpty || widget.editingRoutine != null) 'note': note,
    };
    if (widget.editingRoutine == null) return full;
    final payload = <String, dynamic>{};
    if (label != _initialLabel) payload['label'] = label;
    if (selectedType.typeId != _initialTypeId) {
      payload['typeId'] = selectedType.typeId;
    }
    if (_repeatType != _initialRepeatType) {
      payload['repeatType'] = _repeatType;
      payload['days'] = days;
      if (_repeatType == 'monthly') {
        payload['monthlyInterval'] = int.parse(
          _monthlyIntervalController.text.trim(),
        );
      }
    } else {
      if (_usesDays(_repeatType) && !_listEquals(days, _initialDays)) {
        payload['days'] = days;
      }
      if (_repeatType == 'monthly' &&
          int.parse(_monthlyIntervalController.text.trim()) !=
              _initialMonthlyInterval) {
        payload['monthlyInterval'] = int.parse(
          _monthlyIntervalController.text.trim(),
        );
      }
    }
    final sortedTimes = [..._times]..sort();
    if (!_listEquals(sortedTimes, _initialTimes)) {
      payload['times'] = sortedTimes;
    }
    final startDate = _isoDate(_startDate);
    if (startDate != _initialStartDate) payload['startDate'] = startDate;
    final endDate = _endDate == null ? null : _isoDate(_endDate!);
    if (endDate != _initialEndDate) {
      if (endDate == null) {
        payload['clearEndDate'] = true;
      } else {
        payload['endDate'] = endDate;
      }
    }
    if (note != (_initialNote ?? '')) payload['note'] = note;
    if (_notificationEnabled != _initialNotificationEnabled) {
      payload['notificationEnabled'] = _notificationEnabled;
    }
    return payload;
  }

  Future<void> _saveRoutine() async {
    if (!_canSave) return;
    final notifier = ref.read(petProvider.notifier);
    final token = notifier.routineContext;
    final payload = _buildPayload();
    final routineId = widget.editingRoutine?.id;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await dismissKeyboardBeforeTransition(context);
      if (!mounted || !notifier.isRoutineContextCurrent(token)) return;
      final applied = routineId == null
          ? await notifier.addRoutine(payload)
          : await notifier.updateRoutine(routineId, payload);
      if (!applied) return;
      if (mounted && !_leaving && notifier.isRoutineContextCurrent(token)) {
        _leaving = true;
        if (widget.editingRoutine == null) {
          context.go('/routine?tab=routines');
        } else {
          context.go('/routine/${widget.editingRoutine!.id}');
        }
      }
    } catch (error) {
      if (mounted && !_leaving && notifier.isRoutineContextCurrent(token)) {
        await _handleFailure(error, deleting: false);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickNotification() async {
    if (_saving || _confirming || _leaving) return;
    final picked = await showRecordPickerSheet<bool>(
      context,
      builder: (context) =>
          _NotificationPickerSheet(initialValue: _notificationEnabled),
    );
    if (picked != null && mounted && !_leaving) {
      setState(() => _notificationEnabled = picked);
    }
  }

  Future<void> _deleteRoutine() async {
    final routine = widget.editingRoutine;
    if (routine == null || _saving || _confirming) return;
    final notifier = ref.read(petProvider.notifier);
    final token = notifier.routineContext;
    setState(() => _confirming = true);
    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: '루틴을 삭제할까요?',
      message: '삭제한 루틴과 완료 기록은 다시 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      confirmKey: const Key('routine-delete-confirm-button'),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true || !notifier.isRoutineContextCurrent(token)) return;
    setState(() => _saving = true);
    try {
      final applied = await notifier.deleteRoutine(routine.id);
      if (!applied) return;
      if (mounted && !_leaving && notifier.isRoutineContextCurrent(token)) {
        _leaving = true;
        context.go('/routine?tab=routines');
      }
    } catch (error) {
      if (mounted && !_leaving && notifier.isRoutineContextCurrent(token)) {
        await _handleFailure(error, deleting: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleFailure(Object error, {required bool deleting}) async {
    if (error is DioException) error = parseApiError(error);
    if (error is ApiException && error.statusCode == 403) {
      setState(() => _error = '이 루틴에 접근할 수 없어요.');
      return;
    }
    if (error is ApiException &&
        (error.statusCode == 400 || error.statusCode == 404) &&
        widget.editingRoutine != null) {
      final notifier = ref.read(petProvider.notifier);
      final token = notifier.routineContext;
      try {
        await notifier.reloadRoutines();
        if (!mounted || _leaving || !notifier.isRoutineContextCurrent(token)) {
          return;
        }
        if (!ref
            .read(petProvider)
            .routines
            .any((r) => r.id == widget.editingRoutine!.id)) {
          if (deleting) {
            _leaving = true;
            context.go('/routine?tab=routines');
          } else {
            setState(() {
              _missing = true;
            });
          }
          return;
        }
      } catch (_) {
        if (mounted && !_leaving && notifier.isRoutineContextCurrent(token)) {
          setState(() => _error = '연결 상태를 확인한 뒤 다시 시도해 주세요. 입력 내용은 유지됩니다.');
        }
        return;
      }
    }
    if (mounted) {
      setState(
        () => _error = deleting
            ? '삭제에 실패했어요. 잠시 후 다시 시도해 주세요.'
            : '저장에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  Future<void> _goBack() async {
    if (_confirming || _leaving) return;
    if (_saving || _hasChanges) {
      setState(() => _confirming = true);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_saving ? '저장 중 화면을 나갈까요?' : '변경 내용을 버릴까요?'),
          content: Text(
            _saving ? '이미 보낸 저장 요청은 계속 처리될 수 있어요.' : '저장하지 않은 변경 내용이 사라져요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 편집'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (discard != true) return;
    }
    setState(() => _leaving = true);
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
    return Ink(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AppText(value, fontSize: 14, color: AppColors.text),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool canDelete;

  const _TimeRow({
    super.key,
    required this.value,
    required this.onTap,
    required this.onDelete,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '$value 시간 수정',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: AppInkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: _ValueField(value: value),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '$value 시간 삭제',
          onPressed: canDelete ? onDelete : null,
          icon: const AppIcon(Icons.remove_circle_outline, size: 20),
        ),
      ],
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
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: AppInkWell(
          key: Key('routine-category-${option.typeId}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppVisual(
                  id: recordTypeVisualId(option.typeId),
                  size: 24,
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: AppInkWell(
              key: fieldKey,
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: _ValueField(value: value),
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: '종료일 제거',
            onPressed: onClear,
            icon: const AppIcon(Icons.close_rounded, size: 18),
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

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

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
  _ => recordTypeLabel(typeId) == typeId ? '기존 카테고리' : recordTypeLabel(typeId),
};

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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
  );
}
