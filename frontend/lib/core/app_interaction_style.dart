import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppInputAccess { editable, picker, readOnly, disabled }

/// Shared state colors. A read-only TextField can still be an editable picker.
abstract final class AppInteractionStyle {
  static const inputFill = _InputFillColor();

  static Color inputFillFor(AppInputAccess access, {bool enabled = true}) {
    if (!enabled ||
        access == AppInputAccess.disabled ||
        access == AppInputAccess.readOnly) {
      return AppColors.surfaceSoft;
    }
    return inputFill;
  }

  static BorderSide selectionBorder(bool selected) => BorderSide(
    color: selected ? AppColors.primary : AppColors.border,
    width: 1.5,
  );

  static WidgetStateProperty<Color?> overlay({bool danger = false}) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return (danger ? AppColors.danger : AppColors.primary).withValues(
            alpha: .10,
          );
        }
        // Returning null here would restore Material's default grey overlay.
        return Colors.transparent;
      });
}

class _InputFillColor extends WidgetStateColor {
  const _InputFillColor() : super(0xFFFFFFFF);

  @override
  Color resolve(Set<WidgetState> states) =>
      states.contains(WidgetState.disabled)
      ? AppColors.surfaceSoft
      : AppColors.white;
}
