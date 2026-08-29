import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_navigation.dart';
import 'app_text.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool centerTitle;
  final bool showDivider;
  final VoidCallback? onBack;
  final Widget? leading;
  final Key? titleKey;
  final Key? leadingKey;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.centerTitle = false,
    this.showDivider = false,
    this.onBack,
    this.leading,
    this.titleKey,
    this.leadingKey,
  }) : assert(!showBackButton || onBack != null);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 56,
      leadingWidth: (leading != null || showBackButton) ? 44 : null,
      titleSpacing: (leading != null || showBackButton) ? 0 : null,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: leadingKey == null
          ? (leading ?? (showBackButton
                ? Align(child: AppBackButton(onPressed: onBack!))
                : null))
          : KeyedSubtree(
              key: leadingKey,
              child: leading ?? (showBackButton
                  ? Align(child: AppBackButton(onPressed: onBack!))
                  : const SizedBox.shrink()),
            ),
      centerTitle: centerTitle,
      title: AppText(
        title,
        key: titleKey,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
      ),
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      actions: actions,
      shape: showDivider
          ? const Border(bottom: BorderSide(color: AppColors.border))
          : null,
    );
  }
}

class AppInlineHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool showDivider;

  const AppInlineHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            key: const Key('app-inline-header-leading-slot'),
            width: 84,
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(onPressed: onBack),
            ),
          ),
          Expanded(
            child: AppText(
              title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            key: const Key('app-inline-header-trailing-slot'),
            width: 84,
            height: 56,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class AppFormHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool showDivider;

  const AppFormHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            key: const Key('app-form-header-leading-slot'),
            width: 96,
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(onPressed: onBack),
            ),
          ),
          Expanded(
            child: AppText(
              title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            key: const Key('app-form-header-trailing-slot'),
            width: 96,
            height: 56,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class AppHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
