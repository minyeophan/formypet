import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'my_widgets.dart';

class MyPetsScreen extends ConsumerWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '나의 반려동물',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.pets.isEmpty
          ? const Center(
              child: AppText('등록된 펫이 없어요', color: AppColors.textSecondary),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              itemCount: state.pets.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == state.pets.length) {
                  return OutlinedButton.icon(
                    onPressed: () => context.push('/pets/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: const AppText('펫 추가하기'),
                  );
                }
                final pet = state.pets[index];
                return MyPetCard(
                  pet: pet,
                  isActive: state.activePetId == pet.id,
                );
              },
            ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/my');
}
