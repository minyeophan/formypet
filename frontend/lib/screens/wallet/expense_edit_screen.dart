import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import 'expense_detail_screen.dart';
import 'expense_form.dart';

class ExpenseEditScreen extends ConsumerStatefulWidget {
  final String recordId;

  const ExpenseEditScreen({super.key, required this.recordId});

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  var _submitting = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final record = state.records
        .where(
          (candidate) =>
              candidate.id == widget.recordId &&
              candidate.petId == state.activePetId &&
              candidate.typeId == 'expense',
        )
        .firstOrNull;

    if (record == null) {
      return const ExpenseDetailScreen(recordId: '');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(title: '지출 수정', onBack: _goBack),
            Expanded(
              child: ExpenseFormBody(
                key: ValueKey(record.id),
                mode: ExpenseFormMode.edit,
                initialData: ExpenseFormData.fromRecord(record),
                petName: state.activePet?.name,
                submitting: _submitting,
                errorText: _errorText,
                onSubmit: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(ExpenseFormData data) async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(petProvider.notifier)
          .updateRecord(widget.recordId, data.toRecordBody());
      if (!mounted) return;
      context.go('/wallet/expenses/${widget.recordId}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '지출 기록을 수정하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/wallet/expenses/${widget.recordId}');
  }
}
