import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../providers/wallet_view_provider.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';
import 'wallet_widgets.dart';

class WalletBudgetCard extends StatefulWidget {
  final WalletViewData data;
  const WalletBudgetCard({super.key, required this.data});
  @override
  State<WalletBudgetCard> createState() => _WalletBudgetCardState();
}

class _WalletBudgetCardState extends State<WalletBudgetCard> {
  int? _budget;
  bool _loaded = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          final value = prefs.getInt('wallet_monthly_budget');
          _budget = value != null && value > 0 ? value : null;
          _loaded = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '예산 설정을 불러오지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.data.amounts.budgetTotal;
    final available = widget.data.budgetAvailable;
    final budget = _budget;
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              const AppText(
                '이번 달 예산',
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              TextButton(
                onPressed: _edit,
                child: Text(budget == null ? '예산 설정' : '예산 변경'),
              ),
            ],
          ),
          const AppText(
            '전체 반려동물 기준',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            AppText(_error!),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ] else if (!_loaded)
            const LinearProgressIndicator()
          else if (budget == null)
            const AppText(
              '월 예산을 설정해 지출을 관리해 보세요.',
              color: AppColors.textSecondary,
            )
          else ...[
            AppText('월 예산 ${formatWon(budget)}', fontWeight: FontWeight.w600),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: available ? (total / budget).clamp(0.0, 1.0) : 0,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 12),
            AppText(available ? '사용 ${formatWon(total)}' : '사용 —'),
            if (available)
              AppText(
                total > budget
                    ? '${formatWon(total - budget)} 초과'
                    : '잔액 ${formatWon(budget - total)}',
                color: AppColors.textSecondary,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _BudgetDialog(initial: _budget),
    );
    if (!mounted || value == null) return;
    setState(() {
      _budget = value;
      _loaded = true;
      _error = null;
    });
  }
}

class _BudgetDialog extends StatefulWidget {
  final int? initial;
  const _BudgetDialog({this.initial});
  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('이번 달 예산'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('전체 반려동물의 이번 달 지출 기준이에요.'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('wallet-budget-input'),
              controller: _controller,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                labelText: '예산 금액',
                suffixText: '원',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final value = int.tryParse(_controller.text);
                  if (value == null || value <= 0 || value > 999999999) {
                    setState(() => _error = '1원 이상의 금액을 입력해 주세요.');
                    return;
                  }
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    if (!await prefs.setInt('wallet_monthly_budget', value)) {
                      throw StateError('budget not saved');
                    }
                    if (context.mounted) Navigator.pop(context, value);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        _saving = false;
                        _error = '예산을 저장하지 못했어요.';
                      });
                    }
                  }
                },
          child: Text(_saving ? '저장 중…' : '저장'),
        ),
      ],
    ),
  );
}
