import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_text.dart';

void showPreparingToast(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Center(
          widthFactor: 1,
          child: AppText(
            '준비중',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: 112,
        elevation: 0,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
}
