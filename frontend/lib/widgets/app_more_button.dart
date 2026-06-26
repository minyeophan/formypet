import 'package:flutter/material.dart';

import '../core/app_colors.dart';

enum _AppMoreButtonVariant { surface, plain }

class AppMoreButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final _AppMoreButtonVariant _variant;

  const AppMoreButton.surface({super.key, this.tooltip = '더보기', this.onPressed})
    : _variant = _AppMoreButtonVariant.surface;

  const AppMoreButton.plain({super.key, this.tooltip = '더보기', this.onPressed})
    : _variant = _AppMoreButtonVariant.plain;

  @override
  Widget build(BuildContext context) {
    final isSurface = _variant == _AppMoreButtonVariant.surface;
    final size = isSurface ? 38.0 : 44.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isSurface ? 14 : 22),
          child: Container(
            width: size,
            height: size,
            decoration: isSurface
                ? BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  )
                : null,
            alignment: Alignment.center,
            child: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
