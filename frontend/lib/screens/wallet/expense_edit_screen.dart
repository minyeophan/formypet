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
import 'wallet_refresh_notice.dart';

class ExpenseEditScreen extends ConsumerStatefulWidget {
  final String expenseId;
  final String? petId;

  const ExpenseEditScreen({super.key, required this.expenseId, this.petId});

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  var _submitting = false;
  String? _errorText;
  Future<WalletExpense>? _expenseFuture;
  (int, String, String)? _expenseKey;
  int? _session;
  String? _ownerPetId;
  WalletExpense? _loadedExpense;
  String? _ownerPetName;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petProvider);
    final session = ref.watch(
      walletExpenseProvider.select((state) => state.session),
    );
    if (_session != session) {
      _session = session;
      _ownerPetId = widget.petId;
      _expenseKey = null;
      _expenseFuture = null;
      _loadedExpense = null;
      _ownerPetName = null;
      _submitting = false;
      _errorText = null;
    }
    _ownerPetId ??= pets.activePetId;
    final petId = widget.petId ?? _ownerPetId;
    final hasLoadedIdentity =
        _loadedExpense != null &&
        _expenseKey == (session, petId, widget.expenseId);
    if (pets.isLoading && !hasLoadedIdentity) {
      return ExpenseLoadScreen(loading: true, title: '지출 수정', onBack: _goBack);
    }
    if (petId == null ||
        (!pets.isLoading && !pets.pets.any((pet) => pet.id == petId))) {
      return ExpenseLoadScreen(
        title: '지출 수정',
        onBack: _goBack,
        error: pets.dataErrorText,
        onRetry: pets.dataErrorText == null
            ? null
            : () => ref.read(petProvider.notifier).refreshPets(),
      );
    }
    final expenseKey = (session, petId, widget.expenseId);
    if (_expenseKey != expenseKey) {
      _expenseKey = expenseKey;
      _expenseFuture = null;
      _loadedExpense = null;
      _ownerPetName = null;
      _submitting = false;
      _errorText = null;
    }
    _expenseFuture ??= ref
        .read(walletExpenseProvider.notifier)
        .getExpense(petId, widget.expenseId);

    return FutureBuilder<WalletExpense>(
      future: _expenseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ExpenseLoadScreen(
            loading: true,
            title: '지출 수정',
            onBack: _goBack,
          );
        }
        final expense = snapshot.data;
        if (expense == null) {
          return ExpenseLoadScreen(
            title: '지출 수정',
            onBack: _goBack,
            error: snapshot.error,
            onRetry: () => setState(() => _expenseFuture = null),
          );
        }
        _loadedExpense = expense;
        _ownerPetName =
            pets.pets
                .where((pet) => pet.id == expense.petId)
                .firstOrNull
                ?.name ??
            _ownerPetName;
        return Scaffold(
          backgroundColor: AppColors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                AppFormHeader(
                  title: '\uC9C0\uCD9C \uC218\uC815',
                  onBack: _goBack,
                ),
                Expanded(
                  child: ExpenseFormBody(
                    key: ValueKey(expenseKey),
                    mode: ExpenseFormMode.edit,
                    initialData: ExpenseFormData.fromExpense(expense),
                    petName: _ownerPetName,
                    submitting: _submitting,
                    errorText: _errorText,
                    validTarget:
                        !pets.isLoading &&
                        expense.petId == petId &&
                        pets.pets.any((pet) => pet.id == petId),
                    onSubmit: (data) {
                      if (expenseKey == _expenseKey &&
                          session == ref.read(walletExpenseProvider).session) {
                        _save(expense, data);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(WalletExpense expense, ExpenseFormData data) async {
    if (_submitting) {
      return;
    }
    final petId = expense.petId;
    if (ref.read(petProvider).isLoading ||
        _session != ref.read(walletExpenseProvider).session ||
        !ref.read(petProvider).pets.any((pet) => pet.id == petId)) {
      return;
    }
    final session = ref.read(walletExpenseProvider).session;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(walletExpenseProvider.notifier)
          .updateExpense(
            petId,
            expense.id,
            data.toWalletExpenseBody(includeNulls: true),
          );
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
      showWalletRefreshWarning(context, ref.read(walletExpenseProvider));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          '/wallet/expenses/${expense.id}?petId=${Uri.encodeQueryComponent(petId)}',
        );
      }
    } catch (_) {
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
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
    final petId = _expenseKey?.$2 ?? widget.petId;
    context.go(
      '/wallet/expenses/${widget.expenseId}${petId == null ? '' : '?petId=${Uri.encodeQueryComponent(petId)}'}',
    );
  }
}
