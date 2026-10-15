import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_fonts.dart';

/// Shows a brief, non-interactive confirmation after a successful action.
/// Keep errors and messages that need a retry in their richer existing UI.
void showAppSuccessToast(
  BuildContext context,
  String message, {
  double? bottomOffset,
}) {
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
          style: TextStyle(
            color: AppColors.text,
            fontFamily: AppFonts.family,
            fontSize: bottomOffset == null ? 12 : 13,
            height: bottomOffset == null ? null : 20 / 13,
            fontWeight: bottomOffset == null
                ? FontWeight.w500
                : FontWeight.w400,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: bottomOffset == null ? toastWidth : null,
        margin: bottomOffset == null
            ? null
            : EdgeInsets.fromLTRB(
                ((media?.size.width ?? 390) - 124) / 2,
                0,
                ((media?.size.width ?? 390) - 124) / 2,
                bottomOffset,
              ),
        duration: const Duration(milliseconds: 1600),
        elevation: bottomOffset == null ? 2 : 0,
        backgroundColor: AppColors.surface,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: bottomOffset == null ? 8 : 7,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(bottomOffset == null ? 12 : 17),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
}
