import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';
import '../../widgets/record_inputs/record_inputs.dart';

class ExpenseAddScreen extends ConsumerStatefulWidget {
  const ExpenseAddScreen({super.key});

  @override
  ConsumerState<ExpenseAddScreen> createState() => _ExpenseAddScreenState();
}

class _ExpenseAddScreenState extends ConsumerState<ExpenseAddScreen> {
  final _amountCtrl = TextEditingController();
  final _itemNameCtrl = TextEditingController();
  final _purchaseUrlCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  String _currency = 'KRW';
  String? _category;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _itemNameCtrl.dispose();
    _purchaseUrlCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => (_amount ?? 0) > 0 && _category != null;

  double? get _amount => double.tryParse(_amountCtrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final activePet = ref.watch(petProvider).activePet;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(title: '비용 추가', onBack: _goBack),
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
                                key: const Key('expense-date-button'),
                                text: DateFormat('yyyy-MM-dd').format(_date),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InputBox(
                                key: const Key('expense-time-button'),
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
                  _SectionBlock(
                    title: '금액',
                    child: Row(
                      children: [
                        Expanded(
                          child: RecordNumberInput(
                            key: const Key('expense-amount-input'),
                            controller: _amountCtrl,
                            mode: RecordNumberInputMode.integer,
                            hintText: '0',
                            suffixText: '원',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CurrencyChip(
                          value: _currency,
                          onTap: () => setState(() => _currency = 'KRW'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '카테고리',
                    child: _CategoryGrid(
                      selectedValue: _category,
                      onSelected: (value) => setState(() => _category = value),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '반려동물',
                    child: activePet == null
                        ? const _InfoPanel(text: '반려동물을 등록해 주세요.')
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: _PetChip(label: activePet.name),
                          ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '기본 정보',
                    child: Column(
                      children: [
                        _LabeledRow(
                          label: '제품이름',
                          child: _TextInput(
                            key: const Key('expense-item-name-field'),
                            controller: _itemNameCtrl,
                            hintText: '선택',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LabeledRow(
                          label: '구매처 URL',
                          child: _TextInput(
                            key: const Key('expense-purchase-url-field'),
                            controller: _purchaseUrlCtrl,
                            hintText: '선택',
                            keyboardType: TextInputType.url,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _StaticAction(label: '+ 항목 추가'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionBlock(
                    title: '사진',
                    child: _StaticAction(label: '+ 사진'),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '메모',
                    child: _TextInput(
                      key: const Key('expense-memo-field'),
                      controller: _memoCtrl,
                      hintText: '선택',
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SaveButton(canSave: _canSave, onTap: _showPreparing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    });
  }

  void _showPreparing() {
    FocusScope.of(context).unfocus();
    showPreparingToast(context);
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
    context.go('/wallet');
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

class _CurrencyChip extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _CurrencyChip({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          width: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: AppText(
            value,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const _CategoryGrid({required this.selectedValue, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _expenseCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final option = _expenseCategories[index];
        return _CategoryCard(
          key: Key('expense-category-${option.value}'),
          option: option,
          selected: selectedValue == option.value,
          onTap: () => onSelected(option.value),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _ExpenseCategory option;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.text : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.text : AppColors.border,
            ),
          ),
          child: AppText(
            option.label,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.white : AppColors.text,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  final String label;

  const _PetChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        label,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
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
          width: 92,
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
  final TextInputType? keyboardType;

  const _TextInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
          borderSide: const BorderSide(color: AppColors.text),
        ),
      ),
    );
  }
}

class _StaticAction extends StatelessWidget {
  final String label;

  const _StaticAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        label,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool canSave;
  final VoidCallback onTap;

  const _SaveButton({required this.canSave, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('expense-save-button'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: canSave ? AppColors.text : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canSave ? AppColors.text : AppColors.border,
            ),
          ),
          child: AppText(
            '비용 저장',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: canSave ? AppColors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _ExpenseCategory {
  final String value;
  final String label;

  const _ExpenseCategory(this.value, this.label);
}

const _expenseCategories = [
  _ExpenseCategory('food', '사료'),
  _ExpenseCategory('snack', '간식'),
  _ExpenseCategory('hospital', '병원'),
  _ExpenseCategory('medicine', '약'),
  _ExpenseCategory('grooming', '미용'),
  _ExpenseCategory('supplies', '용품'),
];
