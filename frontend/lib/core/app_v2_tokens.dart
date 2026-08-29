import 'package:flutter/material.dart';

abstract final class AppV2Tokens {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF3FBF7);
  static const mintSurface = Color(0xFFE7F8F0);
  static const mintBorder = Color(0xFFE1E9E5);
  static const primary = Color(0xFF006C49);
  static const primaryPressed = Color(0xFF00563A);
  // Backward-compatible name used by existing selected-state and splash styles.
  static const primarySoft = mintSurface;
  static const text = Color(0xFF151C27);
  static const textSecondary = Color(0xFF3C4A42);
  static const border = mintBorder;
  static const error = Color(0xFFBA1A1A);
  static const gutter = 20.0;
  static const fontFamily = 'PlusJakartaSans';
}
