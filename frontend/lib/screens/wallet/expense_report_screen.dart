import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';
import 'wallet_widgets.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  final String? petId, category, period;
  const ExpenseReportScreen({
    super.key,
    this.petId,
    this.category,
    this.period,
  });
  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  int _visibleCount = 20;
  Object? _queryKey;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletViewProvider);
    final query = data.query;
    final key = (query.petId, query.period, query.baseMonth, query.category);
    if (_queryKey != key) {
      _queryKey = key;
      _visibleCount = 20;
    }
    final entries =
        data.amounts.categories.entries
            .where((e) => query.category == null || e.key == query.category)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return WalletDataScope(
      petId: widget.petId,
      category: widget.category,
      period: widget.period,
      child: WalletPage(
        title: '지출 리포트',
        children: [
          const WalletFilters(),
          const SizedBox(height: 24),
          WalletTotal(data: data),
          const WalletLoadStatus(),
          const SizedBox(height: 24),
          const AppText('카테고리별 지출', fontSize: 18, fontWeight: FontWeight.bold),
          const SizedBox(height: 12),
          const WalletFilters(showCategory: true),
          if (data.available) ...[
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        AppText(
                          expenseCategoryDisplayLabel(entry.key),
                          fontWeight: FontWeight.w600,
                        ),
                        AppText(
                          '${formatWon(entry.value)} · ${data.amounts.total == 0 ? '0' : (entry.value * 100 / data.amounts.total).toStringAsFixed(1)}%',
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: data.amounts.total <= 0
                          ? 0
                          : (entry.value / data.amounts.total).clamp(0.0, 1.0),
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: .08),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const AppText('지출 내역', fontSize: 18, fontWeight: FontWeight.bold),
            if (data.amounts.visible.isEmpty)
              WalletEmpty(noPets: data.pets.isEmpty),
            ...walletDatedRows(
              data.amounts.visible.take(_visibleCount).toList(),
              data,
              keyPrefix: 'wallet-report-expense-row',
            ),
            if (_visibleCount < data.amounts.visible.length)
              TextButton(
                key: const Key('wallet-load-more-button'),
                onPressed: () => setState(() => _visibleCount += 20),
                child: const Text('더 보기'),
              ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/wallet/calendar'),
            child: const Text('캘린더에서 보기'),
          ),
        ],
      ),
    );
  }
}
