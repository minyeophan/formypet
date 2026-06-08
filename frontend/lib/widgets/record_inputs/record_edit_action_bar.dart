import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../app_text.dart';

class RecordEditActionBar extends StatelessWidget {
  final bool enabled;
  final bool isSaving;
  final bool isDeleting;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const RecordEditActionBar({
    super.key,
    required this.enabled,
    required this.isSaving,
    required this.isDeleting,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isSaving || isDeleting;
    final canSave = enabled && !busy;
    final canDelete = !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: canSave ? AppColors.primary : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('record-edit-save-button'),
            borderRadius: BorderRadius.circular(16),
            onTap: canSave ? onSave : null,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canSave ? AppColors.primary : AppColors.border,
                ),
              ),
              child: AppText(
                isSaving ? '수정 중...' : '수정 완료',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: canSave ? AppColors.white : AppColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('record-edit-delete-button'),
            borderRadius: BorderRadius.circular(16),
            onTap: canDelete ? onDelete : null,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.dangerBorder),
              ),
              child: AppText(
                isDeleting ? '삭제 중...' : '삭제',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool?> showRecordDeleteConfirmationSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText(
              '기록을 삭제할까요?',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            const SizedBox(height: 8),
            const AppText(
              '삭제한 기록은 다시 되돌릴 수 없어요.',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('record-delete-confirm-button'),
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const AppText('삭제', color: AppColors.white),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('취소', color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}
