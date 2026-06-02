import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/record_inputs/record_inputs.dart';

class RecordCategoryFormScreen extends ConsumerStatefulWidget {
  final String typeId;

  const RecordCategoryFormScreen({super.key, required this.typeId});

  @override
  ConsumerState<RecordCategoryFormScreen> createState() =>
      _RecordCategoryFormScreenState();
}

class _RecordCategoryFormScreenState
    extends ConsumerState<RecordCategoryFormScreen> {
  final _distanceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _waterAmountCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _vetClinicCtrl = TextEditingController();
  final _vetReasonCtrl = TextEditingController();
  final _vetTreatmentCtrl = TextEditingController();
  final _medicineNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  String _poopKind = 'stool';
  String? _poopShape;
  String? _poopColor;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _noteCtrl.dispose();
    _waterAmountCtrl.dispose();
    _weightCtrl.dispose();
    _vetClinicCtrl.dispose();
    _vetReasonCtrl.dispose();
    _vetTreatmentCtrl.dispose();
    _medicineNameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_isSaving) return false;
    switch (widget.typeId) {
      case 'poop':
        return _poopKind == 'urine'
            ? _poopColor != null
            : _poopShape != null && _poopColor != null;
      case 'water':
        return _positiveDouble(_waterAmountCtrl.text) != null;
      case 'walk':
        return _positiveDouble(_distanceCtrl.text) != null;
      case 'weight':
        return _positiveDouble(_weightCtrl.text) != null;
      case 'vet':
        return _vetClinicCtrl.text.trim().isNotEmpty &&
            _vetReasonCtrl.text.trim().isNotEmpty &&
            _vetTreatmentCtrl.text.trim().isNotEmpty;
      case 'medicine':
        return _medicineNameCtrl.text.trim().isNotEmpty &&
            _dosageCtrl.text.trim().isNotEmpty;
      case 'diary':
        return _noteCtrl.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _categoryConfig(widget.typeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(
              title: '${config.label} 기록',
              onBack: _goBack,
              trailing: TextButton(
                key: const Key('category-save-button'),
                onPressed: _canSave ? _save : null,
                child: AppText(
                  _isSaving ? '저장 중' : '등록',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _canSave ? AppColors.primaryPressed : AppColors.muted,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  _SectionBlock(
                    title: '날짜/시간',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _InputBox(
                                key: const Key('category-date-button'),
                                text: DateFormat('yyyy-MM-dd').format(_date),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InputBox(
                                key: const Key('category-time-button'),
                                text: _apiTime,
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SubtleButton(label: '현재 시간으로 설정', onTap: _setNow),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildTypeBody(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppText(
                      _error!,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE35D5D),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBody() {
    switch (widget.typeId) {
      case 'poop':
        return _buildPoopBody();
      case 'water':
        return _buildWaterBody();
      case 'walk':
        return _buildWalkBody();
      case 'weight':
        return _buildWeightBody();
      case 'vet':
        return _buildVetBody();
      case 'medicine':
        return _buildMedicineBody();
      case 'diary':
        return _buildDiaryBody();
      default:
        return const _SectionBlock(
          title: '준비중',
          child: AppText('아직 지원하지 않는 기록이에요.', color: AppColors.textSecondary),
        );
    }
  }

  Widget _buildPoopBody() {
    final colorOptions = _poopKind == 'urine'
        ? _urineColorOptions
        : _stoolColorOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionBlock(
          title: '종류',
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  key: const Key('category-poop-kind-stool'),
                  label: '대변',
                  selected: _poopKind == 'stool',
                  onTap: () => setState(() {
                    _poopKind = 'stool';
                    _poopShape = null;
                    _poopColor = null;
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentButton(
                  key: const Key('category-poop-kind-urine'),
                  label: '소변',
                  selected: _poopKind == 'urine',
                  onTap: () => setState(() {
                    _poopKind = 'urine';
                    _poopShape = null;
                    _poopColor = null;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
        ),
        if (_poopKind == 'stool') ...[
          const SizedBox(height: 22),
          _SectionBlock(
            title: '변 상태',
            child: _OptionGrid(
              options: _poopShapeOptions,
              selectedValue: _poopShape,
              onSelected: (value) => setState(() {
                _poopShape = value;
                _error = null;
              }),
              keyPrefix: 'category-poop-shape',
            ),
          ),
        ],
        const SizedBox(height: 22),
        _SectionBlock(
          title: '색상',
          child: _OptionGrid(
            options: colorOptions,
            selectedValue: _poopColor,
            onSelected: (value) => setState(() {
              _poopColor = value;
              _error = null;
            }),
            keyPrefix: 'category-poop-color',
          ),
        ),
        if (_showPoopWarning) ...[
          const SizedBox(height: 12),
          const _WarningBox(message: '평소와 다르면 수의사 상담을 권장해요.'),
        ],
        const SizedBox(height: 22),
        _SectionBlock(
          title: '메모',
          child: _TextInput(
            key: const Key('category-note-field'),
            controller: _noteCtrl,
            hintText: '선택',
            maxLines: 3,
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterBody() {
    return _SectionBlock(
      title: '음수 정보',
      child: _LabeledRow(
        label: '음수량',
        child: RecordNumberInput(
          key: const Key('category-water-amount-field'),
          controller: _waterAmountCtrl,
          mode: RecordNumberInputMode.decimal,
          hintText: '0',
          maxDecimalPlaces: 1,
          suffixText: 'ml',
          onChanged: (_) => setState(() => _error = null),
        ),
      ),
    );
  }

  Widget _buildWalkBody() {
    return _SectionBlock(
      title: '산책 정보',
      child: Column(
        children: [
          _LabeledRow(
            label: '거리',
            child: RecordNumberInput(
              key: const Key('category-distance-field'),
              controller: _distanceCtrl,
              mode: RecordNumberInputMode.decimal,
              hintText: '0.0',
              maxDecimalPlaces: 2,
              suffixText: 'km',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '산책 메모',
            child: _TextInput(
              key: const Key('category-note-field'),
              controller: _noteCtrl,
              hintText: '선택',
              maxLines: 3,
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightBody() {
    final records =
        ref
            .watch(petProvider)
            .records
            .where((record) => record.typeId == 'weight')
            .where((record) => _weightValue(record) != null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final latest = records.isEmpty ? null : records.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionBlock(
          title: '몸무게 정보',
          child: _LabeledRow(
            label: '몸무게',
            child: RecordNumberInput(
              key: const Key('category-weight-field'),
              controller: _weightCtrl,
              mode: RecordNumberInputMode.decimal,
              hintText: '0.0',
              maxDecimalPlaces: 2,
              suffixText: 'kg',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: '최근 기록',
          child: _InfoPanel(
            text: latest == null
                ? '아직 몸무게 기록이 없어요.'
                : '${latest.date} · ${_numberLabel(_weightValue(latest)!)}kg',
          ),
        ),
      ],
    );
  }

  Widget _buildVetBody() {
    return _SectionBlock(
      title: '병원 정보',
      child: Column(
        children: [
          _LabeledRow(
            label: '병원명',
            child: _TextInput(
              key: const Key('category-vet-clinic-field'),
              controller: _vetClinicCtrl,
              hintText: '병원 이름',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '방문 사유',
            child: _TextInput(
              key: const Key('category-vet-reason-field'),
              controller: _vetReasonCtrl,
              hintText: '예: 정기 검진',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '진료/처방 메모',
            child: _TextInput(
              key: const Key('category-vet-treatment-field'),
              controller: _vetTreatmentCtrl,
              hintText: '진료 내용',
              maxLines: 3,
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineBody() {
    return _SectionBlock(
      title: '영양/약 정보',
      child: Column(
        children: [
          _LabeledRow(
            label: '이름',
            child: _TextInput(
              key: const Key('category-medicine-name-field'),
              controller: _medicineNameCtrl,
              hintText: '영양제 또는 약 이름',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '용량',
            child: _TextInput(
              key: const Key('category-dosage-field'),
              controller: _dosageCtrl,
              hintText: '예: 1정',
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryBody() {
    return _SectionBlock(
      title: '메모',
      child: _TextInput(
        key: const Key('category-diary-note-field'),
        controller: _noteCtrl,
        hintText: '오늘의 반려일기를 남겨 주세요',
        maxLines: 8,
        onChanged: (_) => setState(() => _error = null),
      ),
    );
  }

  bool get _showPoopWarning {
    if (_poopKind == 'stool') {
      return _poopShape == 'loose' ||
          _poopShape == 'diarrhea' ||
          {'red', 'black', 'green', 'other'}.contains(_poopColor);
    }
    return {'darkYellow', 'red', 'brown'}.contains(_poopColor);
  }

  Future<void> _pickDate() async {
    final picked = await showRecordDatePickerSheet(context, initialDate: _date);
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showRecordTimePickerSheet(context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _setNow() {
    final now = DateTime.now();
    setState(() {
      _date = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay(hour: now.hour, minute: now.minute);
      _error = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(petProvider.notifier).addRecord(_buildPayload());
      if (!mounted) return;
      context.go('/records');
    } catch (_) {
      if (mounted) {
        setState(() => _error = '저장에 실패했어요. 잠시 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      'typeId': widget.typeId,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'time': _apiTime,
    };

    switch (widget.typeId) {
      case 'poop':
        final note = _noteCtrl.text.trim();
        if (note.isNotEmpty) payload['note'] = note;
        payload['typeId'] = 'poop';
        payload['detail'] = {
          'poopShape': _poopKind == 'urine' ? 'urine' : _poopShape,
          'poopColor': _poopColor,
        };
        break;
      case 'water':
        payload['detail'] = {'amount': _positiveDouble(_waterAmountCtrl.text)};
        break;
      case 'walk':
        final note = _noteCtrl.text.trim();
        if (note.isNotEmpty) payload['note'] = note;
        payload['detail'] = {'distance': _positiveDouble(_distanceCtrl.text)};
        break;
      case 'weight':
        payload['detail'] = {'weight': _positiveDouble(_weightCtrl.text)};
        break;
      case 'vet':
        payload['detail'] = {
          'vetClinicName': _vetClinicCtrl.text.trim(),
          'vetVisitReason': _vetReasonCtrl.text.trim(),
          'vetTreatment': _vetTreatmentCtrl.text.trim(),
        };
        break;
      case 'medicine':
        payload['detail'] = {
          'medicineName': _medicineNameCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim(),
        };
        break;
      case 'diary':
        payload['note'] = _noteCtrl.text.trim();
        break;
    }

    return payload;
  }

  String get _apiTime =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/records');
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _InputBox extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _InputBox({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: AppText(
            text,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _SubtleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SubtleButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              label,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _TextInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final List<_Option> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  const _OptionGrid({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        return _OptionCard(
          key: Key('$keyPrefix-${option.value}'),
          label: option.label,
          selected: selectedValue == option.value,
          onTap: () => onSelected(option.value),
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selectedFill : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selectedFill : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.primaryPressed : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String message;

  const _WarningBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD3D3)),
      ),
      child: AppText(
        message,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFE35D5D),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String text;

  const _InfoPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        text,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _CategoryConfig {
  final String id;
  final String label;

  const _CategoryConfig({required this.id, required this.label});
}

class _Option {
  final String value;
  final String label;

  const _Option(this.value, this.label);
}

const _selectedFill = Color(0xFFFFF7EF);

const _poopShapeOptions = [
  _Option('normal', '보통 변'),
  _Option('loose', '묽은 변'),
  _Option('diarrhea', '설사'),
];

const _stoolColorOptions = [
  _Option('brown', '갈색'),
  _Option('lightBrown', '연갈색'),
  _Option('red', '붉은색'),
  _Option('black', '검은색'),
  _Option('green', '녹색'),
  _Option('other', '기타'),
];

const _urineColorOptions = [
  _Option('clear', '투명'),
  _Option('lightYellow', '연노랑'),
  _Option('yellow', '노랑'),
  _Option('darkYellow', '진노랑'),
  _Option('red', '붉은색'),
  _Option('brown', '갈색'),
];

_CategoryConfig _categoryConfig(String typeId) {
  const configs = {
    'poop': _CategoryConfig(id: 'poop', label: '배변'),
    'water': _CategoryConfig(id: 'water', label: '음수'),
    'walk': _CategoryConfig(id: 'walk', label: '산책'),
    'weight': _CategoryConfig(id: 'weight', label: '몸무게'),
    'vet': _CategoryConfig(id: 'vet', label: '병원'),
    'medicine': _CategoryConfig(id: 'medicine', label: '영양/약'),
    'diary': _CategoryConfig(id: 'diary', label: '일기'),
  };
  return configs[typeId] ?? _CategoryConfig(id: typeId, label: typeId);
}

double? _positiveDouble(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

double? _weightValue(ActivityRecord record) {
  final value = record.detail['weight'] ?? record.detail['value'];
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String _numberLabel(double value) {
  final rounded = value.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}
