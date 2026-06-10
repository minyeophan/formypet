import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import 'expense_form.dart';

class ExpenseAddScreen extends ConsumerStatefulWidget {
  const ExpenseAddScreen({super.key});

  @override
  ConsumerState<ExpenseAddScreen> createState() => _ExpenseAddScreenState();
}

class _ExpenseAddScreenState extends ConsumerState<ExpenseAddScreen> {
  var _submitting = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final activePet = ref.watch(petProvider).activePet;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(title: '비용 추가', onBack: _goBack),
            Expanded(
              child: ExpenseFormBody(
                mode: ExpenseFormMode.add,
                initialData: ExpenseFormData.now(),
                petName: activePet?.name,
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
    final activePet = ref.read(petProvider).activePet;
    if (activePet == null) {
      setState(() => _errorText = '반려동물을 등록한 뒤 저장할 수 있어요.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref.read(petProvider.notifier).addRecord(data.toRecordBody());
      if (!mounted) return;
      context.go('/wallet');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '비용을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
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
    context.go('/wallet');
  }
}
