import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'meal_record_screen.dart';
import 'record_category_form_screen.dart';
import 'record_support.dart';

class RecordEditScreen extends ConsumerWidget {
  final String recordId;

  const RecordEditScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final record = state.records
        .where(
          (candidate) =>
              candidate.id == recordId &&
              candidate.petId == state.activePetId &&
              isRecordDetailSupported(candidate.typeId),
        )
        .firstOrNull;

    if (record == null) {
      return const _RecordEditNotFoundScreen();
    }

    if (record.typeId == 'meal') {
      return MealRecordScreen(editingRecord: record);
    }

    return RecordCategoryFormScreen(
      typeId: record.typeId,
      editingRecord: record,
    );
  }
}

class _RecordEditNotFoundScreen extends StatelessWidget {
  const _RecordEditNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppInlineHeader(
                title: '기록 수정',
                onBack: () => _goBack(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('record-edit-not-found'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText(
                          '기록을 찾을 수 없어요',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/records'),
                          child: const AppText(
                            '기록으로 돌아가기',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/records');
}
