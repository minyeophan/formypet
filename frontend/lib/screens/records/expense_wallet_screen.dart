import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'expense_record_utils.dart';

class ExpenseWalletScreen extends ConsumerWidget {
  const ExpenseWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = expenseRecords(ref.watch(petProvider).records);
    final recent = expenses.take(3).toList();

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
                      title: '집사의 지갑',
                      onBack: () => _goBack(context),
                    ),
                    const SizedBox(height: 8),
                    _WalletSummaryCard(expenses: expenses),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletActionButton(
                            label: '비용 추가',
                            icon: Icons.add_rounded,
                            onTap: () => context.push('/records/expense/new'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WalletActionButton(
                            label: '내역 보기',
                            icon: Icons.receipt_long_rounded,
                            onTap: () => context.push('/wallet/report'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const AppText(
                      '최근 지출',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    if (recent.isEmpty)
                      const _ExpenseEmptyPanel(message: '아직 지출 기록이 없어요')
                    else
                      for (final record in recent)
                        _ExpenseListRow(record: record),
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

class _WalletSummaryCard extends StatelessWidget {
  final List<ActivityRecord> expenses;

  const _WalletSummaryCard({required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            '누적 지출',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 6),
          AppText(
            totalExpenseLabel(expenses),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 6),
          AppText(
            '${expenses.length}건의 지출 기록',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _WalletActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F8FCF)),
              const SizedBox(width: 7),
              AppText(
                label,
                fontSize: 14,
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

class _ExpenseListRow extends StatelessWidget {
  final ActivityRecord record;

  const _ExpenseListRow({required this.record});

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
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF4F8FCF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: Color(0xFF4F8FCF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  expenseTitle(record),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                AppText(
                  '${record.date} · ${expenseCategory(record)}',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppText(
            expenseAmountLabel(record),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _ExpenseEmptyPanel extends StatelessWidget {
  final String message;

  const _ExpenseEmptyPanel({required this.message});

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
  context.go('/home');
}
