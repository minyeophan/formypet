import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_interaction_style.dart';
import '../../widgets/record_inputs/record_inputs.dart';

/// Numeric draft field whose picker cannot write after save or disposal.
class RecordDraftNumberInput extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final RecordNumberInputMode mode;
  final String hintText;
  final int maxDecimalPlaces;
  final String? suffixText;
  final bool enabled;
  final bool Function() canApply;
  final ValueChanged<String>? onChanged;

  const RecordDraftNumberInput({
    Key? key,
    required this.controller,
    required this.mode,
    required this.enabled,
    required this.canApply,
    this.hintText = '',
    this.maxDecimalPlaces = 2,
    this.suffixText,
    this.onChanged,
  }) : fieldKey = key,
       super(key: null);

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    enabled: enabled,
    readOnly: true,
    showCursor: false,
    enableInteractiveSelection: false,
    textAlign: TextAlign.right,
    onTap: () async {
      if (!canApply()) return;
      final value = await showRecordNumberPadSheet(
        context,
        initialValue: controller.text,
        mode: mode,
        maxDecimalPlaces: maxDecimalPlaces,
        suffixText: suffixText,
        placeholderText: hintText,
      );
      if (!context.mounted || !canApply() || value == null) return;
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      onChanged?.call(value);
    },
    style: const TextStyle(
      fontSize: 14,
      color: AppColors.text,
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      filled: true,
      fillColor: AppInteractionStyle.inputFill,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
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
