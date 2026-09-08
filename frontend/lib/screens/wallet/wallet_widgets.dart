import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  const WalletPage({
    super.key,
    required this.title,
    this.fallbackRoute = '/wallet',
    required this.children,
    this.bottom,
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
  const WalletCard({super.key, required this.child, this.highlighted = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showCategory) ...[
          SingleChildScrollView(
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
          if (showPeriod) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  WalletPeriod.month: '월별',
                  WalletPeriod.year: '올해',
                  WalletPeriod.all: '전체 기간',
                }.entries)
                  _Choice(
                    label: entry.value,
                    selected: query.period == entry.key,
                    onTap: () => notifier.setPeriod(entry.key),
                  ),
              ],
            ),
            if (query.period == WalletPeriod.month)
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: () => notifier.setMonth(
                      DateTime(query.baseMonth.year, query.baseMonth.month - 1),
                    ),
                    icon: const AppIcon(Icons.chevron_left_rounded, size: 20),
                  ),
                  Expanded(
                    child: AppText(
                      walletPeriodLabel(query.period, query.baseMonth),
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed: () => notifier.setMonth(
                      DateTime(query.baseMonth.year, query.baseMonth.month + 1),
                    ),
                    icon: const AppIcon(Icons.chevron_right_rounded, size: 20),
                  ),
                ],
              ),
          ],
        ],
        if (showCategory)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Choice(
                  label: '전체 카테고리',
                  selected: query.category == null,
                  onTap: () => notifier.setCategory(null),
                ),
                for (final option in expenseCategoryOptions)
                  _Choice(
                    label: option.label,
                    selected: query.category == option.key,
                    onTap: () => notifier.setCategory(option.key),
                  ),
              ],
            ),
          ),
      ],
    );
  }
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
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary.withValues(alpha: .10),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.text,
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
        if (wallet.refreshWarning == null && wallet.errorText == null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: data.loading || data.petError != null
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(walletExpenseProvider.notifier)
                            .refreshWallet(
                              ref
                                  .read(petProvider)
                                  .pets
                                  .map((pet) => pet.id)
                                  .toList(),
                            );
                      } catch (_) {
                        // Retain the cached values and expose the existing retry notice.
                      }
                    },
              child: const Text('새로고침'),
            ),
          )
        else
          AbsorbPointer(
            absorbing: data.loading || data.petError != null,
            child: const WalletRefreshNotice(),
          ),
      ],
    );
  }
}

class WalletTotal extends StatelessWidget {
  final WalletViewData data;
  const WalletTotal({super.key, required this.data});
  @override
  Widget build(BuildContext context) => WalletCard(
    highlighted: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${walletPeriodLabel(data.query.period, data.query.baseMonth)} · ${data.query.petId == null ? '전체 반려동물' : data.petName(data.query.petId!) ?? ''}',
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 8),
        const AppText('선택 기간 전체 지출', fontWeight: FontWeight.w600),
        const SizedBox(height: 8),
        if (data.available)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              formatWon(data.amounts.total),
              key: const Key('wallet-period-total'),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (!data.available) const AppText('—', fontSize: 32),
        if (data.available)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppText(
              '${data.amounts.periodExpenses.length}건의 지출',
              color: AppColors.textSecondary,
            ),
          ),
      ],
    ),
  );
}

class WalletExpenseRow extends StatelessWidget {
  final WalletExpense expense;
  final String? petName;
  final String keyPrefix;
  const WalletExpenseRow({
    super.key,
    required this.expense,
    this.petName,
    this.keyPrefix = 'wallet-expense-row',
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: InkWell(
      key: Key('$keyPrefix-${expense.id}'),
      onTap: () => context.push(
        '/wallet/expenses/${expense.id}?petId=${Uri.encodeQueryComponent(expense.petId)}',
      ),
      focusColor: AppColors.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppVisual(id: walletExpenseVisualId(expense.category), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    walletExpenseTitle(expense),
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    [
                      ?petName,
                      walletExpenseCategoryLabel(expense),
                      if (normalizeExpenseTime(expense.expenseTime).isNotEmpty)
                        normalizeExpenseTime(expense.expenseTime),
                    ].join(' · '),
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    walletExpenseAmountLabel(expense),
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const AppIcon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

List<Widget> walletDatedRows(
  List<WalletExpense> expenses,
  WalletViewData data, {
  String keyPrefix = 'wallet-expense-row',
}) {
  final result = <Widget>[];
  String? previous;
  for (final expense in expenses) {
    final date = walletExpenseDate(expense.expenseDate);
    final label = date == null ? '날짜 확인 필요' : '${date.month}월 ${date.day}일';
    if (previous != expense.expenseDate) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: AppText(
            date == null ? label : '${date.year}년 $label',
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
