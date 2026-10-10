import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_icon.dart';

class DefaultProfileAvatar extends StatelessWidget {
  const DefaultProfileAvatar({
    super.key,
    required this.size,
    this.backgroundColor = AppColors.surfaceSoft,
    this.iconColor = AppColors.textSecondary,
  });

  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Center(
        child: AppIcon(
          Icons.person_outline_rounded,
          size: size * 0.4375,
          color: iconColor,
        ),
      ),
    ),
  );
}
