import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import 'expense_detail_screen.dart';
import 'expense_form.dart';

class ExpenseEditScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const ExpenseEditScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  var _submitting = false;
  String? _errorText;
  Future<WalletExpense>? _expenseFuture;

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(petProvider).activePetId;
    if (petId == null) {
      return const ExpenseDetailScreen(expenseId: '');
    }
    _expenseFuture ??= ref
        .read(walletExpenseProvider.notifier)
        .getExpense(petId, widget.expenseId);

    return FutureBuilder<WalletExpense>(
      future: _expenseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final expense = snapshot.data;
        if (expense == null) {
          return const ExpenseDetailScreen(expenseId: '');
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                AppFormHeader(
                  title: '\uC9C0\uCD9C \uC218\uC815',
                  onBack: _goBack,
                ),
                Expanded(
                  child: ExpenseFormBody(
                    key: ValueKey(expense.id),
                    mode: ExpenseFormMode.edit,
                    initialData: ExpenseFormData.fromExpense(expense),
                    petName: ref.watch(petProvider).activePet?.name,
                    submitting: _submitting,
                    errorText: _errorText,
                    onSubmit: _save,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(ExpenseFormData data) async {
    if (_submitting) {
      return;
    }
    final petId = ref.read(petProvider).activePetId;
    if (petId == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(walletExpenseProvider.notifier)
          .updateExpense(
            petId,
            widget.expenseId,
            data.toWalletExpenseBody(includeNulls: true),
          );
      if (!mounted) return;
      context.go('/wallet/expenses/${widget.expenseId}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText =
            '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uC218\uC815\uD558\uC9C0 \uBABB\uD588\uC5B4\uC694. \uC7A0\uC2DC \uD6C4 \uB2E4\uC2DC \uC2DC\uB3C4\uD574 \uC8FC\uC138\uC694.';
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
    context.go('/wallet/expenses/${widget.expenseId}');
  }
}
