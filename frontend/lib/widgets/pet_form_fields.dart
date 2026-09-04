import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_text.dart';

class PetFormSection extends StatelessWidget {
  final String? title;
  final Widget child;

  const PetFormSection({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            AppText(
              title!,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class PetTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? trailing;
  final int minLines;
  final TextInputAction? textInputAction;

  const PetTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.trailing,
    this.minLines = 1,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, fontWeight: FontWeight.bold),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          cursorColor: AppColors.primary,
          minLines: minLines,
          maxLines: minLines == 1 ? 1 : 4,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            constraints: const BoxConstraints(minHeight: 54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 4), trailing!],
      ],
    );
  }
}

class PetDateField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PetDateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final visibleValue = value?.trim();
    final hasValue = visibleValue != null && visibleValue.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, fontWeight: FontWeight.bold),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      hasValue ? visibleValue : placeholder,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasValue ? AppColors.text : AppColors.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 4), trailing!],
      ],
    );
  }
}

class PetPickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isPlaceholder;
  final bool enabled;

  const PetPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, fontWeight: FontWeight.bold),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      value,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isPlaceholder
                          ? AppColors.textSecondary
                          : AppColors.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PetChoiceButton extends StatelessWidget {
  final Widget? leading;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;

  const PetChoiceButton({
    super.key,
    this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? AppColors.text : AppColors.muted;
    final minHeight = dense ? 44.0 : 48.0;
    final minWidth = dense ? 0.0 : 74.0;
    final horizontalPadding = leading != null ? 6.0 : (dense ? 8.0 : 14.0);
    final verticalPadding = dense ? 10.0 : 11.0;
    final fontSize = dense ? 12.0 : 14.0;
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: minWidth,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(height: 4)],
                AppText(
                  label,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.white : textColor,
                  textAlign: TextAlign.center,
                  maxLines: leading == null ? 1 : null,
                  overflow: leading == null ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
