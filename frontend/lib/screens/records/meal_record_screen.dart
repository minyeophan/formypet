import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/record_inputs/record_inputs.dart';
import 'record_support.dart';

typedef MealImagePicker = Future<XFile?> Function();

class MealRecordScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final MealImagePicker? pickImageForTest;
  final ActivityRecord? editingRecord;

  const MealRecordScreen({
    super.key,
    this.initialDate,
    this.pickImageForTest,
    this.editingRecord,
  });

  @override
  ConsumerState<MealRecordScreen> createState() => _MealRecordScreenState();
}

class _MealRecordScreenState extends ConsumerState<MealRecordScreen> {
  final _productCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  String? _foodType;
  int? _consumedPercent;
  String? _feedingMethod;
  bool _showMore = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final editingRecord = widget.editingRecord;
    final initialDate = editingRecord == null
        ? (widget.initialDate ?? now)
        : (DateTime.tryParse(editingRecord.date) ?? now);
    _date = DateTime(initialDate.year, initialDate.month, initialDate.day);
    _time = editingRecord == null
        ? TimeOfDay(hour: now.hour, minute: now.minute)
        : _timeOfDayFrom(editingRecord.time) ??
              TimeOfDay(hour: now.hour, minute: now.minute);
    if (editingRecord != null) {
      _initializeFromRecord(editingRecord);
    }
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
      !_isDeleting &&
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
            AppFormHeader(
              title: widget.editingRecord == null ? '급식 기록' : '급식 수정',
              onBack: _goBack,
            ),
            Expanded(
              child: RecordFormScrollBody(
                submitButton: widget.editingRecord == null
                    ? RecordFormSubmitButton(
                        key: const Key('meal-save-button'),
                        enabled: _canSave,
                        isSaving: _isSaving,
                        onPressed: _save,
                      )
                    : RecordEditActionBar(
                        enabled: _canSave,
                        isSaving: _isSaving,
                        isDeleting: _isDeleting,
                        onSave: _save,
                        onDelete: _delete,
                      ),
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
                                key: const Key('meal-date-label'),
                                text: DateFormat('yyyy-MM-dd').format(_date),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InputBox(
                                key: const Key('meal-time-button'),
                                text: _apiTime,
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SubtleButton(
                          key: const Key('meal-set-now-button'),
                          label: '현재 시간으로 설정',
                          onTap: _setNow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '사료 종류',
                    child: _FoodTypeGrid(
                      selectedValue: _foodType,
                      onSelected: (value) => setState(() {
                        _foodType = value;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '상세 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LabeledRow(
                          label: '사료명',
                          child: _TextInput(
                            key: const Key('meal-product-field'),
                            controller: _productCtrl,
                            hintText: '20자 이내',
                            maxLength: 20,
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LabeledRow(
                          label: '급여량',
                          child: RecordNumberInput(
                            key: const Key('meal-served-amount-field'),
                            controller: _amountCtrl,
                            mode: RecordNumberInputMode.integer,
                            hintText: '0',
                            suffixText: 'g',
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LabeledRow(
                          label: '섭취율',
                          child: _ConsumeGrid(
                            selectedValue: _consumedPercent,
                            onSelected: (value) => setState(() {
                              _consumedPercent = value;
                              _error = null;
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LabeledRow(
                          label: '메모',
                          child: _TextInput(
                            key: const Key('meal-note-field'),
                            controller: _noteCtrl,
                            hintText: '선택',
                            maxLines: 3,
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _MoreSection(
                    expanded: _showMore,
                    onToggle: () => setState(() => _showMore = !_showMore),
                    brandController: _brandCtrl,
                    feedingMethod: _feedingMethod,
                    onBrandChanged: (_) => setState(() => _error = null),
                    onFeedingMethodChanged: (value) => setState(() {
                      _feedingMethod = value;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 18),
                  if (widget.editingRecord == null)
                    _PhotoButton(
                      label: _photo == null
                          ? '사진 추가 (0/1)'
                          : '사진 추가 (1/1) · ${_filenameFor(_photo!)}',
                      hasPhoto: _photo != null,
                      onTap: _pickPhoto,
                    )
                  else
                    _ExistingMealPhotos(record: widget.editingRecord!),
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

  Future<void> _pickTime() async {
    final picked = await showRecordTimePickerSheet(context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _setNow() {
    final now = DateTime.now();
    setState(() {
      _time = TimeOfDay(hour: now.hour, minute: now.minute);
      _error = null;
    });
  }

  Future<void> _pickPhoto() async {
    final pickImage =
        widget.pickImageForTest ??
        () => ImagePicker().pickImage(source: ImageSource.gallery);
    final photo = await pickImage();
    if (photo != null) {
      setState(() {
        _photo = photo;
        _error = null;
      });
    }
  }

  void _initializeFromRecord(ActivityRecord record) {
    final detail = record.detail;
    _foodType = detail['foodType']?.toString();
    _consumedPercent = int.tryParse('${detail['consumedPercent']}');
    _feedingMethod = detail['feedingMethod']?.toString();
    _productCtrl.text = detail['product']?.toString() ?? '';
    _amountCtrl.text = detail['servedAmount'] == null
        ? ''
        : numberLabel(detail['servedAmount']);
    _brandCtrl.text = detail['brand']?.toString() ?? '';
    _noteCtrl.text = record.note ?? '';
    _showMore = _brandCtrl.text.trim().isNotEmpty || _feedingMethod != null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final body = _buildPayload();
      final editingRecord = widget.editingRecord;
      if (editingRecord == null) {
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
      } else {
        await ref
            .read(petProvider.notifier)
            .updateRecord(editingRecord.id, body);
      }
      if (!mounted) return;
      context.go('/records?date=${DateFormat('yyyy-MM-dd').format(_date)}');
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

  Future<void> _delete() async {
    final record = widget.editingRecord;
    if (record == null || _isSaving || _isDeleting) return;
    final confirmed = await showRecordDeleteConfirmationSheet(context);
    if (confirmed != true || !mounted) return;
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await ref.read(petProvider.notifier).deleteRecord(record.id);
      if (!mounted) return;
      context.go('/records?date=${record.date}');
    } catch (_) {
      if (mounted) {
        setState(() => _error = '삭제에 실패했어요. 잠시 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
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
  final VoidCallback? onTap;

  const _InputBox({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: content,
      );
    }

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _SubtleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SubtleButton({super.key, required this.label, required this.onTap});

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

class _FoodTypeGrid extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const _FoodTypeGrid({required this.selectedValue, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _foodTypeOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final option = _foodTypeOptions[index];
        return _VisualOptionCard(
          key: Key('meal-food-type-${option.value}'),
          visualId: option.visualId!,
          label: option.label,
          selected: selectedValue == option.value,
          onTap: () => onSelected(option.value),
        );
      },
    );
  }
}

class _ConsumeGrid extends StatelessWidget {
  final int? selectedValue;
  final ValueChanged<int> onSelected;

  const _ConsumeGrid({required this.selectedValue, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _consumeOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final option = _consumeOptions[index];
        return _VisualOptionCard(
          key: Key('meal-consumed-${option.value}'),
          visualId: option.visualId,
          label: '${option.value}%',
          selected: selectedValue == option.value,
          onTap: () => onSelected(option.value),
        );
      },
    );
  }
}

class _VisualOptionCard extends StatelessWidget {
  final AppVisualId visualId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisualOptionCard({
    super.key,
    required this.visualId,
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppVisual(id: visualId, size: 24),
              const SizedBox(height: 6),
              AppText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _TextInput({
    Key? key,
    required this.controller,
    required this.hintText,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  }) : fieldKey = key,
       super(key: null);

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLength: maxLength,
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
        counterText: '',
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

class _MoreSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController brandController;
  final String? feedingMethod;
  final ValueChanged<String> onBrandChanged;
  final ValueChanged<String> onFeedingMethodChanged;

  const _MoreSection({
    required this.expanded,
    required this.onToggle,
    required this.brandController,
    required this.feedingMethod,
    required this.onBrandChanged,
    required this.onFeedingMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('meal-more-toggle'),
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    expanded ? '추가 정보 (브랜드/급식방법) 접기' : '추가 정보 (브랜드/급식방법) 펼치기',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (!expanded)
          const AppText(
            '브랜드와 급식 방법은 필요할 때만 입력해요.',
            fontSize: 12,
            color: AppColors.muted,
          )
        else ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _selectedFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary),
              ),
              child: const AppText(
                '선택 입력',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPressed,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '브랜드명',
            child: _TextInput(
              key: const Key('meal-brand-field'),
              controller: brandController,
              hintText: '선택',
              onChanged: onBrandChanged,
            ),
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: '급식 방법',
            child: Row(
              children: [
                for (final option in _feedingMethodOptions) ...[
                  Expanded(
                    child: _SegmentButton(
                      key: Key('meal-feeding-method-${option.value}'),
                      label: option.label,
                      selected: feedingMethod == option.value,
                      onTap: () => onFeedingMethodChanged(option.value),
                    ),
                  ),
                  if (option != _feedingMethodOptions.last)
                    const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ],
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
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.primaryPressed : AppColors.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    final content = Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasPhoto ? _selectedFill : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasPhoto ? Border.all(color: AppColors.primary) : null,
      ),
      child: Row(
        children: [
          Icon(
            hasPhoto ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
            color: hasPhoto ? AppColors.primaryPressed : AppColors.muted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              label,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('meal-photo-button'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: hasPhoto
            ? content
            : CustomPaint(
                painter: _DashedBorderPainter(
                  color: AppColors.border,
                  radius: 16,
                ),
                child: content,
              ),
      ),
    );
  }
}

class _ExistingMealPhotos extends StatelessWidget {
  final ActivityRecord record;

  const _ExistingMealPhotos({required this.record});

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      title: '사진',
      child: record.mediaUrls.isEmpty
          ? const _ReadOnlyPhotoPanel(text: '등록된 사진이 없어요')
          : SizedBox(
              key: const Key('meal-existing-photos'),
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final url = record.mediaUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AuthenticatedNetworkImage(
                      url: url,
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                      fallback: const _ReadOnlyPhotoPanel(width: 108),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemCount: record.mediaUrls.length,
              ),
            ),
    );
  }
}

class _ReadOnlyPhotoPanel extends StatelessWidget {
  final String text;
  final double? width;

  const _ReadOnlyPhotoPanel({this.text = '사진을 불러오는 중이에요', this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 108,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        text,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.muted,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + 7;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _StringOption {
  final String value;
  final String label;
  final AppVisualId? visualId;

  const _StringOption(this.value, this.label, [this.visualId]);
}

class _IntOption {
  final int value;
  final AppVisualId visualId;

  const _IntOption(this.value, this.visualId);
}

const _selectedFill = Color(0xFFFFF7EF);

const _foodTypeOptions = [
  _StringOption('wet', '습식', AppVisualId.mealWet),
  _StringOption('dry', '건식', AppVisualId.mealDry),
  _StringOption('snack', '간식', AppVisualId.mealSnack),
  _StringOption('prescription', '처방식', AppVisualId.mealPrescription),
  _StringOption('raw', '생식', AppVisualId.mealRaw),
  _StringOption('freezeDried', '동결건조', AppVisualId.mealFreezeDried),
];

const _consumeOptions = [
  _IntOption(25, AppVisualId.mealConsumed25),
  _IntOption(50, AppVisualId.mealConsumed50),
  _IntOption(75, AppVisualId.mealConsumed75),
  _IntOption(100, AppVisualId.mealConsumed100),
];

const _feedingMethodOptions = [
  _StringOption('served', '배식'),
  _StringOption('freeFeed', '자율급식'),
  _StringOption('autoFeeder', '자동급식기'),
];

TimeOfDay? _timeOfDayFrom(String? raw) {
  final normalized = recordTimeLabel(raw);
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(normalized);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
