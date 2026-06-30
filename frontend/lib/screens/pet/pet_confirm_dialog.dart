import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_text.dart';

class PetConfirmDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  const PetConfirmDialogAction({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });
}

class PetConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<PetConfirmDialogAction> actions;

  const PetConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              const SizedBox(height: 10),
              AppText(
                body,
                fontSize: 14,
                color: AppColors.textSecondary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _DialogActionButton(action: actions[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  final PetConfirmDialogAction action;

  const _DialogActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surfaceSoft,
        foregroundColor: action.isDanger ? AppColors.danger : AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        minimumSize: const Size(64, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      child: AppText(
        action.label,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: action.isDanger ? AppColors.danger : AppColors.text,
      ),
    );
  }
}
