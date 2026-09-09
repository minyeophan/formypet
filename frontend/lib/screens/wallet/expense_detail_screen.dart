import 'package:dio/dio.dart';
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
import 'expense_form.dart';
import 'wallet_refresh_notice.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  final String? petId;

  const ExpenseDetailScreen({super.key, required this.expenseId, this.petId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  var _deleting = false;
  var _confirming = false;
  int? _session;
  String? _ownerPetId;
  String? _errorText;
  Future<WalletExpense>? _expenseFuture;
  (int, String, String)? _expenseKey;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petProvider);
    final wallet = ref.watch(walletExpenseProvider);
    if (_session != wallet.session) {
      _session = wallet.session;
      _ownerPetId = widget.petId;
      _expenseKey = null;
      _expenseFuture = null;
      _deleting = false;
      _confirming = false;
      _errorText = null;
    }
    if (pets.isLoading) {
      return const ExpenseLoadScreen(loading: true);
    }
    _ownerPetId ??= pets.activePetId;
    final petId = widget.petId ?? _ownerPetId;
    if (petId == null || !pets.pets.any((pet) => pet.id == petId)) {
      return ExpenseLoadScreen(
        error: pets.dataErrorText,
        onRetry: pets.dataErrorText == null
            ? null
            : () => ref.read(petProvider.notifier).refreshPets(),
      );
    }
    final expenseKey = (wallet.session, petId, widget.expenseId);
    if (_expenseKey != expenseKey) {
      _expenseKey = expenseKey;
      _expenseFuture = null;
      _deleting = false;
      _errorText = null;
    }
    _expenseFuture ??= ref
        .read(walletExpenseProvider.notifier)
        .getExpense(petId, widget.expenseId);

    return FutureBuilder<WalletExpense>(
      future: _expenseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ExpenseLoadScreen(loading: true);
        }
        if (!snapshot.hasData) {
          return ExpenseLoadScreen(
            error: snapshot.error,
            onRetry: () => setState(() => _expenseFuture = null),
          );
        }
        final matchingPets = ref
            .read(petProvider)
            .pets
            .where((pet) => pet.id == petId)
            .toList();
        return _ExpenseDetailBody(
          expense:
              [...?wallet.expensesByPet[petId], ...wallet.items]
                  .where(
                    (item) =>
                        item.id == widget.expenseId && item.petId == petId,
                  )
                  .firstOrNull ??
              snapshot.data!,
          petName: matchingPets.isEmpty ? null : matchingPets.first.name,
          deleting: _deleting,
          busy: _deleting || _confirming,
          errorText: _errorText,
          onDelete: _deleting || _confirming ? null : _confirmDelete,
        );
      },
    );
  }

  Future<void> _confirmDelete(WalletExpense expense) async {
    if (_deleting || _confirming) return;
    final session = ref.read(walletExpenseProvider).session;
    final expenseKey = _expenseKey;
    setState(() => _confirming = true);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uC0AD\uC81C\uD560\uAE4C\uC694?',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                const SizedBox(height: 8),
                const AppText(
                  '\uC0AD\uC81C\uD55C \uAE30\uB85D\uC740 \uB418\uB3CC\uB9B4 \uC218 \uC5C6\uC5B4\uC694.',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                _SheetButton(
                  key: const Key('expense-delete-confirm-button'),
                  label: '\uC0AD\uC81C',
                  danger: true,
                  onTap: () => context.pop(true),
                ),
                const SizedBox(height: 8),
                _SheetButton(
                  label: '\uCDE8\uC18C',
                  danger: false,
                  onTap: () => context.pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted ||
        ref.read(walletExpenseProvider).session != session ||
        expenseKey != _expenseKey) {
      return;
    }
    setState(() => _confirming = false);
    if (confirmed == true) await _delete(expense);
  }

  Future<void> _delete(WalletExpense expense) async {
    if (_deleting || _session != ref.read(walletExpenseProvider).session) {
      return;
    }
    final petId = expense.petId;
    if (ref.read(petProvider).isLoading ||
        !ref.read(petProvider).pets.any((pet) => pet.id == petId)) {
      return;
    }
    final session = ref.read(walletExpenseProvider).session;
    setState(() {
      _deleting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(walletExpenseProvider.notifier)
          .deleteExpense(petId, expense.id);
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
      showWalletRefreshWarning(context, ref.read(walletExpenseProvider));
      context.go('/wallet');
    } catch (_) {
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
      setState(() {
        _deleting = false;
        _errorText =
            '\uC9C0\uCD9C \uAE30\uB85D\uC744 \uC0AD\uC81C\uD558\uC9C0 \uBABB\uD588\uC5B4\uC694. \uC7A0\uC2DC \uD6C4 \uB2E4\uC2DC \uC2DC\uB3C4\uD574 \uC8FC\uC138\uC694.';
      });
    }
  }
}

class _ExpenseDetailBody extends StatelessWidget {
  final WalletExpense expense;
  final String? petName;
  final bool deleting;
  final bool busy;
  final String? errorText;
  final ValueChanged<WalletExpense>? onDelete;

  const _ExpenseDetailBody({
    required this.expense,
    required this.petName,
    required this.deleting,
    required this.busy,
    required this.errorText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemName = expense.itemName?.trim();
    final note = expense.note?.trim();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '\uC9C0\uCD9C \uC0C1\uC138',
                  onBack: () => _goBack(context),
                  trailing: TextButton(
                    key: const Key('expense-detail-edit-button'),
                    onPressed: busy
                        ? null
                        : () => context.push(
                            '/wallet/expenses/${expense.id}/edit?petId=${Uri.encodeQueryComponent(expense.petId)}',
                          ),
                    child: const AppText(
                      '\uC218\uC815',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.list(
                children: [
                  Column(
                    key: const Key('expense-detail-hero'),
                    children: [
                      ExpenseCategoryVisual(
                        category: expense.category,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        walletExpenseCategoryLabel(expense),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        walletExpenseAmountLabel(expense),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      if (itemName?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        AppText(
                          itemName!,
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ValueRow(
                    key: const Key('expense-detail-pet-row'),
                    label: '반려동물',
                    value: petName ?? '-',
                  ),
                  const SizedBox(height: 24),
                  _SectionBlock(
                    title: '날짜/시간',
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        AppText(
                          expense.expenseDate,
                          key: const Key('expense-detail-date-label'),
                          fontSize: 15,
                          color: AppColors.text,
                        ),
                        AppText(
                          normalizeExpenseTime(expense.expenseTime),
                          key: const Key('expense-detail-time-label'),
                          fontSize: 15,
                          color: AppColors.text,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionBlock(
                    title: '메모',
                    child: AppText(
                      note?.isNotEmpty == true ? note! : '-',
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (errorText != null) ...[
                    _InlineError(text: errorText!),
                    const SizedBox(height: 12),
                  ],
                  _DetailActionButton(
                    deleting: deleting,
                    onTap: onDelete == null ? null : () => onDelete!(expense),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared loading, not-found and retry states for detail and edit.
class ExpenseLoadScreen extends StatelessWidget {
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;
  final String title;
  final VoidCallback? onBack;

  const ExpenseLoadScreen({
    super.key,
    this.loading = false,
    this.error,
    this.onRetry,
    this.title = '지출 상세',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final missing =
        error == null ||
        (error is DioException &&
            (error as DioException).response?.statusCode == 404);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(
              title: title,
              onBack: onBack ?? () => _goBack(context),
            ),
            Expanded(
              child: Center(
                child: loading
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              missing ? '지출 기록을 찾을 수 없어요' : '지출 정보를 불러오지 못했어요.',
                              key: Key(
                                missing
                                    ? 'expense-detail-not-found'
                                    : 'expense-load-error',
                              ),
                              fontSize: 15,
                              color: AppColors.text,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (!missing && onRetry != null)
                              TextButton(
                                onPressed: onRetry,
                                child: const Text('다시 시도'),
                              )
                            else
                              TextButton(
                                key: const Key(
                                  'expense-not-found-wallet-button',
                                ),
                                onPressed: () => context.go('/wallet'),
                                child: const Text('지갑으로 돌아가기'),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _ValueRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppText(
        label,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
      ),
      const SizedBox(height: 10),
      AppText(value, fontSize: 15, color: AppColors.textSecondary),
    ],
  );
}

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('expense-delete-error'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: AppText(
        text,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFB91C1C),
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  final bool deleting;
  final VoidCallback? onTap;

  const _DetailActionButton({required this.deleting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('expense-delete-button'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppText(
                  '\uC9C0\uCD9C \uC0AD\uC81C',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C),
                ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SheetButton({
    super.key,
    required this.label,
    required this.danger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? const Color(0xFFFFF1F2) : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: danger ? const Color(0xFFFECACA) : AppColors.border,
            ),
          ),
          child: AppText(
            label,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: danger ? const Color(0xFFB91C1C) : AppColors.text,
          ),
        ),
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/wallet');
}
