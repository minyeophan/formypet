import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_underline_tabs.dart';
import 'wallet_expense_utils.dart';

class ExpenseWalletScreen extends ConsumerStatefulWidget {
  const ExpenseWalletScreen({super.key});

  @override
  ConsumerState<ExpenseWalletScreen> createState() =>
      _ExpenseWalletScreenState();
}

class _ExpenseWalletScreenState extends ConsumerState<ExpenseWalletScreen> {
  String? _loadedPetId;
  String? _selectedPetId;
  String? _selectedCategory;
  Map<String, List<WalletExpense>> _expensesByPet = const {};
  int? _monthlyBudget;
  String _totalPeriod = 'all';

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _monthlyBudget = prefs.getInt('wallet_monthly_budget'));
  }

  @override
  Widget build(BuildContext context) {
    final activePetId = ref.watch(petProvider).activePetId;
    final pets = ref.watch(petProvider).pets;
    if (activePetId != null && activePetId != _loadedPetId) {
      _loadedPetId = activePetId;
      _selectedPetId = null;
      Future.microtask(
        () async {
          try {
            await ref.read(walletExpenseProvider.notifier).loadFirstPage(activePetId);
            await _loadExpensesForPets(pets);
          } catch (_) {}
        },
      );
    }

    final walletState = ref.watch(walletExpenseProvider);
    final petItems = _selectedPetId == null
        ? (_expensesByPet.isEmpty
              ? [...walletState.items]
              : _expensesByPet.values.expand((items) => items).toList())
        : (_expensesByPet[_selectedPetId] ?? walletState.items);
    final selectedItems = petItems.where((item) => _selectedCategory == null || item.category == _selectedCategory).toList();
    final now = DateTime.now();
    final monthlyTotal = selectedItems.where((item) {
      final date = DateTime.tryParse(item.expenseDate);
      return date != null && date.year == now.year && date.month == now.month;
    }).fold<int>(0, (sum, item) => sum + item.amount);
    selectedItems.removeWhere((item) {
      final date = DateTime.tryParse(item.expenseDate);
      if (date == null || _totalPeriod == 'all') return false;
      if (_totalPeriod == 'year') return date.year != now.year;
      return date.year != now.year || date.month != now.month;
    });
    selectedItems.sort((a, b) => '${b.expenseDate}${b.expenseTime ?? ''}'
        .compareTo('${a.expenseDate}${a.expenseTime ?? ''}'));
    final recent = selectedItems.take(5).toList();
    final total = selectedItems.fold<int>(0, (sum, item) => sum + item.amount);

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
                      title: '\uC9D1\uC0AC\uC758 \uC9C0\uAC11',
                      onBack: () => _goBack(context),
                      trailing: TextButton(
                        onPressed: () => context.push('/wallet/report'),
                        child: const Text('\uC804\uCCB4\uBCF4\uAE30'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _WalletPetSelector(
                      key: const Key('wallet-pet-selector'),
                      items: ['전체', ...pets.map((pet) => pet.name)],
                      selectedIndex: _selectedPetId == null
                          ? 0
                          : pets.indexWhere((pet) => pet.id == _selectedPetId) + 1,
                      onChanged: (index) => setState(() {
                        _selectedPetId = index == 0 ? null : pets[index - 1].id;
                      }),
                    ),
                    const SizedBox(height: 12),
                    AppUnderlineTabs(
                      items: ['전체', ...expenseCategoryOptions.map((item) => item.label)],
                      selectedIndex: _selectedCategory == null ? 0 : expenseCategoryOptions.indexWhere((item) => item.key == _selectedCategory) + 1,
                      onChanged: (index) => setState(() => _selectedCategory = index == 0 ? null : expenseCategoryOptions[index - 1].key),
                    ),
                    _WalletSummaryCard(
                      totalAmount: total,
                      monthlyTotal: monthlyTotal,
                      budget: _monthlyBudget,
                      count: selectedItems.length,
                      isOverBudget: _monthlyBudget != null && total > _monthlyBudget!,
                      onBudgetTap: _editBudget,
                    ),
                    if (walletState.isLoading) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (!walletState.isLoading && walletState.errorText != null) ...[
                      const SizedBox(height: 12),
                      _WalletErrorPanel(
                        onRetry: () => ref
                            .read(walletExpenseProvider.notifier)
                            .loadFirstPage(activePetId!),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: AppText('\uCD5C\uADFC \uBE44\uC6A9', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _totalPeriod,
                            isDense: true,
                            selectedItemBuilder: (_) => const [
                              Text('\uAE30\uAC04 \uC120\uD0DD'),
                              Text('\uAE30\uAC04 \uC120\uD0DD'),
                              Text('\uAE30\uAC04 \uC120\uD0DD'),
                            ],
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('\uC804\uCCB4 \uAE30\uAC04')),
                              DropdownMenuItem(value: 'year', child: Text('\uC62C\uD574 \uC9C0\uCD9C')),
                              DropdownMenuItem(value: 'month', child: Text('\uC774\uBC88 \uB2EC \uC9C0\uCD9C')),
                            ],
                            onChanged: (value) => setState(() => _totalPeriod = value ?? 'all'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (recent.isEmpty)
                      const _ExpenseEmptyPanel(
                        message:
                            '\uC544\uC9C1 \uC9C0\uCD9C \uAE30\uB85D\uC774 \uC5C6\uC5B4\uC694',
                      )
                    else
                      for (final expense in recent)
                        _ExpenseListRow(expense: expense),
                    const SizedBox(height: 14),
                    _WalletActionButton(
                      label: '\uBE44\uC6A9 \uCD94\uAC00',
                      onTap: () => context.push('/wallet/expenses/new'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadExpensesForPets(List pets) async {
    if (pets.isEmpty) return;
    final service = ref.read(walletExpenseServiceProvider);
    final entries = await Future.wait(
      pets.map((pet) async {
        final result = await service.listExpenses(pet.id);
        return MapEntry<String, List<WalletExpense>>(pet.id, result.items);
      }),
    );
    if (!mounted) return;
    setState(() => _expensesByPet = Map.fromEntries(entries));
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(text: _monthlyBudget?.toString() ?? '');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이번 달 예산'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '금액을 입력해 주세요', suffixText: '원')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('건너뛰기'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text.replaceAll(',', '').trim())), child: const Text('저장')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wallet_monthly_budget', value);
    if (mounted) setState(() => _monthlyBudget = value);
  }
}

class _WalletPetSelector extends StatelessWidget {
  const _WalletPetSelector({super.key, required this.items, required this.selectedIndex, required this.onChanged});
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onChanged(index),
        child: Container(
          constraints: const BoxConstraints(minWidth: 82),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index == selectedIndex ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: index == selectedIndex ? AppColors.primary : AppColors.border),
          ),
          child: AppText(items[index], fontSize: 12, fontWeight: FontWeight.bold, color: index == selectedIndex ? AppColors.white : AppColors.text),
        ),
      ),
    ),
  );
}

class _WalletSummaryCard extends StatelessWidget {
  final int totalAmount;
  final int monthlyTotal;
  final int? budget;
  final int count;
  final VoidCallback onBudgetTap;
  final bool isOverBudget;

  const _WalletSummaryCard({required this.totalAmount, required this.monthlyTotal, required this.budget, required this.count, required this.onBudgetTap, required this.isOverBudget});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBudgetTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(32),
            bottomLeft: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.border),
        ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _SummaryValue(label: '\uCD1D \uC9C0\uCD9C', value: formatWon(totalAmount), accent: true)),
                Container(width: 1, height: 58, color: AppColors.border),
                Expanded(child: _SummaryValue(label: '\uC774\uBC88 \uB2EC', value: formatWon(monthlyTotal), accent: false)),
              ],
            ),
            const SizedBox(height: 10),
            Center(child: AppText(budget == null ? '$count\uAC74 · \uC608\uC0B0\uC744 \uB204\uB974\uBA74 \uC124\uC815\uD560 \uC218 \uC788\uC5B4\uC694' : '\uC6D4 \uC608\uC0B0 ${formatWon(budget!)}', fontSize: 11, color: AppColors.textSecondary)),
            if (isOverBudget) ...[
              const SizedBox(height: 6),
              const Center(child: AppText('\uC608\uC0B0\uC744 \uCD08\uACFC\uD588\uC5B4\uC694', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppText(label, fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
      const SizedBox(height: 7),
      AppText(value, fontSize: 22, fontWeight: FontWeight.bold, color: accent ? AppColors.primary : AppColors.text),
    ],
  );
}

class _WalletErrorPanel extends StatelessWidget {
  final VoidCallback onRetry;

  const _WalletErrorPanel({required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('wallet-error-panel'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Expanded(child: AppText('지출을 불러오지 못했어요.')),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _WalletActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _WalletActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppText(
                label,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseListRow extends StatefulWidget {
  final WalletExpense expense;

  const _ExpenseListRow({required this.expense});

  @override
  State<_ExpenseListRow> createState() => _ExpenseListRowState();
}

class _ExpenseListRowState extends State<_ExpenseListRow> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    return Material(
      key: Key('wallet-expense-row-${expense.id}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/wallet/expenses/${expense.id}'),
        onFocusChange: (isFocused) {
          if (_isFocused == isFocused) return;
          setState(() => _isFocused = isFocused);
        },
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: AppColors.text.withValues(alpha: 0.06),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused ? AppColors.textSecondary : AppColors.border,
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_walletExpenseEmoji(expense.category), style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      walletExpenseTitle(expense),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      expense.expenseDate,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppText(
                walletExpenseAmountLabel(expense),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseEmptyPanel extends StatelessWidget {
  final String message;

  const _ExpenseEmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        message,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/home');
}

String _walletExpenseEmoji(String category) => switch (category) {
  'food' => '🍚',
  'snack' => '🦴',
  'vet' || 'hospital' => '🏥',
  'medicine' || 'medication' => '💊',
  'grooming' => '✂️',
  _ => '🧾',
};
