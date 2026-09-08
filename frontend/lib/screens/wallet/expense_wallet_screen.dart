import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text.dart';
import 'wallet_budget_card.dart';
import 'wallet_widgets.dart';

export 'wallet_widgets.dart' show walletExpenseVisualId;

class ExpenseWalletScreen extends ConsumerWidget {
  const ExpenseWalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletViewProvider);
    return WalletDataScope(
      child: WalletPage(
        title: '집사의 지갑',
        fallbackRoute: '/home',
        bottom: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('wallet-add-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: data.pets.isEmpty
                ? null
                : () => context.push('/wallet/expenses/new'),
            child: const Text('지출 추가'),
          ),
        ),
        children: [
          const WalletFilters(),
          const SizedBox(height: 24),
          WalletTotal(data: data),
          const WalletLoadStatus(),
          const SizedBox(height: 24),
          WalletBudgetCard(data: data),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.push('/wallet/report'),
                child: const Text('리포트'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/wallet/calendar'),
                icon: const AppIcon(Icons.calendar_today_rounded, size: 20),
                label: const Text('캘린더'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AppText('최근 지출', fontSize: 18, fontWeight: FontWeight.bold),
          const SizedBox(height: 12),
          const WalletFilters(showCategory: true),
          if (data.available && data.amounts.visible.isEmpty)
            WalletEmpty(noPets: data.pets.isEmpty),
          ...walletDatedRows(data.amounts.visible.take(5).toList(), data),
          if (data.amounts.visible.length > 5)
            TextButton(
              onPressed: () => context.push('/wallet/report'),
              child: const Text('전체 내역 보기'),
            ),
        ],
      ),
    );
  }
}
