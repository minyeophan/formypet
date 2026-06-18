import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailHero(schedule: schedule),
                    const SizedBox(height: 12),
                    _InfoRow(
                      key: const Key('schedule-detail-info-row-place'),
                      label: '장소',
                      value: schedule.place,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      key: const Key('schedule-detail-info-row-reminder'),
                      label: '알림',
                      value: schedule.reminder,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      key: const Key('schedule-detail-info-row-memo'),
                      label: '메모',
                      value: schedule.memo,
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    _ScheduleDetailEditButton(
                      onTap: () =>
                          context.push('/routine/schedule/${schedule.id}/edit'),
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

class _DetailHero extends StatelessWidget {
  final CareSchedule schedule;

  const _DetailHero({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('schedule-detail-hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppText(
                  _categoryEmoji(schedule.categoryId),
                  fontSize: 28,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: AppText(
                        _categoryLabel(schedule.categoryId),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPressed,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppText(
                      schedule.title,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AppText(
              _dateTimeLabel(schedule),
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDetailEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScheduleDetailEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('schedule-detail-edit-button'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: const AppText(
            '수정',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = value?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
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
          AppText(
            display.isEmpty ? '-' : display,
            fontSize: 13,
            color: display.isEmpty ? AppColors.muted : AppColors.text,
          ),
        ],
      ),
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

String _categoryEmoji(String categoryId) => switch (categoryId) {
  'grooming' => '✂️',
  'hospital' => '🏥',
  'travel' => '🧳',
  'hotel' => '🏨',
  'outing' => '☕',
  'event' => '🎉',
  _ => '📌',
};

String _dateTimeLabel(CareSchedule schedule) {
  final startDate = DateTime.parse(schedule.startDate);
  final endDate = DateTime.parse(schedule.endDate);
  final startDateText = _dateLabel(startDate);
  final endDateText = _dateLabel(endDate);

  if (schedule.allDay) {
    return schedule.startDate == schedule.endDate
        ? '$startDateText 종일'
        : '$startDateText - $endDateText 종일';
  }

  final startTime = schedule.startTime;
  final endTime = schedule.endTime;
  final start = [
    startDateText,
    if (startTime != null && startTime.isNotEmpty) startTime,
  ].join(' ');
  final end = schedule.startDate == schedule.endDate
      ? endTime
      : [
          endDateText,
          if (endTime != null && endTime.isNotEmpty) endTime,
        ].join(' ');
  if (end == null || end.isEmpty) {
    return start;
  }
  return '$start - $end';
}

String _dateLabel(DateTime date) => DateFormat('M월 d일').format(date);

void _goBack(BuildContext context, {required String fallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}
