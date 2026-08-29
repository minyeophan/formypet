import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/wallet_expense.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
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
  Map<String, List<WalletExpense>> _expensesByPet = const {};
  bool _isLoadingAll = false;

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
    final selectedItems = _selectedPetId == null
        ? (_expensesByPet.isEmpty
              ? [...walletState.items]
              : _expensesByPet.values.expand((items) => items).toList())
        : (_expensesByPet[_selectedPetId] ?? walletState.items);
    selectedItems.sort((a, b) => '${b.expenseDate}${b.expenseTime ?? ''}'
        .compareTo('${a.expenseDate}${a.expenseTime ?? ''}'));
    final recent = selectedItems.take(3).toList();
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
                    ),
                    const SizedBox(height: 8),
                    _WalletPetFilter(
                      pets: pets,
                      selectedPetId: _selectedPetId,
                      onChanged: (id) => setState(() => _selectedPetId = id),
                    ),
                    _WalletSummaryCard(totalAmount: _selectedPetId == null ? total : walletState.summary.totalAmount, count: selectedItems.length),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletActionButton(
                            label: '\uBE44\uC6A9 \uCD94\uAC00',
                            icon: Icons.add_rounded,
                            onTap: () => context.push('/wallet/expenses/new'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WalletActionButton(
                            label: '\uB0B4\uC5ED \uBCF4\uAE30',
                            icon: Icons.receipt_long_rounded,
                            onTap: () => context.push('/wallet/report'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const AppText(
                      '\uCD5C\uADFC \uC9C0\uCD9C',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
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
    setState(() => _isLoadingAll = true);
    final service = ref.read(walletExpenseServiceProvider);
    try {
      final entries = await Future.wait(
        pets.map((pet) async {
          final result = await service.listExpenses(pet.id);
          return MapEntry<String, List<WalletExpense>>(pet.id, result.items);
        }),
      );
      if (!mounted) return;
      setState(() => _expensesByPet = Map.fromEntries(entries));
    } finally {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }
}

class _WalletPetFilter extends StatelessWidget {
  const _WalletPetFilter({required this.pets, required this.selectedPetId, required this.onChanged});
  final List pets;
  final String? selectedPetId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _filterChip('전체', selectedPetId == null, () => onChanged(null)),
        for (final pet in pets) ...[
          const SizedBox(width: 8),
          _filterChip(pet.name, selectedPetId == pet.id, () => onChanged(pet.id)),
        ],
      ],
    ),
  );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.border),
        ),
      );
}

class _WalletSummaryCard extends StatelessWidget {
  final int totalAmount;
  final int count;

  const _WalletSummaryCard({required this.totalAmount, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            '\uB204\uC801 \uC9C0\uCD9C',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 6),
          AppText(
            formatWon(totalAmount),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 6),
          AppText(
            '$count\uAC74\uC758 \uC9C0\uCD9C \uAE30\uB85D',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
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
  final IconData icon;
  final VoidCallback onTap;

  const _WalletActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F8FCF)),
              const SizedBox(width: 7),
              AppText(
                label,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
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
                  color: const Color(0xFF4F8FCF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Color(0xFF4F8FCF),
                ),
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
                      '${expense.expenseDate} · ${walletExpenseCategoryLabel(expense)}',
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
