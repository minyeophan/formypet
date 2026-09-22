import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/pet_data_status.dart';
import 'meal_record_screen.dart';
import 'record_category_form_screen.dart';
import 'record_support.dart';

class RecordEditScreen extends ConsumerStatefulWidget {
  final String recordId;

  const RecordEditScreen({super.key, required this.recordId});

  @override
  ConsumerState<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends ConsumerState<RecordEditScreen> {
  ActivityRecord? _baseline;
  (PetNotifier, (int, int, String?), String)? _identity;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final notifier = ref.read(petProvider.notifier);
    final identity = (notifier, notifier.routineContext, widget.recordId);
    if (_identity != identity) {
      _baseline = null;
      _identity = identity;
    }
    final found = state.records
        .where(
          (candidate) =>
              candidate.id == widget.recordId &&
              candidate.petId == state.activePetId &&
              isRecordDetailSupported(candidate.typeId),
        )
        .firstOrNull;
    if (found != null) _baseline ??= found;
    final record =
        found ??
        (state.isLoading || state.dataErrorText != null ? _baseline : null);

    if (record == null) {
      _baseline = null;
      return _RecordEditNotFoundScreen(
        pending: state.isLoading || state.dataErrorText != null,
      );
    }

    if (record.typeId == 'meal') {
      return MealRecordScreen(
        key: ValueKey(identity),
        editingRecord: _baseline ?? record,
      );
    }

    return RecordCategoryFormScreen(
      key: ValueKey(identity),
      typeId: record.typeId,
      editingRecord: _baseline ?? record,
    );
  }
}

class _RecordEditNotFoundScreen extends StatelessWidget {
  final bool pending;
  const _RecordEditNotFoundScreen({this.pending = false});

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
              child: pending
                  ? const Align(
                      alignment: Alignment.topCenter,
                      child: PetDataStatus(),
                    )
                  : Center(
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
