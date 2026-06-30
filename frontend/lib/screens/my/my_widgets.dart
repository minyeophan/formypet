import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/pet_taxonomy.dart';
import '../../models/pet.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';

class MyMenuCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool danger;

  const MyMenuCard({
    super.key,
    required this.title,
    required this.children,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: danger ? AppColors.dangerBorder : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: AppText(
              title,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: danger ? AppColors.danger : AppColors.text,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class MyMenuRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool showTopBorder;
  final Widget? trailing;

  const MyMenuRow({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.danger = false,
    this.showTopBorder = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: showTopBorder
                ? Border(
                    top: BorderSide(
                      color: danger ? AppColors.dangerBorder : AppColors.border,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  label,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              trailing ?? const AppDisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class MyPetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback? onTap;
  final bool isActive;

  const MyPetCard({
    super.key,
    required this.pet,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap ?? () => context.push('/pet/${pet.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AuthenticatedNetworkImage(
                  url: pet.profileImageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: AppColors.surfaceSoft,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.pets_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      pet.name,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      speciesLabel(pet.species),
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const AppText(
                    '현재 선택',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
