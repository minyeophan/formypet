import 'package:flutter/material.dart';
import 'pet_profile_form.dart';

class PetEditScreen extends StatelessWidget {
  final String petId;
  const PetEditScreen({super.key, required this.petId});
  @override
  Widget build(BuildContext context) => PetProfileForm(petId: petId);
}
