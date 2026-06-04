import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/pet_colors.dart';
import '../../models/activity_record.dart';
import '../../models/pet.dart';
import '../../models/routine.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';

const _appName = 'petyilgi';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final pet = state.activePet;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeIndex = state.pets.indexWhere((p) => p.id == state.activePetId);
    final pageIndex = activeIndex < 0 ? 0 : activeIndex;
    _pageController ??= PageController(initialPage: pageIndex);
    _syncPageController(pageIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: pet == null
            ? const _EmptyHome()
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HomeHeader(),
                        _PetProfilePager(
                          pets: state.pets,
                          pageController: _pageController!,
                          activeIndex: pageIndex,
                          onPageChanged: (index) {
                            if (index < 0 || index >= state.pets.length) {
                              return;
                            }
                            final nextPet = state.pets[index];
                            if (nextPet.id == state.activePetId) {
                              return;
                            }
                            ref
                                .read(petProvider.notifier)
                                .setActivePet(nextPet.id);
                          },
                        ),
                        _HomeMenuGrid(
                          onScheduleTap: () => showPreparingToast(context),
                          onCategoryTap: () => showPreparingToast(context),
                        ),
                        const SizedBox(height: 14),
                        _TodayCareSection(
                          items: state.todayRoutineItems,
                          completions: state.routineCompletions,
                          records: state.records,
                          onToggle: (routineId, date) => ref
                              .read(petProvider.notifier)
                              .toggleRoutineCompletion(routineId, date),
                        ),
                        const SizedBox(height: 14),
                        _HealthSummarySection(records: state.records),
                        const SizedBox(
                          key: Key('home-bottom-spacer'),
                          height: 96,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _syncPageController(int activeIndex) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final currentPage = controller.page?.round() ?? controller.initialPage;
    if (currentPage == activeIndex) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) {
        controller.jumpToPage(activeIndex);
      }
    });
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
      child: Row(
        children: [
          const Expanded(
            child: AppText(
              _appName,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox.square(
            dimension: 48,
            child: Center(
              child: AppHeaderIconButton(
                key: Key('home-notification-button'),
                icon: Icons.notifications_none_rounded,
                tooltip: '알림',
                onTap: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetProfilePager extends StatelessWidget {
  final List<Pet> pets;
  final PageController pageController;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;

  const _PetProfilePager({
    required this.pets,
    required this.pageController,
    required this.activeIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: pageController,
            itemCount: pets.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) => _PetProfileCard(pet: pets[index]),
          ),
        ),
        if (pets.length > 1) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pets.length, (index) {
              final isActive = index == activeIndex;
              return AnimatedContainer(
                key: Key('home-pet-dot-$index'),
                duration: const Duration(milliseconds: 160),
                width: isActive ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.text : AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 18),
      ],
    );
  }
}

class _PetProfileCard extends StatelessWidget {
  final Pet pet;

  const _PetProfileCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final details = [
      getDDay(pet.birthDate),
      if (pet.weight != null) _weightLabel(pet.weight),
      if (_compactText(pet.diseases) != null)
        '질병 ${_compactText(pet.diseases)}',
      if (_compactText(pet.specialNotes) != null)
        '특이 ${_compactText(pet.specialNotes)}',
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2A18).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PetProfilePhoto(pet: pet),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  pet.name,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                AppText(
                  pet.species,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final detail in details.take(4))
                      _ProfilePill(label: detail),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetProfilePhoto extends StatelessWidget {
  final Pet pet;

  const _PetProfilePhoto({required this.pet});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AuthenticatedNetworkImage(
        url: pet.profileImageUrl,
        width: 118,
        height: 138,
        fit: BoxFit.cover,
        fallback: _PetEmojiFallback(pet: pet),
      ),
    );
  }
}

class _PetEmojiFallback extends StatelessWidget {
  final Pet pet;

  const _PetEmojiFallback({required this.pet});

  @override
  Widget build(BuildContext context) {
    final color = colorPairForHex(pet.accentColor);
    return Container(
      color: color.bgLight,
      alignment: Alignment.center,
      child: AppText(
        _speciesEmoji(pet.species),
        fontSize: 44,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final String label;

  const _ProfilePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HomeMenuGrid extends StatelessWidget {
  final VoidCallback onScheduleTap;
  final VoidCallback onCategoryTap;

  const _HomeMenuGrid({
    required this.onScheduleTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeMenuItem(
        label: '반려기록',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFFF8A65),
        onTap: () => context.push('/records'),
      ),
      _HomeMenuItem(
        label: '지갑',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF4F8FCF),
        onTap: () => context.push('/wallet'),
      ),
      _HomeMenuItem(
        label: '루틴',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF81C784),
        onTap: () => context.push('/routine'),
      ),
      _HomeMenuItem(
        label: '일정',
        icon: Icons.event_note_rounded,
        color: const Color(0xFF64B5F6),
        onTap: onScheduleTap,
      ),
      _HomeMenuItem(
        label: '성장',
        icon: Icons.show_chart_rounded,
        color: const Color(0xFFBA68C8),
        onTap: () => context.push('/records/growth'),
      ),
      _HomeMenuItem(
        label: '반려로그',
        icon: Icons.category_outlined,
        color: const Color(0xFFE879B9),
        onTap: onCategoryTap,
      ),
      const _HomeMenuItem.empty(),
      const _HomeMenuItem.empty(),
    ];

    return Container(
      key: const Key('home-menu-panel'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _HomeMenuItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isEmpty;

  const _HomeMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : isEmpty = false;

  const _HomeMenuItem.empty()
    : label = '+',
      icon = null,
      color = null,
      onTap = null,
      isEmpty = true;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: isEmpty ? AppColors.surfaceSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEmpty
              ? AppColors.border.withValues(alpha: 0.72)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isEmpty)
            const AppText(
              '+',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.muted,
            )
          else ...[
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppText(
                label,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    if (isEmpty) {
      return Opacity(opacity: 0.62, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _TodayCareSection extends StatelessWidget {
  final List<TodayRoutineItem> items;
  final Map<String, CompletionStatus> completions;
  final List<ActivityRecord> records;
  final void Function(String routineId, String date) onToggle;

  const _TodayCareSection({
    required this.items,
    required this.completions,
    required this.records,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final timeline = _timelineItems(items, records);

    return _HomeSectionCard(
      title: '오늘 관리',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            const _EmptyPanel(
              title: '오늘 예정된 루틴이 없어요',
              message: '루틴을 만들면 오늘 해야 할 관리를 한눈에 볼 수 있어요.',
            )
          else
            ...items.map((item) {
              final routine = item.routine;
              final date = item.completion.scheduledDate;
              final key = '${routine.id}:$date';
              final status = completions[key] ?? item.completion.status;
              final done = status == CompletionStatus.completed;
              return _RoutineChecklistRow(
                item: item,
                isDone: done,
                onTap: () => onToggle(routine.id, date),
              );
            }),
          const SizedBox(height: 14),
          const AppText(
            '오늘 타임라인',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            const _TimelineEmpty()
          else
            ...timeline.map((item) => _TimelineRow(item: item)),
        ],
      ),
    );
  }
}

class _RoutineChecklistRow extends StatelessWidget {
  final TodayRoutineItem item;
  final bool isDone;
  final VoidCallback onTap;

  const _RoutineChecklistRow({
    required this.item,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final routine = item.routine;
    final count = routine.times.isEmpty ? 1 : routine.times.length;
    final title = '${_routineTitle(routine)} · 오늘 $count회 예정';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDone ? AppColors.surfaceSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isDone ? AppColors.primary : AppColors.muted,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    title,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDone ? AppColors.textSecondary : AppColors.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppText(
                  isDone ? '완료' : '예정',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDone ? AppColors.primary : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthSummarySection extends StatelessWidget {
  final List<ActivityRecord> records;

  const _HealthSummarySection({required this.records});

  @override
  Widget build(BuildContext context) {
    final weight = _latestRecord(records, 'weight');
    final poop = _latestRecord(records, 'poop');
    final hasMealToday = _hasRecordToday(records, 'meal');
    final hasMedicineToday = _hasRecordToday(records, 'medicine');
    final hasAnyData =
        weight != null || poop != null || hasMealToday || hasMedicineToday;

    return _HomeSectionCard(
      title: '최근 건강 상태',
      subtitle: hasAnyData ? '최근 기록 기준으로 관리 중이에요' : null,
      child: hasAnyData
          ? Column(
              children: [
                _HealthMetricRow(
                  label: '최신 체중',
                  value: _weightRecordValue(weight) ?? '기록 없음',
                ),
                _HealthMetricRow(
                  label: '최신 배변',
                  value: _poopRecordValue(poop) ?? '기록 없음',
                ),
                _HealthMetricRow(
                  label: '오늘 급식',
                  value: hasMealToday ? '기록됨' : '기록 없음',
                ),
                _HealthMetricRow(
                  label: '오늘 투약',
                  value: hasMedicineToday ? '기록됨' : '기록 없음',
                ),
              ],
            )
          : const _EmptyPanel(
              title: '아직 기록이 부족해요',
              message: '체중, 배변, 급식 기록을 남기면 최근 상태를 보여드릴게요.',
            ),
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _HomeSectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            AppText(subtitle!, fontSize: 12, color: AppColors.textSecondary),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HealthMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _HealthMetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              fontSize: 13,
              color: AppColors.textSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppText(
            value,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyPanel({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 4),
          AppText(message, fontSize: 12, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: AppText(
              '${item.time} ${item.status}',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: item.isRecord ? AppColors.primary : AppColors.muted,
            ),
          ),
          Expanded(
            child: AppText(
              item.title,
              fontSize: 13,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppText(
      '오늘 시간 기록이 아직 없어요',
      fontSize: 12,
      color: AppColors.textSecondary,
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: AppText(
          '반려동물을 등록해 주세요.',
          fontSize: 15,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TimelineItem {
  final String time;
  final String title;
  final String status;
  final bool isRecord;

  const _TimelineItem({
    required this.time,
    required this.title,
    required this.status,
    required this.isRecord,
  });
}

List<_TimelineItem> _timelineItems(
  List<TodayRoutineItem> routineItems,
  List<ActivityRecord> records,
) {
  final today = todayString();
  final items = <_TimelineItem>[];
  for (final item in routineItems) {
    final times = item.routine.times.isEmpty
        ? const ['--:--']
        : item.routine.times;
    for (final time in times) {
      items.add(
        _TimelineItem(
          time: time,
          title: _routineTitle(item.routine),
          status: '예정',
          isRecord: false,
        ),
      );
    }
  }
  for (final record in records.where(
    (record) =>
        record.date == today &&
        record.time != null &&
        const {'medicine', 'vet', 'checkup'}.contains(record.typeId),
  )) {
    items.add(
      _TimelineItem(
        time: record.time!,
        title: _recordTitle(record),
        status: '기록됨',
        isRecord: true,
      ),
    );
  }
  items.sort((a, b) => a.time.compareTo(b.time));
  return items;
}

ActivityRecord? _latestRecord(List<ActivityRecord> records, String typeId) {
  final filtered = records.where((record) => record.typeId == typeId).toList();
  if (filtered.isEmpty) {
    return null;
  }
  filtered.sort((a, b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return (b.time ?? '').compareTo(a.time ?? '');
  });
  return filtered.first;
}

bool _hasRecordToday(List<ActivityRecord> records, String typeId) {
  final today = todayString();
  return records.any(
    (record) => record.typeId == typeId && record.date == today,
  );
}

String _routineTitle(Routine routine) {
  final label = _compactText(routine.label);
  if (label != null) return label;
  return _typeLabel(routine.typeId);
}

String _recordTitle(ActivityRecord record) => _typeLabel(record.typeId);

String _typeLabel(String typeId) {
  const labels = {
    'meal': '급식',
    'water': '음수',
    'walk': '산책',
    'poop': '배변',
    'play': '놀이',
    'sleep': '수면',
    'medicine': '투약',
    'weight': '체중',
    'vet': '병원',
    'checkup': '검진',
    'diary': '일기',
    'bath': '목욕',
    'groom': '미용',
  };
  return labels[typeId] ?? typeId;
}

String? _weightRecordValue(ActivityRecord? record) {
  if (record == null) {
    return null;
  }
  final value = record.detail['value'] ?? record.detail['weight'];
  if (value == null) {
    return null;
  }
  final unit = record.detail['unit']?.toString();
  final normalized = _numberLabel(value);
  return unit == null || unit.isEmpty ? '${normalized}kg' : '$normalized$unit';
}

String? _poopRecordValue(ActivityRecord? record) {
  if (record == null) {
    return null;
  }
  final consistency = record.detail['consistency'];
  return consistency?.toString();
}

String _weightLabel(double? weight) {
  if (weight == null) return '체중 미등록';
  return '${_numberLabel(weight)}kg';
}

String _numberLabel(Object value) {
  final parsed = double.tryParse(value.toString());
  if (parsed == null) {
    return value.toString();
  }
  final rounded = parsed.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}

String? _compactText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _speciesEmoji(String species) {
  final normalized = species.toLowerCase();
  if (normalized.contains('cat') || species.contains('고양')) {
    return '🐱';
  }
  if (normalized.contains('rabbit') || species.contains('토끼')) {
    return '🐰';
  }
  if (normalized.contains('hamster')) {
    return '🐹';
  }
  if (normalized.contains('bird') || species.contains('새')) {
    return '🐦';
  }
  return '🐶';
}
