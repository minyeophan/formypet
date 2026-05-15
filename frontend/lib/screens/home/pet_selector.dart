import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../core/pet_colors.dart';
import '../../widgets/app_text.dart';

class PetSelector extends ConsumerWidget {
  final List<Pet> pets;
  final String? activePetId;

  const PetSelector({super.key, required this.pets, required this.activePetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: pets.length,
        itemBuilder: (_, i) {
          final pet = pets[i];
          final isActive = pet.id == activePetId;
          final color = colorPairForHex(pet.accentColor);
          return GestureDetector(
            onTap: () =>
                ref.read(petProvider.notifier).setActivePet(pet.id),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color.accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: color.accent, width: isActive ? 0 : 1),
              ),
              child: AppText(
                pet.name,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : color.accent,
              ),
            ),
          );
        },
      ),
    );
  }
}
