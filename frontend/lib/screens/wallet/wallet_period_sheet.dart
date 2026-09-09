import '../../core/app_interaction_style.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text.dart';
import 'wallet_expense_utils.dart';

typedef WalletPeriodSelection = ({WalletPeriod period, DateTime month});

Future<WalletPeriodSelection?> showWalletPeriodSheet(
  BuildContext context, {
  required WalletPeriod period,
  required DateTime month,
}) => showModalBottomSheet<WalletPeriodSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  barrierColor: AppColors.text.withValues(alpha: .32),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _PeriodSheet(period: period, month: month),
);

class _PeriodSheet extends StatefulWidget {
  final WalletPeriod period;
  final DateTime month;
  const _PeriodSheet({required this.period, required this.month});
  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late WalletPeriod _period = widget.period;
  late DateTime _month = widget.month;
  final _today = DateTime.now();

  String get _summary => switch (_period) {
    WalletPeriod.all => '선택 기간 · 전체 기간',
    WalletPeriod.year => '선택 기간 · ${_today.year}년',
    WalletPeriod.month =>
      '${DateFormat('yyyy.MM.dd').format(_month)} – ${DateFormat('yyyy.MM.dd').format(DateTime(_month.year, _month.month + 1, 0))}',
  };

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final maxHeight = MediaQuery.sizeOf(context).height * .9;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: math.min(550 + math.max(0, scale - 1) * 180, maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppText(
                        '기간 설정',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 16),
                      const AppText(
                        '보고 싶은 지출 기간을 선택해주세요.',
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (final entry in const {
                            WalletPeriod.all: '전체 기간',
                            WalletPeriod.year: '올해',
                            WalletPeriod.month: '월별',
                          }.entries)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: entry.key == WalletPeriod.month
                                      ? 0
                                      : 8,
                                ),
                                child: _SheetChoice(
                                  label: entry.value,
                                  selected: _period == entry.key,
                                  onTap: () =>
                                      setState(() => _period = entry.key),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_period == WalletPeriod.month) ...[
                        Row(
                          children: [
                            IconButton(
                              tooltip: '이전 연도',
                              onPressed: _month.year <= 1
                                  ? null
                                  : () => setState(
                                      () => _month = DateTime(
                                        _month.year - 1,
                                        _month.month,
                                      ),
                                    ),
                              icon: const AppIcon(
                                Icons.chevron_left_rounded,
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: AppText(
                                '${_month.year}년',
                                textAlign: TextAlign.center,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              tooltip: '다음 연도',
                              onPressed: _month.year >= 9998
                                  ? null
                                  : () => setState(
                                      () => _month = DateTime(
                                        _month.year + 1,
                                        _month.month,
                                      ),
                                    ),
                              icon: const AppIcon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var row = 0; row < 3; row++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                for (var column = 0; column < 4; column++)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: column == 3 ? 0 : 8,
                                      ),
                                      child: _SheetChoice(
                                        label: '${row * 4 + column + 1}월',
                                        selected:
                                            _month.month ==
                                            row * 4 + column + 1,
                                        onTap: () => setState(
                                          () => _month = DateTime(
                                            _month.year,
                                            row * 4 + column + 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ] else
                        Container(
                          constraints: const BoxConstraints(minHeight: 180),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppV2Tokens.mintSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppText(
                                _period == WalletPeriod.year
                                    ? '${_today.year}년 전체 지출'
                                    : '등록된 모든 지출',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              AppText(
                                _period == WalletPeriod.year
                                    ? '${_today.year}.01.01 – ${_today.year}.12.31'
                                    : '기간 제한 없이 한눈에 확인해요.',
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppText(
                _summary,
                textAlign: TextAlign.center,
                color: AppColors.primary,
                fontSize: 14,
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                onPressed: () =>
                    Navigator.pop(context, (period: _period, month: _month)),
                child: const Text('적용하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SheetChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected ? AppColors.primary : AppColors.surfaceSoft,
        foregroundColor: selected ? AppColors.white : AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ).copyWith(overlayColor: AppInteractionStyle.overlay()),
      child: AppText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selected ? AppColors.white : AppColors.text,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
