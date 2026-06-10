import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../widgets/app_text.dart';
import '../../widgets/record_inputs/record_inputs.dart';
import 'expense_record_utils.dart';

enum ExpenseFormMode { add, edit }

class ExpenseFormData {
  final DateTime date;
  final TimeOfDay time;
  final int amount;
  final String category;
  final String itemName;
  final String note;

  const ExpenseFormData({
    required this.date,
    required this.time,
    required this.amount,
    required this.category,
    required this.itemName,
    required this.note,
  });

  factory ExpenseFormData.now() {
    final now = DateTime.now();
    return ExpenseFormData(
      date: DateTime(now.year, now.month, now.day),
      time: TimeOfDay(hour: now.hour, minute: now.minute),
      amount: 0,
      category: '',
      itemName: '',
      note: '',
    );
  }

  factory ExpenseFormData.fromRecord(ActivityRecord record) {
    final parsedDate = DateTime.tryParse(record.date);
    final date = parsedDate == null
        ? DateTime.now()
        : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final normalizedTime = normalizeExpenseTime(record.time);
    final timeParts = normalizedTime.split(':');
    final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) : null;
    final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) : null;
    final now = TimeOfDay.now();

    return ExpenseFormData(
      date: date,
      time: hour == null || minute == null
          ? TimeOfDay(hour: now.hour, minute: now.minute)
          : TimeOfDay(hour: hour, minute: minute),
      amount: expenseAmount(record) ?? 0,
      category: record.detail['category']?.toString().trim() ?? '',
      itemName: record.detail['itemName']?.toString().trim() ?? '',
      note: record.note?.trim() ?? '',
    );
  }

  Map<String, dynamic> toRecordBody() {
    final body = <String, dynamic>{
      'typeId': 'expense',
      'date': DateFormat('yyyy-MM-dd').format(date),
      'time':
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}',
      'detail': <String, dynamic>{
        'amount': amount,
        'currency': 'KRW',
        'category': category,
      },
    };

    final trimmedItemName = itemName.trim();
    if (trimmedItemName.isNotEmpty) {
      (body['detail'] as Map<String, dynamic>)['itemName'] = trimmedItemName;
    }

    final trimmedNote = note.trim();
    if (trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote;
    }

    return body;
  }
}

class ExpenseFormBody extends StatefulWidget {
  final ExpenseFormMode mode;
  final ExpenseFormData initialData;
  final String? petName;
  final bool submitting;
  final String? errorText;
  final ValueChanged<ExpenseFormData> onSubmit;

  const ExpenseFormBody({
    super.key,
    required this.mode,
    required this.initialData,
    required this.petName,
    required this.submitting,
    required this.errorText,
    required this.onSubmit,
  });

  @override
  State<ExpenseFormBody> createState() => _ExpenseFormBodyState();
}

class _ExpenseFormBodyState extends State<ExpenseFormBody> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _itemNameCtrl;
  late final TextEditingController _memoCtrl;
  late DateTime _date;
  late TimeOfDay _time;
  late String? _category;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    _date = initial.date;
    _time = initial.time;
    _category = initial.category.isEmpty ? null : initial.category;
    _amountCtrl = TextEditingController(
      text: initial.amount > 0 ? initial.amount.toString() : '',
    );
    _itemNameCtrl = TextEditingController(text: initial.itemName);
    _memoCtrl = TextEditingController(text: initial.note);
  }

  @override
  void didUpdateWidget(covariant ExpenseFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData) {
      final initial = widget.initialData;
      _date = initial.date;
      _time = initial.time;
      _category = initial.category.isEmpty ? null : initial.category;
      _amountCtrl.text = initial.amount > 0 ? initial.amount.toString() : '';
      _itemNameCtrl.text = initial.itemName;
      _memoCtrl.text = initial.note;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _itemNameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountCtrl.text.trim());

  bool get _canSubmit =>
      !widget.submitting &&
      widget.petName != null &&
      (_amount ?? 0) > 0 &&
      _category != null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      text: _timeLabel,
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
              const _CurrencyChip(value: 'KRW'),
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
          child: widget.petName == null
              ? const _InfoPanel(text: '반려동물을 등록해 주세요')
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _PetChip(label: widget.petName!),
                ),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: '기본 정보',
          child: _LabeledRow(
            label: '항목명',
            child: _TextInput(
              key: const Key('expense-item-name-field'),
              controller: _itemNameCtrl,
              hintText: '선택',
            ),
          ),
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
        if (widget.errorText != null) ...[
          _InlineError(text: widget.errorText!),
          const SizedBox(height: 12),
        ],
        _SaveButton(
          label: widget.mode == ExpenseFormMode.add ? '비용 저장' : '수정 완료',
          canSave: _canSubmit,
          submitting: widget.submitting,
          onTap: _canSubmit ? _submit : null,
        ),
      ],
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

  void _submit() {
    final amount = _amount;
    final category = _category;
    if (amount == null || amount <= 0 || category == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onSubmit(
      ExpenseFormData(
        date: _date,
        time: _time,
        amount: amount,
        category: category,
        itemName: _itemNameCtrl.text.trim(),
        note: _memoCtrl.text.trim(),
      ),
    );
  }

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';
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

  const _CurrencyChip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        value,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
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
      itemCount: expenseCategoryOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final option = expenseCategoryOptions[index];
        return _CategoryCard(
          key: Key('expense-category-${option.key}'),
          option: option,
          selected: selectedValue == option.key,
          onTap: () => onSelected(option.key),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ExpenseCategoryOption option;
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

  const _TextInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
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

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('expense-form-error'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: AppText(
        text,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFB91C1C),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool canSave;
  final bool submitting;
  final VoidCallback? onTap;

  const _SaveButton({
    required this.label,
    required this.canSave,
    required this.submitting,
    required this.onTap,
  });

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
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : AppText(
                  label,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: canSave ? AppColors.white : AppColors.muted,
                ),
        ),
      ),
    );
  }
}
