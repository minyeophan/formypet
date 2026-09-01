import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/record_utils.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';

class RoutineDetailScreen extends ConsumerWidget {
  final String routineId;

  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final routine = state.routines
        .where(
          (item) => item.id == routineId && item.petId == state.activePetId,
        )
        .firstOrNull;
    if (routine == null) return const _RoutineNotFoundScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '루틴 상세',
                  onBack: () => _goBack(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.list(
                children: [
                  _RoutineHero(routine: routine),
                  const SizedBox(height: 12),
                  _InfoRow(label: '시작일', value: _dateLabel(routine.startDate)),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: '종료일',
                    value: routine.endDate == null
                        ? '종료일 없음'
                        : _dateLabel(routine.endDate!),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: '시간', value: routine.times.join(', ')),
                  const SizedBox(height: 10),
                  _InfoRow(label: '반복', value: _repeatLabel(routine)),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: '알림',
                    value: routine.notificationEnabled ? '알림 사용' : '알림 사용 안 함',
                  ),
                  if ((routine.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(label: '메모', value: routine.note!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('routine-detail-edit-button'),
                      onPressed: () =>
                          context.push('/routine/${routine.id}/edit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const AppText(
                        '수정',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
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

class _RoutineHero extends StatelessWidget {
  final Routine routine;

  const _RoutineHero({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AppVisual(
              id: recordTypeVisualId(routine.typeId),
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _categoryLabel(routine.typeId),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPressed,
                ),
                const SizedBox(height: 6),
                AppText(
                  routine.label,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.muted,
          ),
          const SizedBox(height: 5),
          AppText(value, fontSize: 13, color: AppColors.text),
        ],
      ),
    );
  }
}

class _RoutineNotFoundScreen extends StatelessWidget {
  const _RoutineNotFoundScreen();

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
                title: '루틴 상세',
                onBack: () => _goBack(context),
              ),
            ),
            const Expanded(
              child: Center(
                child: AppText(
                  '루틴을 찾을 수 없어요',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(String typeId) => switch (typeId) {
  'medicine' => '투약',
  'meal' => '급식',
  'vet' => '병원 관리',
  _ => recordTypeLabel(typeId),
};

String _dateLabel(String value) =>
    DateFormat('yyyy년 M월 d일').format(DateTime.parse(value));

String _repeatLabel(Routine routine) {
  final repeat = switch (routine.repeatType) {
    'weekly' => '매주',
    'biweekly' => '격주',
    'monthly' => '매월',
    _ => '매일',
  };
  if (routine.repeatType != 'weekly' && routine.repeatType != 'biweekly') {
    return repeat;
  }
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  final selected = routine.days
      .where((day) => day >= 0 && day < weekdays.length)
      .map((day) => weekdays[day])
      .join(', ');
  return selected.isEmpty ? repeat : '$repeat · $selected';
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/routine?tab=routines');
  }
}
