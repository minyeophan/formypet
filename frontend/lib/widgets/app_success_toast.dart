import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_fonts.dart';

/// Shows a brief, non-interactive confirmation after a successful action.
/// Keep errors and messages that need a retry in their richer existing UI.
void showAppSuccessToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final media = MediaQuery.maybeOf(context);
  final scale = media?.textScaler.scale(12) ?? 12;
  final available = (media?.size.width ?? 600) - 32;
  final toastWidth = (message.runes.length * scale + 32)
      .clamp(112, available.clamp(112, 568))
      .toDouble();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: null,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontFamily: AppFonts.family,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: toastWidth,
        duration: const Duration(milliseconds: 1600),
        elevation: 2,
        backgroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
}
