import '../../core/app_interaction_style.dart';
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
        trailing: IconButton(
          tooltip: '캘린더',
          onPressed: () => context.push('/wallet/calendar'),
          icon: const AppIcon(Icons.calendar_today_rounded, size: 24),
        ),
        bottom: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('wallet-add-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ).copyWith(overlayColor: AppInteractionStyle.overlay()),
            onPressed: data.pets.isEmpty
                ? null
                : () => context.push('/wallet/expenses/new'),
            child: const Text('지출 추가'),
          ),
        ),
        children: [
          const WalletFilters(),
          const SizedBox(height: 16),
          WalletBudgetCard(data: data),
          const WalletLoadStatus(),
          const SizedBox(height: 24),
          const WalletFilters(showCategory: true),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: AppText(
                  '최근 지출',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/wallet/report'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '전체보기',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.available && data.amounts.visible.isEmpty)
            WalletEmpty(noPets: data.pets.isEmpty),
          if (data.available)
            for (final expense in data.amounts.visible.take(5)) ...[
              WalletExpenseRow(
                expense: expense,
                petName: data.query.petId == null
                    ? data.petName(expense.petId)
                    : null,
                showDate: true,
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
        ],
      ),
    );
  }
}
