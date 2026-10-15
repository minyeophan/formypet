import 'package:flutter/material.dart';
import '../core/app_colors.dart';

ButtonStyle petLogExportButtonStyle({bool secondary = false}) =>
    FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: secondary ? AppColors.surfaceSoft : AppColors.primary,
      foregroundColor: secondary ? AppColors.text : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

Future<bool?> showPetLogExportSheet(
  BuildContext context, {
  required String title,
  required String description,
  String confirm = '확인',
  String? secondary,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: petLogExportButtonStyle(),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);
