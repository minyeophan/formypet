import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/wallet_expense.dart';
import '../../models/wallet_expense.dart' as wallet_model;
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  String? _loadedPetId;

  @override
  Widget build(BuildContext context) {
    final activePetId = ref.watch(petProvider).activePetId;
    if (activePetId != null && activePetId != _loadedPetId) {
      _loadedPetId = activePetId;
      Future.microtask(
        () =>
            ref.read(walletExpenseProvider.notifier).loadFirstPage(activePetId),
      );
    }

    final state = ref.watch(walletExpenseProvider);
    final expenses = state.items;
    final categories = state.summary.categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInlineHeader(
                      title: '\uC9C0\uCD9C \uB9AC\uD3EC\uD2B8',
                      onBack: () => _goBack(context),
                    ),
                    const SizedBox(height: 8),
                    _ReportSummaryCard(
                      expenses: expenses,
                      totalAmount: state.summary.totalAmount,
                    ),
                    const SizedBox(height: 14),
                    const AppText(
                      '\uCE74\uD14C\uACE0\uB9AC \uC694\uC57D',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    if (categories.isEmpty)
                      const _ReportEmptyPanel(
                        message:
                            '\uC694\uC57D\uD560 \uC9C0\uCD9C \uAE30\uB85D\uC774 \uC5C6\uC5B4\uC694',
                      )
                    else
                      for (final category in categories)
                        _CategorySummaryRow(category: category),
                    const SizedBox(height: 14),
                    const AppText(
                      '\uC9C0\uCD9C \uB0B4\uC5ED',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      const _ReportEmptyPanel(
                        message:
                            '\uC544\uC9C1 \uC9C0\uCD9C \uAE30\uB85D\uC774 \uC5C6\uC5B4\uC694',
                      )
                    else
                      for (final expense in expenses)
                        _ReportExpenseRow(expense: expense),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final List<WalletExpense> expenses;
  final int totalAmount;

  const _ReportSummaryCard({required this.expenses, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    final period = expenses.isEmpty
        ? '\uAE30\uAC04 \uC5C6\uC74C'
        : '${expenses.last.expenseDate} - ${expenses.first.expenseDate}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  '\uC804\uCCB4 \uAE30\uAC04',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 5),
                AppText(
                  period,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppText(
            formatWon(totalAmount),
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  final wallet_model.WalletExpenseCategorySummary category;

  const _CategorySummaryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              category.categoryLabel,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppText(
            formatWon(category.amount),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _ReportExpenseRow extends StatelessWidget {
  final WalletExpense expense;

  const _ReportExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('wallet-report-expense-row-${expense.id}'),
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/wallet/expenses/${expense.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: AppText(
                  expense.expenseDate,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: AppText(
                  '${walletExpenseTitle(expense)} · ${walletExpenseCategoryLabel(expense)}',
                  fontSize: 13,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppText(
                walletExpenseAmountLabel(expense),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportEmptyPanel extends StatelessWidget {
  final String message;

  const _ReportEmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        message,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
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
