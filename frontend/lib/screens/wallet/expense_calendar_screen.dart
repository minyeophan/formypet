import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../providers/wallet_query_provider.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';
import 'wallet_widgets.dart';

class ExpenseCalendarScreen extends ConsumerWidget {
  final String? petId, category, period;
  const ExpenseCalendarScreen({
    super.key,
    this.petId,
    this.category,
    this.period,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletViewProvider);
    final query = data.query;
    final notifier = ref.read(walletQueryProvider.notifier);
    // Use the same complete-source aggregation; calendar has its own visible month.
    final all = ref.watch(walletCalendarExpensesProvider);
    final selected = all
        .where(
          (e) =>
              e.expenseDate ==
              DateFormat('yyyy-MM-dd').format(query.selectedDate),
        )
        .toList();
    final dates = all.map((e) => e.expenseDate).toSet();
    final days = getCalendarDays(
      query.calendarMonth.year,
      query.calendarMonth.month,
    );
    return WalletDataScope(
      calendar: true,
      petId: petId,
      category: category,
      period: period,
      child: WalletPage(
        title: '지출 캘린더',
        children: [
          const WalletFilters(showPeriod: false),
          const SizedBox(height: 12),
          const WalletFilters(showCategory: true),
          const WalletLoadStatus(),
          const SizedBox(height: 24),
          WalletCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '이전 달',
                      onPressed: () => notifier.moveCalendarMonth(-1),
                      icon: const AppIcon(Icons.chevron_left_rounded, size: 20),
                    ),
                    Expanded(
                      child: AppText(
                        '${query.calendarMonth.year}년 ${query.calendarMonth.month}월',
                        textAlign: TextAlign.center,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 달',
                      onPressed: () => notifier.moveCalendarMonth(1),
                      icon: const AppIcon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                TextButton(onPressed: notifier.today, child: const Text('오늘')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in const ['일', '월', '화', '수', '목', '금', '토'])
                      Expanded(
                        child: AppText(
                          day,
                          textAlign: TextAlign.center,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 52,
                  ),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final iso = DateFormat('yyyy-MM-dd').format(day);
                    final active = DateUtils.isSameDay(day, query.selectedDate);
                    return Semantics(
                      label:
                          '${day.month}월 ${day.day}일${dates.contains(iso) ? ', 지출 있음' : ''}',
                      selected: active,
                      button: true,
                      child: InkWell(
                        key: Key('wallet-day-$iso'),
                        onTap: () => notifier.selectDate(day),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 34,
                              width: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: AppText(
                                '${day.day}',
                                fontSize: 13,
                                color: active
                                    ? Colors.white
                                    : day.month == query.calendarMonth.month
                                    ? AppColors.text
                                    : AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dates.contains(iso)
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            '${query.selectedDate.month}월 ${query.selectedDate.day}일 총지출',
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              data.available ? totalWalletExpenseLabel(selected) : '—',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (selected.isEmpty && data.available)
            WalletEmpty(noPets: data.pets.isEmpty),
          ...walletDatedRows(
            selected,
            data,
            keyPrefix: 'wallet-calendar-expense-row',
          ),
        ],
      ),
    );
  }
}
