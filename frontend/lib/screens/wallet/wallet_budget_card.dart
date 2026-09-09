import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../providers/wallet_budget_provider.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_text.dart';
import 'wallet_budget_screen.dart';
import 'wallet_expense_utils.dart';

class WalletBudgetCard extends ConsumerWidget {
  final WalletViewData data;
  const WalletBudgetCard({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final target = data.query.period == WalletPeriod.month
        ? data.query.baseMonth
        : now;
    final month = DateTime(target.year, target.month);
    final identity = ref.watch(walletBudgetIdentityProvider);
    final budget = ref.watch(walletMonthlyBudgetProvider(month));
    final total = ref.watch(walletBudgetExpenseProvider(month));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppV2Tokens.mintSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${walletPeriodLabel(data.query.period, data.query.baseMonth)} 지출',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: identity.$1 == null
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => WalletBudgetScreen(
                            month: month,
                            identity: identity,
                          ),
                        ),
                      ),
                child: const AppText(
                  '예산 설정',
                  fontSize: 12,
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        data.available ? formatWon(data.amounts.total) : '—',
                        key: data.available
                            ? const Key('wallet-period-total')
                            : null,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      data.available
                          ? '${data.amounts.periodExpenses.length}건의 지출'
                          : '지출을 확인하고 있어요',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/illustrations/wallet_puppy_wave.svg',
                width: 126,
                height: 102,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (identity.$1 == null)
            const AppText('로그인 후 예산을 설정해 주세요.', fontSize: 14)
          else
            budget.when(
              skipLoadingOnRefresh: false,
              data: (value) => value == null
                  ? const AppText(
                      '월 예산을 설정해 지출을 관리해 보세요.',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppText(
                                '월 예산 ${formatWon(value)}',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: AppText(
                                !data.budgetAvailable || total == null
                                    ? '잔액 —'
                                    : total > value
                                    ? '${formatWon(total - value)} 초과'
                                    : '잔액 ${formatWon(value - total)}',
                                textAlign: TextAlign.right,
                                fontSize: 12,
                                color: AppColors.primaryPressed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        WalletBudgetProgress(
                          budget: value,
                          total: data.budgetAvailable ? total : null,
                        ),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('예산 설정을 불러오지 못했어요.', fontSize: 14),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(walletMonthlyBudgetProvider(month)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          AppText(
            '전체 반려동물 기준 · ${month.month}월 사용 '
            '${data.budgetAvailable && total != null ? formatWon(total) : '—'}',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
