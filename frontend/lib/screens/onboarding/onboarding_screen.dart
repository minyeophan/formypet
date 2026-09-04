import 'package:flutter/material.dart';
import '../pet/pet_profile_form.dart';

enum PetEntryMode { firstPet, additionalPet }

class OnboardingScreen extends StatelessWidget {
  final PetEntryMode mode;
  const OnboardingScreen({super.key, this.mode = PetEntryMode.firstPet});
  @override
  Widget build(BuildContext context) =>
      PetProfileForm(firstPet: mode == PetEntryMode.firstPet);
}
