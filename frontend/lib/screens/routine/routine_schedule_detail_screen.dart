import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/care_schedule.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'routine_schedule_create_screen.dart';

class RoutineScheduleDetailScreen extends ConsumerWidget {
  final String scheduleId;

  const RoutineScheduleDetailScreen({super.key, required this.scheduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = _findSchedule(ref.watch(petProvider), scheduleId);
    if (schedule == null) {
      return const _ScheduleNotFoundScreen();
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
                  title: '일정 상세',
                  onBack: () => _goBack(context, fallback: '/routine'),
                  trailing: TextButton(
                    key: const Key('schedule-detail-edit-button'),
                    onPressed: () =>
                        context.push('/routine/schedule/${schedule.id}/edit'),
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
                    title: '일정 정보',
                    child: Column(
                      children: [
                        _ValueRow(label: '제목', value: schedule.title),
                        _ValueRow(
                          label: '카테고리',
                          value: _categoryLabel(schedule.categoryId),
                        ),
                        _ValueRow(label: '일시', value: _dateTimeLabel(schedule)),
                        _ValueRow(label: '장소', value: schedule.place),
                        _ValueRow(label: '알림', value: schedule.reminder),
                        _ValueRow(label: '메모', value: schedule.memo),
                      ],
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

class RoutineScheduleEditScreen extends ConsumerWidget {
  final String scheduleId;

  const RoutineScheduleEditScreen({super.key, required this.scheduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = _findSchedule(ref.watch(petProvider), scheduleId);
    if (schedule == null) {
      return const _ScheduleNotFoundScreen();
    }
    return RoutineScheduleCreateScreen(
      key: ValueKey(schedule.id),
      editingSchedule: schedule,
    );
  }
}

class _ScheduleNotFoundScreen extends StatelessWidget {
  const _ScheduleNotFoundScreen();

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
                title: '일정 상세',
                onBack: () => _goBack(context, fallback: '/routine'),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('schedule-detail-not-found'),
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
                          '일정을 찾을 수 없어요',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/routine'),
                          child: const AppText(
                            '루틴으로 돌아가기',
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
  final String? value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
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
          Expanded(child: _ValueBox(text: value ?? '')),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String text;

  const _ValueBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final display = text.trim();
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
        display.isEmpty ? '-' : display,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: display.isEmpty ? AppColors.muted : AppColors.text,
      ),
    );
  }
}

CareSchedule? _findSchedule(PetState state, String scheduleId) => state
    .schedules
    .where(
      (schedule) =>
          schedule.id == scheduleId && schedule.petId == state.activePetId,
    )
    .firstOrNull;

String _categoryLabel(String categoryId) => switch (categoryId) {
  'grooming' => '미용',
  'hospital' => '병원 예약',
  'travel' => '여행숙박',
  'hotel' => '호텔링',
  'outing' => '카페외출',
  'event' => '행사이벤트',
  _ => '기타',
};

String _dateTimeLabel(CareSchedule schedule) {
  if (schedule.allDay) {
    return schedule.startDate == schedule.endDate
        ? '${schedule.startDate} 종일'
        : '${schedule.startDate} - ${schedule.endDate} 종일';
  }
  final start = [
    schedule.startDate,
    schedule.startTime,
  ].whereType<String>().join(' ');
  final end = schedule.startDate == schedule.endDate
      ? schedule.endTime ?? schedule.endDate
      : [schedule.endDate, schedule.endTime].whereType<String>().join(' ');
  return '$start - $end';
}

void _goBack(BuildContext context, {required String fallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}
