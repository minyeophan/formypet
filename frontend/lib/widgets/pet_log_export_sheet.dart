import 'package:flutter/material.dart';
import '../core/app_colors.dart';

const petLogExportMuted = Color(0xFF738078);
const petLogExportSecondary = Color(0xFFF3F5F4);

ButtonStyle petLogExportButtonStyle({bool secondary = false}) =>
    FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: secondary ? petLogExportSecondary : AppColors.primary,
      foregroundColor: secondary ? AppColors.text : Colors.white,
      disabledBackgroundColor: petLogExportSecondary,
      disabledForegroundColor: petLogExportMuted,
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.bold,
      ),
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
  barrierColor: const Color(0x61000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 34),
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, secondary == null ? 28 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475C4F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              title,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 18,
                height: title.contains('\n') ? 1.3 : 1.5,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              description,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 13,
                height: 20 / 13,
                color: petLogExportMuted,
              ),
            ),
            const SizedBox(height: 39),
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
                child: FilledButton(
                  style: petLogExportButtonStyle(secondary: true),
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
