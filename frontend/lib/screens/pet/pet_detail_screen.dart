import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/pet_provider.dart';
import '../../core/date_utils.dart';
import '../../core/record_utils.dart';
import '../../core/pet_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';

class PetDetailScreen extends ConsumerWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final pet = state.pets.where((p) => p.id == petId).firstOrNull;
    final appBar = AppHeader(
      title: pet?.name ?? '반려동물 상세',
      showBackButton: true,
      centerTitle: true,
      onBack: () => _goBackToMy(context),
      actions: pet == null
          ? null
          : [
              AppHeaderIconButton(
                icon: Icons.edit_outlined,
                tooltip: '수정',
                onTap: () => context.push('/pet/${pet.id}/edit'),
              ),
            ],
    );

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (pet == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const Center(child: AppText('반려동물을 찾을 수 없습니다')),
      );
    }

    final color = colorPairForHex(pet.accentColor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.bgLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: color.accent,
                    child: AppText(
                      pet.name[0],
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppText(pet.name, fontSize: 20, fontWeight: FontWeight.bold),
                  AppText(
                    getDDay(pet.birthDate),
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoTile('종류', speciesLabel(pet.species)),
            _InfoTile('생년월일', pet.birthDate),
            if (pet.gender != null)
              _InfoTile('성별', pet.gender == 'male' ? '남아' : '여아'),
            if (pet.weight != null) _InfoTile('체중', '${pet.weight} kg'),
            if (pet.neutered != null)
              _InfoTile('중성화', pet.neutered! ? '완료' : '미완료'),
            if (pet.animalRegistrationNumber != null)
              _InfoTile('동물등록번호', pet.animalRegistrationNumber!),
            if (pet.diseases != null && pet.diseases!.isNotEmpty)
              _InfoTile('질병', pet.diseases!),
            if (pet.specialNotes != null && pet.specialNotes!.isNotEmpty)
              _InfoTile('특이사항', pet.specialNotes!),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const AppText('반려동물 삭제'),
                    content: AppText('${pet.name}을(를) 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const AppText('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const AppText('삭제', color: Colors.red),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(petProvider.notifier).deletePet(petId);
                  if (!context.mounted) return;
                  if (!ref.read(petProvider).hasOnboarded) return;
                  _goBackToMy(context);
                }
              },
              child: const AppText('삭제', color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

void _goBackToMy(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/my');
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: AppText(label, color: Colors.grey, fontSize: 13),
          ),
          Expanded(child: AppText(value, fontSize: 14)),
        ],
      ),
    );
  }
}
