import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/record_inputs/record_date_time_pickers.dart';
import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../providers/wallet_query_provider.dart';
import '../../providers/wallet_view_provider.dart';
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
    final all = ref.watch(walletCalendarExpensesProvider);
    final selected = all
        .where(
          (e) =>
              e.expenseDate ==
              DateFormat('yyyy-MM-dd').format(query.selectedDate),
        )
        .toList();
    final dates = data.available
        ? all.map((e) => e.expenseDate).toSet()
        : <String>{};
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
        bottom: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('wallet-calendar-add-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: data.pets.isEmpty
                ? null
                : () => context.push('/wallet/expenses/new'),
            child: const Text('지출 추가'),
          ),
        ),
        children: [
          const WalletFilters(showPeriod: false),
          const SizedBox(height: 8),
          WalletMonthNavigation(
            label: '${query.calendarMonth.year}년 ${query.calendarMonth.month}월',
            onLabelTap: () async {
              final picked = await showRecordDatePickerSheet(
                context,
                initialDate: query.selectedDate,
                // Browsing is not restricted to this year's record-entry range.
                // Keep even a date reached beyond the usual range selectable.
                firstDate: DateTime(math.min(1950, query.selectedDate.year)),
                lastDate: DateTime(
                  math.max(DateTime.now().year + 100, query.selectedDate.year),
                  12,
                  31,
                ),
              );
              if (context.mounted && picked != null) {
                notifier.selectDate(picked);
              }
            },
            onPrevious: () => notifier.moveCalendarMonth(-1),
            onNext: () => notifier.moveCalendarMonth(1),
          ),
          const SizedBox(height: 8),
          const WalletLoadStatus(),
          const SizedBox(height: 8),
          WalletCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final day in const ['일', '월', '화', '수', '목', '금', '토'])
                      Expanded(
                        child: AppText(
                          day,
                          textAlign: TextAlign.center,
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent:
                        MediaQuery.textScalerOf(context).scale(13) > 20
                        ? 60
                        : 48,
                  ),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final iso = DateFormat('yyyy-MM-dd').format(day);
                    final active = DateUtils.isSameDay(day, query.selectedDate);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());
                    return Semantics(
                      label:
                          '${day.month}월 ${day.day}일${dates.contains(iso) ? ', 지출 있음' : ''}',
                      selected: active,
                      button: true,
                      child: InkWell(
                        key: Key('wallet-day-$iso'),
                        onTap: () => notifier.selectDate(day),
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 44,
                              minWidth: 36,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : Colors.transparent,
                              border: isToday && !active
                                  ? Border.all(color: AppColors.primary)
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AppText(
                                    '${day.day}',
                                    maxLines: 1,
                                    fontSize: 13,
                                    color: active
                                        ? Colors.white
                                        : day.month == query.calendarMonth.month
                                        ? AppColors.text
                                        : AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dates.contains(iso)
                                        ? (active
                                              ? Colors.white
                                              : AppColors.primary)
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      '${query.selectedDate.month}월 ${query.selectedDate.day}일 총지출',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        data.available
                            ? totalWalletExpenseLabel(selected)
                            : '—',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (data.available) ...[
                      const SizedBox(height: 4),
                      AppText(
                        '${selected.length}건의 지출',
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: SvgPicture.asset(
                  'assets/illustrations/wallet_puppy_wave.svg',
                  width: 126,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const WalletFilters(showCategory: true),
          const SizedBox(height: 12),
          const _CalendarExpenseSectionLabel(),
          if (selected.isEmpty && data.available)
            WalletEmpty(noPets: data.pets.isEmpty),
          if (data.available)
            for (final expense in selected) ...[
              WalletExpenseRow(
                expense: expense,
                petName: query.petId == null
                    ? data.petName(expense.petId)
                    : null,
                keyPrefix: 'wallet-calendar-expense-row',
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _CalendarExpenseSectionLabel extends StatelessWidget {
  const _CalendarExpenseSectionLabel();
  @override
  Widget build(BuildContext context) =>
      const AppText('선택한 조건의 지출 내역', fontSize: 16, fontWeight: FontWeight.bold);
}
