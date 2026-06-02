import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'expense_record_utils.dart';

class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = expenseRecords(ref.watch(petProvider).records);
    final categories = _categoryTotals(expenses);

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
                      title: '지출 리포트',
                      onBack: () => _goBack(context),
                    ),
                    const SizedBox(height: 8),
                    _ReportSummaryCard(expenses: expenses),
                    const SizedBox(height: 14),
                    const AppText(
                      '카테고리 요약',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    if (categories.isEmpty)
                      const _ReportEmptyPanel(message: '요약할 지출 기록이 없어요')
                    else
                      for (final entry in categories.entries)
                        _CategorySummaryRow(
                          category: entry.key,
                          amount: entry.value,
                        ),
                    const SizedBox(height: 14),
                    const AppText(
                      '지출 내역',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      const _ReportEmptyPanel(message: '아직 지출 기록이 없어요')
                    else
                      for (final record in expenses)
                        _ReportRecordRow(record: record),
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
  final List<ActivityRecord> expenses;

  const _ReportSummaryCard({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final period = expenses.isEmpty
        ? '기간 없음'
        : '${expenses.last.date} - ${expenses.first.date}';

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
                  '전체 기간',
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
            totalExpenseLabel(expenses),
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
  final String category;
  final num amount;

  const _CategorySummaryRow({required this.category, required this.amount});

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
              category,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppText(
            formatWon(amount),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _ReportRecordRow extends StatelessWidget {
  final ActivityRecord record;

  const _ReportRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: AppText(
              record.date,
              fontSize: 11,
              color: AppColors.textSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: AppText(
              '${expenseTitle(record)} · ${expenseCategory(record)}',
              fontSize: 13,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

Map<String, num> _categoryTotals(List<ActivityRecord> records) {
  final totals = <String, num>{};
  for (final record in records) {
    final category = expenseCategory(record);
    totals[category] = (totals[category] ?? 0) + (expenseAmount(record) ?? 0);
  }
  return totals;
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/wallet');
}
