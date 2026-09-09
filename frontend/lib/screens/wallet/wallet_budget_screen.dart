import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_budget_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';
import 'wallet_budget_amount_input.dart';
import 'wallet_amount_layout.dart';

class WalletBudgetScreen extends ConsumerStatefulWidget {
  final DateTime month;
  final (String?, int) identity;
  const WalletBudgetScreen({
    super.key,
    required this.month,
    required this.identity,
  });
  @override
  ConsumerState<WalletBudgetScreen> createState() => _WalletBudgetScreenState();
}

class _WalletBudgetScreenState extends ConsumerState<WalletBudgetScreen> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _accountChanged = false;
  bool _retryingExpenses = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _amount => walletAmountValue(_controller.text);
  String? get _amountError {
    if (_controller.text.trim().isEmpty) return '예산 금액을 입력해 주세요.';
    final amount = _amount;
    if (amount == null) return '올바른 예산 금액을 입력해 주세요.';
    if (amount <= 0) return '예산은 0원보다 크게 입력해 주세요.';
    if (amount > walletMaxAmount) {
      return '예산 금액이 너무 커요. 1억 원 이하로 입력해 주세요.';
    }
    return null;
  }

  bool get _current =>
      !_accountChanged &&
      widget.identity.$1 != null &&
      ref.read(walletBudgetIdentityProvider) == widget.identity;

  @override
  Widget build(BuildContext context) {
    ref.listen(walletBudgetIdentityProvider, (_, next) {
      if (next != widget.identity) {
        setState(() {
          _accountChanged = true;
          _saving = false;
          _controller.clear();
        });
      }
    });
    final identity = ref.watch(walletBudgetIdentityProvider);
    final budget = ref.watch(walletMonthlyBudgetProvider(widget.month));
    final total = ref.watch(walletBudgetExpenseProvider(widget.month));
    final pets = ref.watch(petProvider);
    final wallet = ref.watch(walletExpenseProvider);
    final expenseError =
        walletPetListError(pets) ?? wallet.errorText ?? wallet.refreshWarning;
    final current =
        !_accountChanged && identity == widget.identity && identity.$1 != null;
    if (!_initialized && !budget.isLoading && !budget.hasError && current) {
      _initialized = true;
      _controller.text = budget.valueOrNull == null
          ? ''
          : formatWon(budget.valueOrNull!);
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              AppFormHeader(
                title: '예산 설정',
                onBack: () {
                  if (!_saving) Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: !current
                    ? const Center(
                        child: AppText(
                          '계정이 변경되었어요. 예산 설정을 다시 열어 주세요.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _BudgetPageBody(
                        submitButton: SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const Key('wallet-budget-save'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed:
                                _saving || !_initialized || budget.hasError
                                ? null
                                : _save,
                            child: AppText(
                              _saving ? '저장 중…' : '예산 저장',
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        children: [
                          AppText(
                            '${widget.month.year}년 ${widget.month.month}월 예산',
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          const AppText(
                            '이달의 예산을 정해볼까요?',
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 6),
                          const AppText(
                            '선택한 달의 예산으로 저장돼요.',
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 20),
                          if (budget.isLoading && !_initialized)
                            const LinearProgressIndicator(),
                          if (budget.hasError) ...[
                            const AppText('예산 설정을 불러오지 못했어요.'),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                walletMonthlyBudgetProvider(widget.month),
                              ),
                              child: const Text('다시 시도'),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppV2Tokens.mintSurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: WalletAmountLayout(
                              controller: _controller,
                              illustrationWidth: 118,
                              inputHorizontalPadding: 36,
                              amountBuilder: (style) => TextField(
                                key: const Key('wallet-budget-input'),
                                controller: _controller,
                                enabled:
                                    !_saving &&
                                    _initialized &&
                                    !budget.hasError,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  const WalletWonInputFormatter(),
                                ],
                                onChanged: (_) =>
                                    setState(() => _error = _amountError),
                                onTapOutside: (_) =>
                                    FocusScope.of(context).unfocus(),
                                style: style,
                                decoration: const InputDecoration(
                                  filled: false,
                                  hintText: '0원',
                                  contentPadding: EdgeInsets.all(18),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                              ),
                              illustration: SvgPicture.asset(
                                'assets/illustrations/wallet_puppy_hug.svg',
                                width: 118,
                                height: 112,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AppText(
                                _error!,
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              for (final entry in [
                                (10000, '+1만원'),
                                (50000, '+5만원'),
                                (100000, '+10만원'),
                              ]) ...[
                                if (entry.$1 != 10000)
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primaryPressed,
                                        padding: EdgeInsets.zero,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed:
                                          _saving ||
                                              !_initialized ||
                                              budget.hasError
                                          ? null
                                          : () {
                                              final value =
                                                  (_amount ?? 0) + entry.$1;
                                              if (value > walletMaxAmount) {
                                                setState(
                                                  () => _error =
                                                      '예산 금액이 너무 커요. 1억 원 이하로 입력해 주세요.',
                                                );
                                                return;
                                              }
                                              setState(() {
                                                _controller.text = formatWon(
                                                  value,
                                                );
                                                _error = null;
                                              });
                                            },
                                      child: AppText(
                                        entry.$2,
                                        fontSize: 14,
                                        color: AppColors.primaryPressed,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _BudgetValue(
                                  label: '이번 달 지출',
                                  value: total == null ? '—' : formatWon(total),
                                ),
                                const SizedBox(height: 20),
                                _BudgetValue(
                                  label:
                                      total != null &&
                                          (_amount ?? 0) > 0 &&
                                          total > _amount!
                                      ? '초과 예산'
                                      : '남은 예산',
                                  value:
                                      total == null ||
                                          (_amount ?? 0) <= 0 ||
                                          _amount! > walletMaxAmount
                                      ? '—'
                                      : formatWon((_amount! - total).abs()),
                                  primary: true,
                                ),
                                const SizedBox(height: 20),
                                WalletBudgetProgress(
                                  budget: _amount,
                                  total: total,
                                ),
                                if (total == null || expenseError != null) ...[
                                  const SizedBox(height: 12),
                                  AppText(
                                    expenseError == null
                                        ? '전체 반려동물의 지출을 확인하고 있어요.'
                                        : total == null
                                        ? '지출 정보를 불러오지 못했어요.'
                                        : '지출 정보를 새로고침하지 못했어요. 최근 저장된 지출을 표시하고 있어요.',
                                    fontSize: 12,
                                  ),
                                  if (expenseError != null)
                                    TextButton(
                                      onPressed:
                                          _retryingExpenses ||
                                              pets.isLoading ||
                                              wallet.isLoadingAll ||
                                              wallet.isLoading
                                          ? null
                                          : _retryExpenses,
                                      child: const Text('다시 시도'),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const AppText(
                            '예산은 전체 반려동물의 월 지출을 기준으로 해요.',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryExpenses() async {
    if (_retryingExpenses || !_current) return;
    final petNotifier = ref.read(petProvider.notifier);
    bool current() =>
        mounted &&
        _current &&
        identical(ref.read(petProvider.notifier), petNotifier);
    setState(() => _retryingExpenses = true);
    try {
      if (walletPetListError(ref.read(petProvider)) != null) {
        await petNotifier.refreshPets();
        if (!current()) return;
        final pets = ref.read(petProvider);
        if (!pets.isLoading && walletPetListError(pets) != null) {
          await petNotifier.retryDataLoad();
        }
      }
      if (!current()) return;
      final pets = ref.read(petProvider);
      if (pets.isLoading || walletPetListError(pets) != null) return;
      await ref
          .read(walletExpenseProvider.notifier)
          .refreshWallet(pets.pets.map((p) => p.id).toList());
    } catch (_) {
      /* Existing providers expose the retry error. */
    } finally {
      if (mounted) setState(() => _retryingExpenses = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_current || !_initialized) return;
    final validationError = _amountError;
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    final amount = _amount!;
    setState(() {
      _saving = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(walletBudgetServiceProvider)
          .save(widget.identity.$1!, widget.month, amount);
      if (!mounted || !_current) return;
      ref.invalidate(walletMonthlyBudgetProvider(widget.month));
      // Unlock PopScope before programmatic pop.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _current) Navigator.of(context).pop();
      });
    } catch (_) {
      if (mounted && _current) {
        setState(() {
          _saving = false;
          _error = '예산을 저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }
}

/// Keep the primary action within Scaffold's keyboard-resized body.
class _BudgetPageBody extends StatelessWidget {
  final List<Widget> children;
  final Widget submitButton;
  const _BudgetPageBody({required this.children, required this.submitButton});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(width: double.infinity, child: submitButton),
      ),
    ],
  );
}

class WalletBudgetProgress extends StatelessWidget {
  final int? budget, total;
  const WalletBudgetProgress({
    super.key,
    required this.budget,
    required this.total,
  });
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value:
        total == null ||
            budget == null ||
            budget! <= 0 ||
            budget! > walletMaxAmount
        ? 0
        : (total! / budget!).clamp(0.0, 1.0),
    color: AppColors.primary,
    backgroundColor: AppColors.border,
    minHeight: 8,
    borderRadius: BorderRadius.circular(8),
  );
}

class _BudgetValue extends StatelessWidget {
  final String label, value;
  final bool primary;
  const _BudgetValue({
    required this.label,
    required this.value,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: AppText(label, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AppText(
            value,
            fontSize: primary ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: primary ? AppColors.primaryPressed : AppColors.text,
          ),
        ),
      ),
    ],
  );
}
