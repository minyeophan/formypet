import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pet_provider.dart';
import '../../core/date_utils.dart';
import '../../core/pet_colors.dart';
import '../../widgets/app_text.dart';
import '../../widgets/record_modal.dart';
import 'pet_selector.dart';
import 'today_routine_card.dart';
import 'recent_records_card.dart';
import 'quick_record_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final pet = state.activePet;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (pet == null) {
      return const Scaffold(body: Center(child: AppText('반려동물을 등록해주세요')));
    }

    final color = colorPairForHex(pet.accentColor);
    final dday = getDDay(pet.birthDate);

    return Scaffold(
      backgroundColor: color.bgLight,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  PetSelector(pets: state.pets, activePetId: state.activePetId),
                  // Hero card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(pet.name,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              const SizedBox(height: 4),
                              AppText(dday,
                                  fontSize: 14, color: Colors.white70),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () => context.push('/pet/${pet.id}/edit'),
                        ),
                      ],
                    ),
                  ),
                  // Quick record
                  QuickRecordRow(
                    quickTypeIds: state.quickTypeIds,
                    onTap: (typeId) => RecordModal.show(context, ref, typeId),
                  ),
                  // Today routines
                  TodayRoutineCard(
                    routines: state.routines,
                    completions: state.routineCompletions,
                    summary: state.todaySummary,
                    today: todayString(),
                    onToggle: (routineId) => ref
                        .read(petProvider.notifier)
                        .toggleRoutineCompletion(routineId, todayString()),
                    onViewAll: () => context.push('/routine'),
                  ),
                  // Recent records
                  RecentRecordsCard(
                    records: state.records,
                    onViewAll: () => context.push('/records'),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
