import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_navigation.dart';
import 'app_text.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool centerTitle;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.centerTitle = false,
    this.onBack,
  }) : assert(!showBackButton || onBack != null);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? Align(child: AppBackButton(onPressed: onBack!))
          : null,
      centerTitle: centerTitle,
      title: AppText(
        title,
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
      ),
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      actions: actions,
    );
  }
}

class AppInlineHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const AppInlineHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            key: const Key('app-inline-header-leading-slot'),
            width: 84,
            height: 52,
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
            height: 52,
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

  const AppFormHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
