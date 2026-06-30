import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../app_text.dart';

class RecordFormScrollBody extends StatelessWidget {
  final List<Widget> children;
  final Widget submitButton;
  final EdgeInsets padding;

  const RecordFormScrollBody({
    super.key,
    required this.children,
    required this.submitButton,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 28),
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top,
            padding.right,
            0,
          ),
          sliver: SliverList.list(children: children),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              0,
              padding.right,
              padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const SizedBox(height: 24),
                submitButton,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RecordFormSubmitButton extends StatelessWidget {
  final bool isSaving;
  final bool enabled;
  final VoidCallback onPressed;

  const RecordFormSubmitButton({
    super.key,
    required this.isSaving,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isSaving;
    return Material(
      color: canTap ? AppColors.primary : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canTap ? onPressed : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canTap ? AppColors.primary : AppColors.border,
            ),
          ),
          child: AppText(
            isSaving ? '저장 중' : '등록',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: canTap ? AppColors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
