import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../widgets/app_visual.dart';
import '../../models/wallet_expense.dart';
import '../../widgets/app_text.dart';
import '../../widgets/record_inputs/record_inputs.dart';
import 'wallet_expense_utils.dart';
import 'wallet_budget_amount_input.dart';
import 'wallet_amount_layout.dart';

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

  factory ExpenseFormData.fromExpense(WalletExpense expense) {
    final parsedDate = DateTime.tryParse(expense.expenseDate);
    final date = parsedDate == null
        ? DateTime.now()
        : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final normalizedTime = normalizeExpenseTime(expense.expenseTime);
    final timeParts = normalizedTime.split(':');
    final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) : null;
    final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) : null;
    final now = TimeOfDay.now();

    return ExpenseFormData(
      date: date,
      time: hour == null || minute == null
          ? TimeOfDay(hour: now.hour, minute: now.minute)
          : TimeOfDay(hour: hour, minute: minute),
      amount: expense.amount,
      category: expense.category.trim(),
      itemName: expense.itemName?.trim() ?? '',
      note: expense.note?.trim() ?? '',
    );
  }

  Map<String, dynamic> toWalletExpenseBody({bool includeNulls = false}) {
    final trimmedItemName = itemName.trim();
    final trimmedNote = note.trim();
    final body = <String, dynamic>{
      'expenseDate': DateFormat('yyyy-MM-dd').format(date),
      'expenseTime':
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}',
      'amount': amount,
      'currency': 'KRW',
      'category': category,
    };

    if (includeNulls || trimmedItemName.isNotEmpty) {
      body['itemName'] = trimmedItemName.isEmpty ? null : trimmedItemName;
    }

    if (includeNulls || trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote.isEmpty ? null : trimmedNote;
    }

    return body;
  }
}

class ExpenseFormBody extends StatefulWidget {
  final ExpenseFormMode mode;
  final ExpenseFormData initialData;
  final String? petName;
  final Widget? petSelector;
  final bool? validTarget;
  final bool submitting;
  final String? errorText;
  final ValueChanged<ExpenseFormData> onSubmit;

  const ExpenseFormBody({
    super.key,
    required this.mode,
    required this.initialData,
    required this.petName,
    this.petSelector,
    this.validTarget,
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
      text: initial.amount > 0 ? formatWon(initial.amount) : '',
    );
    _itemNameCtrl = TextEditingController(text: initial.itemName);
    _memoCtrl = TextEditingController(text: initial.note);
  }

  @override
  void didUpdateWidget(covariant ExpenseFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new record gets a new widget key; parent progress/error rebuilds keep
    // the current draft even when they recreate the initial data object.
    if (oldWidget.mode != widget.mode) {
      final initial = widget.initialData;
      _date = initial.date;
      _time = initial.time;
      _category = initial.category.isEmpty ? null : initial.category;
      _amountCtrl.text = initial.amount > 0 ? formatWon(initial.amount) : '';
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

  int? get _amount => walletAmountValue(_amountCtrl.text);

  bool get _canSubmit =>
      !widget.submitting &&
      (widget.validTarget ?? (widget.petName != null)) &&
      (_amount ?? 0) > 0 &&
      (_amount ?? 0) <= walletMaxAmount &&
      expenseCategoryOptions.any((option) => option.key == _category) &&
      _itemNameCtrl.text.trim().length <= 100 &&
      _memoCtrl.text.trim().length <= 500;

  @override
  Widget build(BuildContext context) {
    return RecordFormScrollBody(
      padding: const EdgeInsets.all(20),
      submitButton: SafeArea(
        top: false,
        child: _SaveButton(
          label: widget.mode == ExpenseFormMode.add ? '지출 저장' : '수정 완료',
          canSave: _canSubmit,
          submitting: widget.submitting,
          onTap: _canSubmit ? _submit : null,
        ),
      ),
      children: [
        WalletAmountLayout(
          controller: _amountCtrl,
          illustrationWidth: 140,
          amountBuilder: (style) => _SectionBlock(
            title: '얼마를 썼나요?',
            child: TextField(
              key: const Key('expense-amount-input'),
              controller: _amountCtrl,
              readOnly: true,
              showCursor: false,
              enableInteractiveSelection: false,
              onTap: widget.submitting ? null : _pickAmount,
              style: style,
              decoration: const InputDecoration(
                filled: false,
                hintText: '0원',
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                focusedErrorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          illustration: SvgPicture.asset(
            'assets/illustrations/wallet_puppy_cheek.svg',
            width: 140,
            height: 112,
            fit: BoxFit.contain,
          ),
        ),
        if ((_amount ?? 0) > walletMaxAmount)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: AppText(
              '금액이 너무 커요. 1억 원 이하로 입력해 주세요.',
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        const SizedBox(height: 24),
        _SectionBlock(
          title: '반려동물',
          child:
              widget.petSelector ??
              (widget.petName == null
                  ? const _InfoPanel(text: '반려동물을 등록해 주세요')
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _PetChip(label: widget.petName!),
                    )),
        ),
        const SizedBox(height: 24),
        _SectionBlock(
          title: '카테고리',
          child: _CategoryGrid(
            selectedValue: _category,
            onSelected: (value) {
              if (!widget.submitting) setState(() => _category = value);
            },
          ),
        ),
        const SizedBox(height: 24),
        _SectionBlock(
          title: '날짜/시간',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              return Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: stacked
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: stacked ? 0 : 1,
                    fit: FlexFit.tight,
                    child: _InputBox(
                      key: const Key('expense-date-button'),
                      text: DateFormat('yyyy-MM-dd').format(_date),
                      onTap: _pickDate,
                    ),
                  ),
                  SizedBox(width: stacked ? 0 : 10, height: stacked ? 10 : 0),
                  Flexible(
                    flex: stacked ? 0 : 1,
                    fit: FlexFit.tight,
                    child: _InputBox(
                      key: const Key('expense-time-button'),
                      text: _timeLabel,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        _SectionBlock(
          title: '항목명',
          child: _TextInput(
            key: const Key('expense-item-name-field'),
            controller: _itemNameCtrl,
            maxLength: 100,
            hintText: '선택',
            enabled: !widget.submitting,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 24),
        _SectionBlock(
          title: '메모 (선택)',
          child: _TextInput(
            key: const Key('expense-memo-field'),
            controller: _memoCtrl,
            maxLength: 500,
            hintText: '간단한 메모를 남겨보세요',
            maxLines: 1,
            enabled: !widget.submitting,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 24),
          _InlineError(text: widget.errorText!),
        ],
      ],
    );
  }

  Future<void> _pickDate() async {
    if (widget.submitting) return;
    final picked = await showRecordDatePickerSheet(context, initialDate: _date);
    if (mounted && picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    if (widget.submitting) return;
    final picked = await showRecordTimePickerSheet(context, initialTime: _time);
    if (mounted && picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickAmount() async {
    final value = await showRecordNumberPadSheet(
      context,
      initialValue: _amount?.toString() ?? '',
      mode: RecordNumberInputMode.integer,
      suffixText: '원',
      placeholderText: '0',
    );
    if (!mounted || value == null || widget.submitting) return;
    setState(
      () => _amountCtrl.text = int.tryParse(value) == null
          ? value
          : formatWon(int.parse(value)),
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    final amount = _amount;
    final category = _category;
    if (amount == null ||
        amount <= 0 ||
        amount > walletMaxAmount ||
        category == null) {
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
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        const SizedBox(height: 8),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: AppText(
            text,
            fontSize: 14,
            fontWeight: FontWeight.normal,
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in expenseCategoryOptions)
          _CategoryCard(
            key: Key('expense-category-${option.key}'),
            option: option,
            selected: selectedValue == option.key,
            onTap: () => onSelected(option.key),
          ),
      ],
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
      color: selected ? AppV2Tokens.mintSurface : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 62,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Semantics(
            selected: selected,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExpenseCategoryVisual(category: option.key, size: 32),
                const SizedBox(height: 6),
                AppText(
                  option.label,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
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
        borderRadius: BorderRadius.circular(20),
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

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _TextInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.maxLength,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.text,
        fontWeight: FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
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
        borderRadius: BorderRadius.circular(20),
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

class _SaveButton extends StatefulWidget {
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
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = !widget.canSave
        ? AppColors.surfaceSoft
        : _pressed
        ? AppColors.primaryPressed
        : AppColors.primary;
    return Material(
      key: const Key('expense-save-button'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.canSave ? color : AppColors.border,
            ),
          ),
          child: widget.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : AppText(
                  widget.label,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: widget.canSave ? AppColors.white : AppColors.muted,
                ),
        ),
      ),
    );
  }
}

/// Wallet categories reuse the app's registered SVG assets.
class ExpenseCategoryVisual extends StatelessWidget {
  final String category;
  final double size;
  const ExpenseCategoryVisual({
    super.key,
    required this.category,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) => AppVisual(
    id: switch (category) {
      'food' => AppVisualId.mealDry,
      'snack' => AppVisualId.mealSnack,
      'hospital' => AppVisualId.recordVet,
      'medicine' => AppVisualId.recordMedicine,
      'grooming' => AppVisualId.recordGroom,
      'supplies' => AppVisualId.recordBath,
      _ => AppVisualId.recordEtc,
    },
    size: size,
  );
}
