import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_interaction_style.dart';
import 'app_text.dart';

Future<bool?> showAppConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  Key? cancelKey,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            const SizedBox(height: 8),
            AppText(message, fontSize: 13, color: AppColors.textSecondary),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: confirmKey,
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style:
                    FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ).copyWith(
                      overlayColor: AppInteractionStyle.overlay(danger: true),
                    ),
                child: AppText(
                  confirmLabel,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                key: cancelKey,
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceSoft,
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const AppText(
                  '취소',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> showAppDraftExitSheet(
  BuildContext context, {
  String title = '입력을 그만할까요?',
  String message = '저장하지 않은 변경사항은 사라져요.',
  String continueLabel = '계속 입력',
  String exitLabel = '나가기',
  VoidCallback? onExitConfirmed,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            const SizedBox(height: 8),
            AppText(message, fontSize: 13, color: AppColors.textSecondary),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                child: AppText(
                  continueLabel,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop(true);
                  onExitConfirmed?.call();
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceSoft,
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                child: AppText(
                  exitLabel,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
