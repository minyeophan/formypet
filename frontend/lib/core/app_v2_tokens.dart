import 'package:flutter/material.dart';

abstract final class AppV2Tokens {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF5F6F5);
  static const mintSurface = Color(0xFFEAF7F0);
  static const mintBorder = Color(0xFFE1E5E2);
  static const primary = Color(0xFF32B982);
  static const primaryPressed = Color(0xFF249A6D);
  // Backward-compatible name used by existing selected-state and splash styles.
  static const primarySoft = mintSurface;
  static const text = Color(0xFF151C27);
  static const textSecondary = Color(0xFF3C4A42);
  static const border = mintBorder;
  static const error = Color(0xFFBA1A1A);
  static const gutter = 20.0;
  static const fontFamily = 'PlusJakartaSans';
}
