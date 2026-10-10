import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_interaction_style.dart';
import 'app_text.dart';

class AppConfirmDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  const AppConfirmDialogAction({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });
}

/// Scrollable decisions retain all consequences and actions at large text sizes.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<AppConfirmDialogAction> actions;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only a completion notice requires its explicit navigation action.
      canPop: actions.length > 1,
      child: Dialog(
        elevation: 0,
        backgroundColor: AppColors.surface,
        constraints: const BoxConstraints(maxWidth: 480),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(title, fontSize: 18, fontWeight: FontWeight.bold),
              const SizedBox(height: 10),
              AppText(body, fontSize: 14, color: AppColors.textSecondary),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19;
                  final buttons = [
                    for (final action in actions)
                      Expanded(child: _ConfirmActionButton(action: action)),
                  ];
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _ConfirmActionButton(action: actions[i]),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        buttons[i],
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmActionButton extends StatelessWidget {
  final AppConfirmDialogAction action;

  const _ConfirmActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: action.onPressed,
      style:
          TextButton.styleFrom(
            backgroundColor: action.isDanger
                ? AppColors.dangerSoft
                : AppColors.surfaceSoft,
            foregroundColor: action.isDanger
                ? AppColors.danger
                : AppColors.text,
            side: BorderSide(
              color: action.isDanger
                  ? AppColors.dangerBorder
                  : AppColors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ).copyWith(
            overlayColor: AppInteractionStyle.overlay(danger: action.isDanger),
          ),
      child: AppText(
        action.label,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
        color: action.isDanger ? AppColors.danger : AppColors.text,
      ),
    );
  }
}
