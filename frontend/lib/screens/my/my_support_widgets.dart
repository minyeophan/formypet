import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';

void goBackOrFallback(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallbackRoute);
}

class MySupportLead extends StatelessWidget {
  final String text;

  const MySupportLead(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return AppText(text, fontSize: 13, color: AppColors.textSecondary);
  }
}

class MySupportSectionTitle extends StatelessWidget {
  final String title;

  const MySupportSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF41B883),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF41B883).withValues(alpha: 0.14),
                spreadRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        AppText(
          title,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ],
    );
  }
}

class MySupportCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const MySupportCard({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class MySupportRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool showTopBorder;
  final String? iconLabel;

  const MySupportRow({
    super.key,
    required this.title,
    required this.onTap,
    this.showTopBorder = false,
    this.iconLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: showTopBorder
                ? const Border(top: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              if (iconLabel != null) ...[
                _TextIconTile(label: iconLabel!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppText(
                  title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const AppDisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class MySupportArticleCard extends StatelessWidget {
  final String title;
  final String meta;
  final String body;

  const MySupportArticleCard({
    super.key,
    required this.title,
    required this.meta,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2A18).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 8),
          AppText(
            meta,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.muted,
          ),
          const SizedBox(height: 16),
          AppText(body, fontSize: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class MySupportNotFound extends StatelessWidget {
  final String message;

  const MySupportNotFound(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppText(
        message,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TextIconTile extends StatelessWidget {
  final String label;

  const _TextIconTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: AppText(
            label,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
