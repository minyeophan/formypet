import '../../core/app_interaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_icon.dart';
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
    return WalletDataScope(
      petId: widget.petId,
      category: widget.category,
      period: widget.period,
      child: WalletPage(
        title: '지출 리포트',
        trailing: IconButton(
          tooltip: '캘린더',
          onPressed: () => context.push('/wallet/calendar'),
          icon: const AppIcon(Icons.calendar_today_rounded, size: 24),
        ),
        children: [
          const WalletFilters(),
          const SizedBox(height: 16),
          const AppText('전체 지출 내역', fontSize: 13, fontWeight: FontWeight.w500),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppText(
                data.available ? formatWon(data.amounts.total) : '—',
                key: const Key('wallet-period-total'),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              if (data.available)
                AppText(
                  '· ${data.amounts.periodExpenses.length}건',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
            ],
          ),
          const WalletLoadStatus(),
          const SizedBox(height: 24),
          const WalletFilters(showCategory: true),
          if (data.available) ...[
            if (data.amounts.visible.isEmpty)
              WalletEmpty(noPets: data.pets.isEmpty),
            ...walletDatedRows(
              data.amounts.visible.take(_visibleCount).toList(),
              data,
              keyPrefix: 'wallet-report-expense-row',
            ),
            if (_visibleCount < data.amounts.visible.length) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                key: const Key('wallet-load-more-button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.surfaceSoft,
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                onPressed: () => setState(() => _visibleCount += 20),
                child: const Text('더 보기'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
