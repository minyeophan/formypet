import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = '뒤로가기',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(Icons.chevron_left_rounded, color: color ?? AppColors.text),
      iconSize: 28,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

class AppDisclosureChevron extends StatelessWidget {
  final double size;
  final Color? color;

  const AppDisclosureChevron({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: size,
      color: color ?? AppColors.muted,
    );
  }
}
