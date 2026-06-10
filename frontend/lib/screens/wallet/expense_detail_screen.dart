import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'expense_record_utils.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String recordId;

  const ExpenseDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  var _deleting = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final record = state.records
        .where(
          (candidate) =>
              candidate.id == widget.recordId &&
              candidate.petId == state.activePetId &&
              candidate.typeId == 'expense',
        )
        .firstOrNull;

    if (record == null) {
      return const _ExpenseNotFoundScreen();
    }

    final itemName = record.detail['itemName']?.toString().trim();
    final note = record.note?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '지출 상세',
                  onBack: () => _goBack(context),
                  trailing: TextButton(
                    key: const Key('expense-detail-edit-button'),
                    onPressed: () =>
                        context.push('/wallet/expenses/${record.id}/edit'),
                    child: const AppText(
                      '수정',
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
                  _SectionBlock(
                    title: '날짜/시간',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ValueBox(
                            key: const Key('expense-detail-date-label'),
                            text: record.date,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ValueBox(
                            key: const Key('expense-detail-time-label'),
                            text: normalizeExpenseTime(record.time),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionBlock(
                    title: '지출 정보',
                    child: Column(
                      children: [
                        _ValueRow(
                          label: '금액',
                          value: expenseAmountLabel(record),
                        ),
                        _ValueRow(
                          label: '카테고리',
                          value: expenseCategoryLabel(record),
                        ),
                        if (itemName != null && itemName.isNotEmpty)
                          _ValueRow(label: '항목명', value: itemName),
                        if (note != null && note.isNotEmpty)
                          _ValueRow(label: '메모', value: note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorText != null) ...[
                    _InlineError(text: _errorText!),
                    const SizedBox(height: 12),
                  ],
                  _DetailActionButton(
                    deleting: _deleting,
                    onTap: _deleting ? null : () => _confirmDelete(record),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ActivityRecord record) async {
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
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  '지출 기록을 삭제할까요?',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                const SizedBox(height: 8),
                const AppText(
                  '삭제한 기록은 되돌릴 수 없어요.',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                _SheetButton(
                  key: const Key('expense-delete-confirm-button'),
                  label: '삭제',
                  danger: true,
                  onTap: () => context.pop(true),
                ),
                const SizedBox(height: 8),
                _SheetButton(
                  label: '취소',
                  danger: false,
                  onTap: () => context.pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _delete(record.id);
    }
  }

  Future<void> _delete(String recordId) async {
    setState(() {
      _deleting = true;
      _errorText = null;
    });

    try {
      await ref.read(petProvider.notifier).deleteRecord(recordId);
      if (!mounted) return;
      context.go('/wallet');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorText = '지출 기록을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }
}

class _ExpenseNotFoundScreen extends StatelessWidget {
  const _ExpenseNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppInlineHeader(
                title: '지출 상세',
                onBack: () => _goBack(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('expense-detail-not-found'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText(
                          '지출 기록을 찾을 수 없어요',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const Key('expense-not-found-wallet-button'),
                          onPressed: () => context.go('/wallet'),
                          child: const AppText(
                            '지갑으로 돌아가기',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AppText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(child: _ValueBox(text: value)),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String text;

  const _ValueBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        value.isEmpty ? '-' : value,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: value.isEmpty ? AppColors.muted : AppColors.text,
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(14),
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppText(
                  '지출 삭제',
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
