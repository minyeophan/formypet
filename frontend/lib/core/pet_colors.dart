import 'package:flutter/material.dart';

class PetColorPair {
  final Color accent;
  final Color bgLight;
  final String accentHex;
  final String bgLightHex;

  const PetColorPair({
    required this.accent,
    required this.bgLight,
    required this.accentHex,
    required this.bgLightHex,
  });
}

// Mirrors RN PET_COLORS array — 5 pairs
const List<PetColorPair> kPetColors = [
  PetColorPair(
    accent: Color(0xFFFF8A65),
    bgLight: Color(0xFFFFF3E0),
    accentHex: '#FF8A65',
    bgLightHex: '#FFF3E0',
  ),
  PetColorPair(
    accent: Color(0xFF81C784),
    bgLight: Color(0xFFE8F5E9),
    accentHex: '#81C784',
    bgLightHex: '#E8F5E9',
  ),
  PetColorPair(
    accent: Color(0xFF64B5F6),
    bgLight: Color(0xFFE3F2FD),
    accentHex: '#64B5F6',
    bgLightHex: '#E3F2FD',
  ),
  PetColorPair(
    accent: Color(0xFFBA68C8),
    bgLight: Color(0xFFF3E5F5),
    accentHex: '#BA68C8',
    bgLightHex: '#F3E5F5',
  ),
  PetColorPair(
    accent: Color(0xFFFFB74D),
    bgLight: Color(0xFFFFF8E1),
    accentHex: '#FFB74D',
    bgLightHex: '#FFF8E1',
  ),
];

Color hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

PetColorPair colorPairForHex(String accentHex) {
  return kPetColors.firstWhere(
    (p) => p.accentHex.toLowerCase() == accentHex.toLowerCase(),
    orElse: () => kPetColors[0],
  );
}
