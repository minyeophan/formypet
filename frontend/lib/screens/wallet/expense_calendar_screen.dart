import '../../widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_underline_tabs.dart';
import 'wallet_expense_utils.dart';
import 'wallet_refresh_notice.dart';

class ExpenseCalendarScreen extends ConsumerStatefulWidget {
  final String? petId;
  final String? category;
  final String? period;

  const ExpenseCalendarScreen({super.key, this.petId, this.category, this.period});

  @override
  ConsumerState<ExpenseCalendarScreen> createState() =>
      _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends ConsumerState<ExpenseCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  String? _loadedPetsKey;
  String? _selectedPetId;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.petId;
    _selectedCategory = widget.category;
    final selectedPeriod = walletPeriodFromValue(widget.period);
    if (selectedPeriod == WalletPeriod.year || selectedPeriod == WalletPeriod.all) {
      _month = DateTime.now();
      _selected = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);
    final pets = petState.pets;
    final walletState = ref.watch(walletExpenseProvider);
    final petsKey =
        '${walletState.session}:${pets.map((pet) => pet.id).join(',')}';
    if (petsKey != _loadedPetsKey) {
      _loadedPetsKey = petsKey;
      if (!pets.any((pet) => pet.id == _selectedPetId)) _selectedPetId = null;
      Future.microtask(() async {
        if (!mounted || petsKey != _loadedPetsKey) return;
        try {
          await ref
              .read(walletExpenseProvider.notifier)
              .loadAllPets(pets.map((pet) => pet.id).toList());
        } catch (_) {
          // The already-loaded provider data remains usable when the API is unavailable.
        }
      });
    }
    final allExpenses = pets
        .where((pet) => _selectedPetId == null || pet.id == _selectedPetId)
        .expand(
          (pet) =>
              walletState.expensesByPet[pet.id] ??
              walletState.items.where((item) => item.petId == pet.id),
        );
    final expenses = allExpenses
        .where(
          (e) => _selectedCategory == null || e.category == _selectedCategory,
        )
        .toList();
    final totalsAvailable =
        !petState.isLoading &&
        !(pets.isEmpty && petState.dataErrorText != null) &&
        pets
            .where((pet) => _selectedPetId == null || pet.id == _selectedPetId)
            .every((pet) => walletState.expensesByPet.containsKey(pet.id));
    final days = getCalendarDays(_month.year, _month.month);
    final selectedExpenses = expenses
        .where((e) => e.expenseDate == _iso(_selected))
        .toList();
    final total = selectedExpenses.fold<int>(0, (sum, e) => sum + e.amount);

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
                      title: '지출 캘린더',
                      onBack: () => _goBack(context),
                    ),
                    if (walletState.isLoadingAll)
                      const Center(child: CircularProgressIndicator()),
                    const WalletRefreshNotice(),
                    if (pets.isEmpty && petState.dataErrorText != null)
                      AppText(petState.dataErrorText!),
                    AppUnderlineTabs(
                      items: ['전체', ...pets.map((pet) => pet.name)],
                      selectedIndex: _selectedPetId == null
                          ? 0
                          : pets.indexWhere((pet) => pet.id == _selectedPetId) +
                                1,
                      onChanged: (index) => setState(
                        () => _selectedPetId = index == 0
                            ? null
                            : pets[index - 1].id,
                      ),
                    ),
                    AppUnderlineTabs(
                      items: [
                        '전체',
                        ...expenseCategoryOptions.map((item) => item.label),
                      ],
                      selectedIndex: _selectedCategory == null
                          ? 0
                          : expenseCategoryOptions.indexWhere(
                                  (item) => item.key == _selectedCategory,
                                ) +
                                1,
                      onChanged: (index) => setState(
                        () => _selectedCategory = index == 0
                            ? null
                            : expenseCategoryOptions[index - 1].key,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _moveMonth(-1),
                          icon: const AppIcon(Icons.chevron_left_rounded),
                        ),
                        AppText(
                          '${_month.year}년 ${_month.month}월',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        IconButton(
                          onPressed: () => _moveMonth(1),
                          icon: const AppIcon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _CalendarGrid(
                      days: days,
                      month: _month,
                      selected: _selected,
                      expenses: expenses,
                      onSelect: (date) => setState(() => _selected = date),
                    ),
                    const SizedBox(height: 22),
                    AppText(
                      '${_selected.month}월 ${_selected.day}일 총지출',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      totalsAvailable ? formatWon(total) : '—',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 14),
                    if (selectedExpenses.isEmpty && totalsAvailable)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: AppText(
                          '이 날의 지출 내역이 없어요.',
                          textAlign: TextAlign.center,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      for (final expense in selectedExpenses)
                        _ExpenseCalendarRow(expense: expense),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(int amount) => setState(() {
    _month = DateTime(_month.year, _month.month + amount);
    _selected = DateTime(_month.year, _month.month, 1);
  });
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.days,
    required this.month,
    required this.selected,
    required this.expenses,
    required this.onSelect,
  });
  final List<DateTime> days;
  final DateTime month;
  final DateTime selected;
  final List<WalletExpense> expenses;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: days.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 7,
      mainAxisExtent: 48,
    ),
    itemBuilder: (_, index) {
      final day = days[index];
      final active =
          day.year == selected.year &&
          day.month == selected.month &&
          day.day == selected.day;
      final hasExpense = expenses.any((e) => e.expenseDate == _iso(day));
      return InkWell(
        onTap: () => onSelect(day),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: AppText(
                '${day.day}',
                color: active ? AppColors.white : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            if (hasExpense)
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ExpenseCalendarRow extends StatelessWidget {
  const _ExpenseCalendarRow({required this.expense});
  final WalletExpense expense;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(walletExpenseTitle(expense), fontWeight: FontWeight.bold),
              const SizedBox(height: 3),
              AppText(
                walletExpenseCategoryLabel(expense),
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        AppText(walletExpenseAmountLabel(expense), fontWeight: FontWeight.bold),
      ],
    ),
  );
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
void _goBack(BuildContext context) => Navigator.of(context).maybePop();
