import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_interaction_style.dart';
import '../widgets/app_ink_well.dart';

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.actionMint,
    primary: AppColors.primary,
    brightness: Brightness.light,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  hoverColor: Colors.transparent,
  splashColor: AppColors.primary.withValues(alpha: .10),
  highlightColor: Colors.transparent,
  textTheme: GoogleFonts.notoSansKrTextTheme(),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: AppColors.primary,
    selectionColor: AppColors.primary.withValues(alpha: 0.25),
    selectionHandleColor: AppColors.primary,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style:
        FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ).copyWith(
          // The existing pressed background already supplies the feedback.
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundBuilder: AppFocusRing.buttonBuilder,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.surfaceSoft;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.muted
                : Colors.white,
          ),
        ),
  ),
  textButtonTheme: TextButtonThemeData(style: _interactionButtonStyle()),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _interactionButtonStyle(),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: _interactionButtonStyle(),
  ),
  iconButtonTheme: IconButtonThemeData(style: _interactionButtonStyle()),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: AppInteractionStyle.inputFill,
    hoverColor: Colors.transparent,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFFE1E5E2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    errorMaxLines: 3,
  ),
  useMaterial3: true,
);

ButtonStyle _interactionButtonStyle() => ButtonStyle(
  overlayColor: AppInteractionStyle.overlay(),
  backgroundBuilder: AppFocusRing.buttonBuilder,
);
