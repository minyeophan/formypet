import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../app_text.dart';
import 'record_input_style.dart';
import 'record_picker_sheet.dart';
import 'record_picker_values.dart';

class RecordNumberInput extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final RecordNumberInputMode mode;
  final String hintText;
  final int maxDecimalPlaces;
  final String? suffixText;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;

  // The public key is intentionally forwarded to the internal read-only field.
  // ignore: use_key_in_widget_constructors
  const RecordNumberInput({
    Key? key,
    required this.controller,
    required this.mode,
    this.hintText = '',
    this.maxDecimalPlaces = 2,
    this.suffixText,
    this.textAlign = TextAlign.right,
    this.onChanged,
  }) : fieldKey = key,
       super();

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      textAlign: textAlign,
      onTap: () => _openNumberPad(context),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        suffixText: suffixText,
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.muted),
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
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

  Future<void> _openNumberPad(BuildContext context) async {
    final value = await showRecordNumberPadSheet(
      context,
      initialValue: controller.text,
      mode: mode,
      maxDecimalPlaces: maxDecimalPlaces,
      suffixText: suffixText,
      placeholderText: hintText,
    );
    if (value == null) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onChanged?.call(value);
  }
}

Future<String?> showRecordNumberPadSheet(
  BuildContext context, {
  required String initialValue,
  required RecordNumberInputMode mode,
  int maxDecimalPlaces = 2,
  String? suffixText,
  String? placeholderText,
}) {
  return showRecordPickerSheet<String>(
    context,
    builder: (context) => _RecordNumberPadSheet(
      initialValue: initialValue,
      mode: mode,
      maxDecimalPlaces: maxDecimalPlaces,
      suffixText: suffixText,
      placeholderText: placeholderText,
    ),
  );
}

class _RecordNumberPadSheet extends StatefulWidget {
  final String initialValue;
  final RecordNumberInputMode mode;
  final int maxDecimalPlaces;
  final String? suffixText;
  final String? placeholderText;

  const _RecordNumberPadSheet({
    required this.initialValue,
    required this.mode,
    required this.maxDecimalPlaces,
    this.suffixText,
    this.placeholderText,
  });

  @override
  State<_RecordNumberPadSheet> createState() => _RecordNumberPadSheetState();
}

class _RecordNumberPadSheetState extends State<_RecordNumberPadSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return RecordPickerSheet<String>(
      value: () => normalizeRecordNumberInput(_value),
      headerCenter: _NumberPreview(
        value: _value,
        suffixText: widget.suffixText,
        placeholderText: widget.placeholderText,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: RecordInputStyle.numberPadMaxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RecordInputStyle.sheetHorizontalPadding,
            12,
            RecordInputStyle.sheetHorizontalPadding,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in _keys) ...[
                Row(
                  children: [
                    for (final keyValue in row) ...[
                      Expanded(
                        child: _NumberKey(
                          keyValue: keyValue,
                          onTap: () => setState(() {
                            _value = applyRecordNumberKey(
                              _value,
                              keyValue,
                              mode: widget.mode,
                              maxDecimalPlaces: widget.maxDecimalPlaces,
                            );
                          }),
                        ),
                      ),
                      if (keyValue != row.last)
                        const SizedBox(
                          width: RecordInputStyle.numberKeySpacing,
                        ),
                    ],
                  ],
                ),
                if (row != _keys.last)
                  const SizedBox(height: RecordInputStyle.numberKeySpacing),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPreview extends StatelessWidget {
  final String value;
  final String? suffixText;
  final String? placeholderText;

  const _NumberPreview({
    required this.value,
    this.suffixText,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value.isEmpty;
    final displayValue = isPlaceholder
        ? (placeholderText?.isNotEmpty == true ? placeholderText! : '0')
        : value;
    final suffix = suffixText?.trim();
    final text = suffix?.isNotEmpty == true
        ? '$displayValue $suffix'
        : displayValue;

    return AppText(
      text,
      key: const Key('record-number-preview'),
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: isPlaceholder ? AppColors.muted : AppColors.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NumberKey extends StatelessWidget {
  final String keyValue;
  final VoidCallback onTap;

  const _NumberKey({required this.keyValue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBackspace = keyValue == 'backspace';
    final keyName = switch (keyValue) {
      '.' => 'dot',
      'backspace' => 'backspace',
      _ => keyValue,
    };

    return Material(
      color: keyValue == '.' ? AppColors.surfaceSoft : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('record-number-key-$keyName'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: RecordInputStyle.numberKeyHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RecordInputStyle.borderColor),
          ),
          child: isBackspace
              ? const Icon(
                  Icons.backspace_outlined,
                  size: 21,
                  color: AppColors.textSecondary,
                )
              : Text(
                  keyValue,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: RecordInputStyle.textColor,
                  ),
                ),
        ),
      ),
    );
  }
}

const _keys = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['.', '0', 'backspace'],
];
