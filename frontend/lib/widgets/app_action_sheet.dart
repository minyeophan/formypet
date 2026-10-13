import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_v2_tokens.dart';
import 'app_ink_well.dart';
import 'app_icon.dart';
import 'app_text.dart';

enum AppActionSheetButtonStyle { standard, primary, destructive, secondary }

enum AppActionSheetPresentation { standard, compactMenu }

class AppActionSheetItem {
  final Key? key;
  final String label;
  final String? description;
  final IconData? icon;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool destructive;
  final bool accented;
  final AppActionSheetButtonStyle buttonStyle;

  const AppActionSheetItem({
    this.key,
    required this.label,
    this.description,
    this.icon,
    this.showChevron = false,
    this.onTap,
    this.destructive = false,
    this.accented = false,
    this.buttonStyle = AppActionSheetButtonStyle.standard,
  });
}

Future<void> showAppActionSheet(
  BuildContext context, {
  String? title,
  required List<AppActionSheetItem> actions,
  String? closeLabel = '닫기',
  AppActionSheetPresentation presentation = AppActionSheetPresentation.standard,
}) {
  FocusScope.of(context).unfocus();
  final compactMenu = presentation == AppActionSheetPresentation.compactMenu;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: !compactMenu,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: compactMenu
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                key: const Key('app-action-sheet-compact-menu'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (var index = 0; index < actions.length; index++) ...[
                    _buildActionButton(
                      sheetContext,
                      actions[index],
                      compactMenu: true,
                    ),
                    if (index < actions.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(title, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                  ],
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildActionButton(sheetContext, action),
                    ),
                  if (closeLabel != null) ...[
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),
                    _ActionButton(
                      key: const Key('app-action-sheet-close'),
                      label: closeLabel,
                      buttonStyle: AppActionSheetButtonStyle.secondary,
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}

Widget _buildActionButton(
  BuildContext context,
  AppActionSheetItem action, {
  bool compactMenu = false,
}) => _ActionButton(
  key: action.key,
  label: action.label,
  description: action.description,
  icon: action.icon,
  showChevron: action.showChevron,
  destructive: action.destructive,
  accented: action.accented,
  buttonStyle: action.buttonStyle,
  compactMenu: compactMenu,
  compactHeight: action.buttonStyle == AppActionSheetButtonStyle.secondary
      ? 46
      : 50,
  onTap: () {
    Navigator.of(context).pop();
    action.onTap?.call();
  },
);

class _ActionButton extends StatelessWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final bool showChevron;
  final bool destructive;
  final bool accented;
  final AppActionSheetButtonStyle buttonStyle;
  final bool compactMenu;
  final double compactHeight;
  final VoidCallback onTap;

  const _ActionButton({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.showChevron = false,
    required this.onTap,
    this.destructive = false,
    this.accented = false,
    this.buttonStyle = AppActionSheetButtonStyle.standard,
    this.compactMenu = false,
    this.compactHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    final background = switch (buttonStyle) {
      AppActionSheetButtonStyle.primary => AppColors.primary,
      AppActionSheetButtonStyle.destructive => AppColors.danger,
      AppActionSheetButtonStyle.secondary => AppColors.surfaceSoft,
      AppActionSheetButtonStyle.standard =>
        destructive
            ? AppColors.dangerSoft
            : accented
            ? AppV2Tokens.mintSurface
            : AppColors.surfaceSoft,
    };
    final border = switch (buttonStyle) {
      AppActionSheetButtonStyle.primary => AppColors.primary,
      AppActionSheetButtonStyle.destructive => AppColors.danger,
      AppActionSheetButtonStyle.secondary => AppColors.border,
      AppActionSheetButtonStyle.standard =>
        destructive
            ? AppColors.dangerBorder
            : accented
            ? AppColors.primary.withValues(alpha: .24)
            : AppColors.border,
    };
    final foreground = switch (buttonStyle) {
      AppActionSheetButtonStyle.primary => AppColors.onPrimary,
      AppActionSheetButtonStyle.destructive => AppColors.white,
      AppActionSheetButtonStyle.secondary => AppColors.textSecondary,
      AppActionSheetButtonStyle.standard =>
        destructive
            ? AppColors.danger
            : accented
            ? AppColors.actionMint
            : AppColors.textSecondary,
    };
    final isDestructive =
        destructive || buttonStyle == AppActionSheetButtonStyle.destructive;
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: (isDestructive ? AppColors.danger : AppColors.primary)
            .withValues(alpha: .10),
      ),
      child: AppFocusIndicator(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            hoverColor: Colors.transparent,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: compactMenu ? compactHeight : null,
              alignment: compactMenu ? Alignment.center : null,
              constraints: compactMenu
                  ? null
                  : BoxConstraints(
                      minHeight: description == null
                          ? switch (buttonStyle) {
                              AppActionSheetButtonStyle.primary ||
                              AppActionSheetButtonStyle.destructive => 52,
                              _ => 48,
                            }
                          : 64,
                    ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              padding: compactMenu
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: icon == null && description == null && !showChevron
                  ? AppText(
                      label,
                      color: foreground,
                      textAlign: TextAlign.center,
                    )
                  : Row(
                      children: [
                        if (icon != null) ...[
                          AppIcon(icon, size: 24, color: foreground),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                label,
                                color: accented ? AppColors.text : foreground,
                                fontWeight: FontWeight.w600,
                              ),
                              if (description != null) ...[
                                const SizedBox(height: 2),
                                AppText(
                                  description!,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showChevron) ...[
                          const SizedBox(width: 8),
                          const AppIcon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
