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
import 'routine_calendar_values.dart';
import 'routine_refresh_notice.dart';

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
    if (routine == null) {
      if (state.isLoading || state.dataErrorText != null) {
        return RoutineLookupStatusScreen(
          title: '루틴 상세',
          fallback: '/routine?tab=routines',
        );
      }
      return const _RoutineNotFoundScreen();
    }

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
                  const RoutineRefreshNotice(),
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
                  _InfoRow(
                    label: '시간',
                    value: routine.times.isEmpty
                        ? '시간 없음'
                        : ([...routine.times]..sort()).join('\n'),
                  ),
                  const Text('시간별로 알림을 받아요. 완료는 하루 단위로 기록해요.'),
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

/// Shared by routine and schedule routes while their initial lookup is unresolved.
class RoutineLookupStatusScreen extends ConsumerStatefulWidget {
  final String title;
  final String fallback;
  const RoutineLookupStatusScreen({
    super.key,
    required this.title,
    required this.fallback,
  });

  @override
  ConsumerState<RoutineLookupStatusScreen> createState() =>
      _RoutineLookupStatusScreenState();
}

class _RoutineLookupStatusScreenState
    extends ConsumerState<RoutineLookupStatusScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await ref.read(petProvider.notifier).retryDataLoad();
    } catch (_) {
      // The provider publishes the load error for the next retry.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppInlineHeader(
                title: widget.title,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(widget.fallback);
                  }
                },
              ),
            ),
            Expanded(
              child: Center(
                child: state.isLoading || _retrying
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.dataErrorText ?? '정보를 불러오지 못했어요.',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _retry,
                              child: const Text('다시 시도'),
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
          SizedBox(
            width: 52,
            height: 52,

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

String _repeatLabel(Routine routine) => routineRepeatLabel(routine);

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/routine?tab=routines');
  }
}
