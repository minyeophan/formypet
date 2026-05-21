import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_text.dart';

class MealRecordScreen extends ConsumerStatefulWidget {
  const MealRecordScreen({super.key});

  @override
  ConsumerState<MealRecordScreen> createState() => _MealRecordScreenState();
}

class _MealRecordScreenState extends ConsumerState<MealRecordScreen> {
  final _productCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  late DateTime _date;
  late TimeOfDay _time;
  String? _foodType;
  int? _consumedPercent;
  String? _feedingMethod;
  bool _showMore = false;
  bool _isSaving = false;
  String? _error;
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _amountCtrl.dispose();
    _brandCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_isSaving &&
      _foodType != null &&
      _consumedPercent != null &&
      (_servedAmount ?? 0) > 0;

  int? get _servedAmount => int.tryParse(_amountCtrl.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              canSave: _canSave,
              isSaving: _isSaving,
              onBack: _goBack,
              onSave: _canSave ? _save : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _SectionCard(
                    title: '날짜/시간',
                    child: Row(
                      children: [
                        Expanded(
                          child: _PickerButton(
                            key: const Key('meal-date-button'),
                            icon: Icons.calendar_today_rounded,
                            label: DateFormat('yyyy.MM.dd').format(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PickerButton(
                            key: const Key('meal-time-button'),
                            icon: Icons.access_time_rounded,
                            label: _apiTime,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '사료 종류',
                    child: _OptionWrap(
                      children: [
                        for (final option in _foodTypeOptions)
                          _ChoicePill(
                            key: Key('meal-food-type-${option.value}'),
                            label: option.label,
                            selected: _foodType == option.value,
                            onTap: () => setState(() {
                              _foodType = option.value;
                              _error = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '상세 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LabeledField(
                          key: const Key('meal-product-field'),
                          controller: _productCtrl,
                          label: '음식 이름',
                          hintText: '20자 이내',
                          maxLength: 20,
                          onChanged: (_) => setState(() => _error = null),
                        ),
                        const SizedBox(height: 12),
                        _LabeledField(
                          key: const Key('meal-served-amount-field'),
                          controller: _amountCtrl,
                          label: '급여량',
                          hintText: 'g',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          suffixText: 'g',
                          onChanged: (_) => setState(() => _error = null),
                        ),
                        const SizedBox(height: 14),
                        const AppText(
                          '섭취율',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        const SizedBox(height: 8),
                        _OptionWrap(
                          children: [
                            for (final option in _consumeOptions)
                              _ChoicePill(
                                key: Key('meal-consumed-${option.value}'),
                                label: option.label,
                                selected: _consumedPercent == option.value,
                                onTap: () => setState(() {
                                  _consumedPercent = option.value;
                                  _error = null;
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '추가 정보',
                    trailing: Icon(
                      _showMore
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTapHeader: () => setState(() => _showMore = !_showMore),
                    headerKey: const Key('meal-more-toggle'),
                    child: _showMore
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LabeledField(
                                key: const Key('meal-brand-field'),
                                controller: _brandCtrl,
                                label: '브랜드명',
                                hintText: '선택',
                                onChanged: (_) => setState(() => _error = null),
                              ),
                              const SizedBox(height: 14),
                              const AppText(
                                '급식 방법',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                              const SizedBox(height: 8),
                              _OptionWrap(
                                children: [
                                  for (final option in _feedingMethodOptions)
                                    _ChoicePill(
                                      key: Key(
                                        'meal-feeding-method-${option.value}',
                                      ),
                                      label: option.label,
                                      selected: _feedingMethod == option.value,
                                      onTap: () => setState(() {
                                        _feedingMethod = option.value;
                                        _error = null;
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _LabeledField(
                                key: const Key('meal-note-field'),
                                controller: _noteCtrl,
                                label: '메모',
                                hintText: '선택',
                                maxLines: 3,
                                onChanged: (_) => setState(() => _error = null),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  _PhotoButton(
                    label: '사진 추가 (${_photo == null ? 0 : 1}/1)',
                    hasPhoto: _photo != null,
                    onTap: _pickPhoto,
                  ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _photo = photo;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final body = _buildPayload();
      final photo = _photo;
      await ref
          .read(petProvider.notifier)
          .addRecord(
            body,
            photo: photo == null
                ? null
                : RecordPhotoUpload(
                    bytes: await photo.readAsBytes(),
                    filename: _filenameFor(photo),
                  ),
          );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/records');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '저장에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    final detail = <String, dynamic>{
      'foodType': _foodType,
      'servedAmount': _servedAmount,
      'consumedPercent': _consumedPercent,
    };
    final product = _productCtrl.text.trim();
    final brand = _brandCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    if (product.isNotEmpty) detail['product'] = product;
    if (brand.isNotEmpty) detail['brand'] = brand;
    if (_feedingMethod != null) detail['feedingMethod'] = _feedingMethod;

    return {
      'typeId': 'meal',
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'time': _apiTime,
      if (note.isNotEmpty) 'note': note,
      'detail': detail,
    };
  }

  String get _apiTime =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  String _filenameFor(XFile file) {
    if (file.name.isNotEmpty) return file.name;
    final normalized = file.path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final fromPath = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    return fromPath.isEmpty ? 'meal-photo.jpg' : fromPath;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/records');
  }
}

class _Header extends StatelessWidget {
  final bool canSave;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  const _Header({
    required this.canSave,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: TextButton(
              onPressed: onBack,
              child: const AppText(
                '뒤로',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
            child: AppText(
              '급식 기록',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 84,
            child: TextButton(
              key: const Key('meal-save-button'),
              onPressed: onSave,
              child: AppText(
                isSaving ? '저장 중' : '등록',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: canSave ? AppColors.primaryPressed : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTapHeader;
  final Key? headerKey;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.onTapHeader,
    this.headerKey,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: AppText(
            title,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        ?trailing,
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          onTapHeader == null
              ? header
              : InkWell(
                  key: headerKey,
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapHeader,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: header,
                  ),
                ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryPressed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  label,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  final List<Widget> children;

  const _OptionWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primaryPressed : AppColors.border,
            ),
          ),
          child: AppText(
            label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.suffixText,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffixText,
        counterText: '',
        filled: true,
        fillColor: AppColors.surfaceSoft,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final String label;
  final bool hasPhoto;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.label,
    required this.hasPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          key: const Key('meal-photo-button'),
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                hasPhoto
                    ? Icons.check_circle_rounded
                    : Icons.add_a_photo_rounded,
                color: hasPhoto ? AppColors.primaryPressed : AppColors.muted,
                size: 22,
              ),
              const SizedBox(width: 10),
              AppText(
                label,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StringOption {
  final String value;
  final String label;

  const _StringOption(this.value, this.label);
}

class _IntOption {
  final int value;
  final String label;

  const _IntOption(this.value, this.label);
}

const _foodTypeOptions = [
  _StringOption('wet', '습식'),
  _StringOption('dry', '건식'),
  _StringOption('snack', '간식'),
  _StringOption('prescription', '처방식'),
  _StringOption('raw', '생식'),
  _StringOption('freezeDried', '동결건조'),
];

const _consumeOptions = [
  _IntOption(25, '😭 25%'),
  _IntOption(50, '😐 50%'),
  _IntOption(75, '🙂 75%'),
  _IntOption(100, '🥰 100%'),
];

const _feedingMethodOptions = [
  _StringOption('served', '배식'),
  _StringOption('freeFeed', '자율급식'),
  _StringOption('autoFeeder', '자동급식기'),
];
