import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_colors.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../providers/wallet_query_provider.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import 'wallet_expense_utils.dart';
import 'wallet_refresh_notice.dart';
import 'wallet_period_sheet.dart';

class WalletDataScope extends ConsumerStatefulWidget {
  final Widget child;
  final bool calendar;
  final String? petId, category, period;
  const WalletDataScope({
    super.key,
    required this.child,
    this.calendar = false,
    this.petId,
    this.category,
    this.period,
  });
  @override
  ConsumerState<WalletDataScope> createState() => _WalletDataScopeState();
}

class _WalletDataScopeState extends ConsumerState<WalletDataScope> {
  String? _loadKey;
  bool _wasCurrent = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final query = ref.read(walletQueryProvider.notifier);
      if (widget.petId != null) query.setPet(widget.petId);
      if (widget.category != null) {
        query.setCategory(
          expenseCategoryOptions.any((o) => o.key == widget.category)
              ? widget.category
              : null,
        );
      }
      if (widget.period != null) {
        query.setPeriod(walletPeriodFromValue(widget.period));
      }
      if (widget.calendar) query.openCalendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petProvider);
    final session = ref.watch(walletExpenseProvider.select((s) => s.session));
    final petError = walletPetListError(pets);
    // ModalRoute notifies this scope when a pushed page is popped, even when
    // the wallet itself stayed mounted underneath it.
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final entering = current && !_wasCurrent;
    _wasCurrent = current;
    final ids = pets.pets.map((p) => p.id).toList()..sort();
    final key = '$session:${ids.join(',')}:${pets.isLoading}:$petError';
    if (current &&
        !pets.isLoading &&
        petError == null &&
        (key != _loadKey || entering)) {
      _loadKey = key;
      Future.microtask(() async {
        if (!mounted || _loadKey != key) return;
        final query = ref.read(walletQueryProvider);
        if (query.petId != null && !ids.contains(query.petId)) {
          ref.read(walletQueryProvider.notifier).setPet(null);
        }
        try {
          await ref.read(walletExpenseProvider.notifier).ensureAllPets(ids);
        } catch (_) {
          /* The provider retains data and exposes the retry state. */
        }
      });
    }
    return widget.child;
  }
}

class WalletPage extends StatelessWidget {
  final String title;
  final String fallbackRoute;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? trailing;
  const WalletPage({
    super.key,
    required this.title,
    this.fallbackRoute = '/wallet',
    required this.children,
    this.bottom,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              AppInlineHeader(
                title: title,
                trailing: trailing,
                onBack: () => walletBack(context, fallbackRoute: fallbackRoute),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: children,
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: bottom!,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void walletBack(BuildContext context, {String fallbackRoute = '/wallet'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}

class WalletCard extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  final EdgeInsetsGeometry padding;
  const WalletCard({
    super.key,
    required this.child,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: highlighted
          ? AppColors.primary.withValues(alpha: 0.07)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class WalletFilters extends ConsumerWidget {
  final bool showPeriod;
  final bool showCategory;
  const WalletFilters({
    super.key,
    this.showPeriod = true,
    this.showCategory = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletViewProvider);
    final query = data.query;
    final notifier = ref.read(walletQueryProvider.notifier);
    if (showCategory) {
      return WalletCategorySelector(
        selected: query.category,
        onSelected: notifier.setCategory,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showPeriod) ...[
              SizedBox(
                key: const Key('wallet-period-button'),
                width: 44,
                height: 44,
                child: Center(
                  child: IconButton(
                    tooltip: '기간 설정',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final session = ref.read(walletExpenseProvider).session;
                      final selection = await showWalletPeriodSheet(
                        context,
                        period: query.period,
                        month: query.baseMonth,
                      );
                      if (!context.mounted ||
                          selection == null ||
                          ref.read(walletExpenseProvider).session != session) {
                        return;
                      }
                      notifier.applyPeriod(selection.period, selection.month);
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/ui_poll.svg',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  key: const Key('wallet-pet-selector'),
                  children: [
                    _Choice(
                      label: '전체',
                      selected: query.petId == null,
                      onTap: () => notifier.setPet(null),
                    ),
                    for (final pet in data.pets)
                      _Choice(
                        label: pet.name,
                        selected: query.petId == pet.id,
                        onTap: () => notifier.setPet(pet.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showPeriod) ...[
          const SizedBox(height: 8),
          WalletMonthNavigation(
            label: walletPeriodLabel(query.period, query.baseMonth),
            onPrevious: query.period == WalletPeriod.month
                ? () => notifier.setMonth(
                    DateTime(query.baseMonth.year, query.baseMonth.month - 1),
                  )
                : null,
            onNext: query.period == WalletPeriod.month
                ? () => notifier.setMonth(
                    DateTime(query.baseMonth.year, query.baseMonth.month + 1),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

class WalletMonthNavigation extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious, onNext;
  final VoidCallback? onLabelTap;
  const WalletMonthNavigation({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
    this.onLabelTap,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onPrevious != null)
        IconButton(
          tooltip: '이전 달',
          onPressed: onPrevious,
          icon: const AppIcon(Icons.chevron_left_rounded, size: 20),
        ),
      Expanded(
        child: InkWell(
          key: onLabelTap == null ? null : const Key('wallet-month-label'),
          onTap: onLabelTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AppText(
              label,
              textAlign: TextAlign.center,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      if (onNext != null)
        IconButton(
          tooltip: '다음 달',
          onPressed: onNext,
          icon: const AppIcon(Icons.chevron_right_rounded, size: 20),
        ),
    ],
  );
}

class WalletCategorySelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool includeAll;
  const WalletCategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeAll = true,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (includeAll)
          _CategoryChoice(
            label: '전체',
            id: AppVisualId.communityAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
        // Keep every server category reachable; the design illustrates the first four.
        for (final key in const [
          'food',
          'snack',
          'hospital',
          'etc',
          'medicine',
          'grooming',
          'supplies',
        ])
          _CategoryChoice(
            label: expenseCategoryDisplayLabel(key),
            id: walletExpenseVisualId(key),
            selected: selected == key,
            onTap: () => onSelected(key),
          ),
      ],
    ),
  );
}

class _CategoryChoice extends StatelessWidget {
  final String label;
  final AppVisualId id;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChoice({
    required this.label,
    required this.id,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? const Color(0xFFEAF7F0) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 62, minHeight: 64),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppVisual(id: id, size: 24),
                const SizedBox(height: 2),
                AppText(label, fontSize: 12, fontWeight: FontWeight.w500),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceSoft,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selected ? AppColors.white : AppColors.text,
      ),
    ),
  );
}

class WalletLoadStatus extends ConsumerWidget {
  const WalletLoadStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletViewProvider);
    final wallet = ref.watch(walletExpenseProvider);
    return Column(
      children: [
        if (data.loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        if (data.petError != null)
          Column(
            children: [
              const AppText('반려동물 목록을 불러오지 못했어요.'),
              TextButton(
                onPressed: data.loading
                    ? null
                    : () async {
                        final session = ref.read(walletExpenseProvider).session;
                        final notifier = ref.read(petProvider.notifier);
                        try {
                          await notifier.refreshPets();
                          if (!context.mounted ||
                              ref.read(walletExpenseProvider).session !=
                                  session ||
                              !identical(
                                ref.read(petProvider.notifier),
                                notifier,
                              )) {
                            return;
                          }
                          final pets = ref.read(petProvider);
                          // An unchanged active pet keeps dataErrorText during
                          // refreshPets. Retry its data to resolve that error
                          // through the provider's loading/session lifecycle.
                          if (!pets.isLoading &&
                              walletPetListError(pets) != null) {
                            await notifier.retryDataLoad();
                          }
                        } catch (_) {}
                      },
                child: const Text('반려동물 새로고침'),
              ),
            ],
          ),
        if (wallet.refreshWarning != null || wallet.errorText != null)
          AbsorbPointer(
            absorbing: data.loading || data.petError != null,
            child: const WalletRefreshNotice(),
          ),
      ],
    );
  }
}

class WalletExpenseRow extends StatelessWidget {
  final WalletExpense expense;
  final String? petName;
  final String keyPrefix;
  final bool showDate;
  const WalletExpenseRow({
    super.key,
    required this.expense,
    this.petName,
    this.keyPrefix = 'wallet-expense-row',
    this.showDate = false,
  });
  @override
  Widget build(BuildContext context) {
    final date = walletExpenseDate(expense.expenseDate);
    final subtitle = [
      ?petName,
      if (showDate)
        date == null ? '날짜 확인 필요' : '${date.month}월 ${date.day}일'
      else
        walletExpenseCategoryLabel(expense),
    ].join(' · ');
    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: Key('$keyPrefix-${expense.id}'),
        onTap: () => context.push(
          '/wallet/expenses/${expense.id}?petId=${Uri.encodeQueryComponent(expense.petId)}',
        ),
        focusColor: AppColors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              final amount = AppText(
                walletExpenseAmountLabel(expense),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              );
              return Row(
                children: [
                  AppVisual(
                    id: walletExpenseVisualId(expense.category),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          walletExpenseTitle(expense),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        const SizedBox(height: 2),
                        AppText(subtitle, color: AppColors.muted, fontSize: 12),
                        if (stacked) ...[const SizedBox(height: 4), amount],
                      ],
                    ),
                  ),
                  if (!stacked) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: amount,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const AppIcon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

List<Widget> walletDatedRows(
  List<WalletExpense> expenses,
  WalletViewData data, {
  String keyPrefix = 'wallet-expense-row',
}) {
  final result = <Widget>[];
  final dailyTotals = <String, int>{};
  for (final expense in data.amounts.visible) {
    dailyTotals.update(
      expense.expenseDate,
      (sum) => sum + expense.amount,
      ifAbsent: () => expense.amount,
    );
  }
  String? previous;
  for (final expense in expenses) {
    final date = walletExpenseDate(expense.expenseDate);
    final label = date == null ? '날짜 확인 필요' : '${date.month}월 ${date.day}일';
    if (previous != expense.expenseDate) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: AppText(
            '${date == null ? label : '${date.year}년 $label'} · ${formatWon(dailyTotals[expense.expenseDate] ?? 0)}',
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      previous = expense.expenseDate;
    }
    result.add(
      WalletExpenseRow(
        expense: expense,
        petName: data.query.petId == null ? data.petName(expense.petId) : null,
        keyPrefix: keyPrefix,
      ),
    );
    result.add(const Divider(height: 1, color: AppColors.border));
  }
  return result;
}

class WalletEmpty extends StatelessWidget {
  final bool noPets;
  const WalletEmpty({super.key, this.noPets = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        AppText(
          noPets ? '반려동물을 등록하면 지출을 기록할 수 있어요.' : '선택한 조건의 지출 내역이 없어요.',
          textAlign: TextAlign.center,
          color: AppColors.textSecondary,
        ),
        if (noPets)
          TextButton(
            onPressed: () => context.push('/pets/new'),
            child: const Text('반려동물 추가'),
          ),
      ],
    ),
  );
}

AppVisualId walletExpenseVisualId(String category) => switch (category) {
  'food' => AppVisualId.recordMeal,
  'snack' => AppVisualId.mealSnack,
  'vet' || 'hospital' => AppVisualId.recordVet,
  'medicine' || 'medication' => AppVisualId.recordMedicine,
  'grooming' => AppVisualId.recordGroom,
  _ => AppVisualId.recordEtc,
};
