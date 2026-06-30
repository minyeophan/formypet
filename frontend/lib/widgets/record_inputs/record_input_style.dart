import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class RecordInputStyle {
  const RecordInputStyle._();

  static const sheetMaxHeightFactor = 0.56;
  static const sheetTopRadius = 28.0;
  static const sheetHeaderHeight = 56.0;
  static const sheetHorizontalPadding = 20.0;
  static const pickerItemExtent = 44.0;
  static const numberPadMaxHeight = 360.0;
  static const numberKeyHeight = 54.0;
  static const numberKeySpacing = 8.0;
  static const barrierColor = Color(0x66000000);

  static const surfaceColor = AppColors.surface;
  static const surfaceSoftColor = AppColors.surfaceSoft;
  static const borderColor = AppColors.border;
  static const textColor = AppColors.text;
  static const textSecondaryColor = AppColors.textSecondary;
  static const mutedColor = AppColors.muted;
  static const accentColor = AppColors.primaryPressed;

  static BorderRadius get sheetBorderRadius =>
      const BorderRadius.vertical(top: Radius.circular(sheetTopRadius));

  static ButtonStyle get headerButtonStyle => TextButton.styleFrom(
    foregroundColor: accentColor,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}
