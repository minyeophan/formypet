import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  var _deleting = false;
  String? _errorText;
  Future<WalletExpense>? _expenseFuture;

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(petProvider).activePetId;
    if (petId == null) {
      return const _ExpenseNotFoundScreen();
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
        if (!snapshot.hasData) {
          return const _ExpenseNotFoundScreen();
        }
        final matchingPets = ref
            .read(petProvider)
            .pets
            .where((pet) => pet.id == petId)
            .toList();
        return _ExpenseDetailBody(
          expense: snapshot.data!,
          petName: matchingPets.isEmpty ? null : matchingPets.first.name,
          deleting: _deleting,
          errorText: _errorText,
          onDelete: _deleting ? null : _confirmDelete,
        );
      },
    );
  }

  Future<void> _confirmDelete(WalletExpense expense) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uC0AD\uC81C\uD560\uAE4C\uC694?',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                const SizedBox(height: 8),
                const AppText(
                  '\uC0AD\uC81C\uD55C \uAE30\uB85D\uC740 \uB418\uB3CC\uB9B4 \uC218 \uC5C6\uC5B4\uC694.',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                _SheetButton(
                  key: const Key('expense-delete-confirm-button'),
                  label: '\uC0AD\uC81C',
                  danger: true,
                  onTap: () => context.pop(true),
                ),
                const SizedBox(height: 8),
                _SheetButton(
                  label: '\uCDE8\uC18C',
                  danger: false,
                  onTap: () => context.pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _delete(expense);
    }
  }

  Future<void> _delete(WalletExpense expense) async {
    final petId = ref.read(petProvider).activePetId;
    if (petId == null) {
      return;
    }
    setState(() {
      _deleting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(walletExpenseProvider.notifier)
          .deleteExpense(petId, expense.id);
      if (!mounted) return;
      context.go('/wallet');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorText =
            '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uC0AD\uC81C\uD558\uC9C0 \uBABB\uD588\uC5B4\uC694. \uC7A0\uC2DC \uD6C4 \uB2E4\uC2DC \uC2DC\uB3C4\uD574 \uC8FC\uC138\uC694.';
      });
    }
  }
}

class _ExpenseDetailBody extends StatelessWidget {
  final WalletExpense expense;
  final String? petName;
  final bool deleting;
  final String? errorText;
  final ValueChanged<WalletExpense>? onDelete;

  const _ExpenseDetailBody({
    required this.expense,
    required this.petName,
    required this.deleting,
    required this.errorText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemName = expense.itemName?.trim();
    final note = expense.note?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '\uC9C0\uCD9C \uC0C1\uC138',
                  onBack: () => _goBack(context),
                  trailing: TextButton(
                    key: const Key('expense-detail-edit-button'),
                    onPressed: () =>
                        context.push('/wallet/expenses/${expense.id}/edit'),
                    child: const AppText(
                      '\uC218\uC815',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.list(
                children: [
                  _SectionBlock(
                    title: '\uB0A0\uC9DC/\uC2DC\uAC04',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ValueBox(
                            key: const Key('expense-detail-date-label'),
                            text: expense.expenseDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ValueBox(
                            key: const Key('expense-detail-time-label'),
                            text: normalizeExpenseTime(expense.expenseTime),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '\uC9C0\uCD9C \uC815\uBCF4',
                    child: Column(
                      children: [
                        _ValueRow(
                          key: const Key('expense-detail-pet-row'),
                          label: '반려동물',
                          value: petName ?? '-',
                        ),
                        _ValueRow(
                          label: '\uAE08\uC561',
                          value: walletExpenseAmountLabel(expense),
                        ),
                        _ValueRow(
                          label: '\uCE74\uD14C\uACE0\uB9AC',
                          value: walletExpenseCategoryLabel(expense),
                        ),
                        _ValueRow(
                          label: '\uD488\uBAA9\uBA85',
                          value: itemName?.isNotEmpty == true ? itemName! : '-',
                        ),
                        _ValueRow(
                          label: '\uBA54\uBAA8',
                          value: note?.isNotEmpty == true ? note! : '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (errorText != null) ...[
                    _InlineError(text: errorText!),
                    const SizedBox(height: 12),
                  ],
                  _DetailActionButton(
                    deleting: deleting,
                    onTap: onDelete == null ? null : () => onDelete!(expense),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseNotFoundScreen extends StatelessWidget {
  const _ExpenseNotFoundScreen();

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
                title: '\uC9C0\uCD9C \uC0C1\uC138',
                onBack: () => _goBack(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('expense-detail-not-found'),
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
                          '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uCC3E\uC744 \uC218 \uC5C6\uC5B4\uC694',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const Key('expense-not-found-wallet-button'),
                          onPressed: () => context.go('/wallet'),
                          child: const AppText(
                            '\uC9C0\uAC11\uC73C\uB85C \uB3CC\uC544\uAC00\uAE30',
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

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ValueRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AppText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(child: _ValueBox(text: value)),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String text;

  const _ValueBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        value.isEmpty ? '-' : value,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: value.isEmpty ? AppColors.muted : AppColors.text,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('expense-delete-error'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: AppText(
        text,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFB91C1C),
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  final bool deleting;
  final VoidCallback? onTap;

  const _DetailActionButton({required this.deleting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('expense-delete-button'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppText(
                  '\uC9C0\uCD9C \uC0AD\uC81C',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C),
                ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SheetButton({
    super.key,
    required this.label,
    required this.danger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? const Color(0xFFFFF1F2) : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger ? const Color(0xFFFECACA) : AppColors.border,
            ),
          ),
          child: AppText(
            label,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: danger ? const Color(0xFFB91C1C) : AppColors.text,
          ),
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
  context.go('/wallet');
}
