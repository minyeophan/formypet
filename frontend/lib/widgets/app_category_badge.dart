import 'package:flutter/material.dart';

import '../core/app_v2_tokens.dart';

enum AppBadgeType { category, popular }

class AppCategoryBadge extends StatelessWidget {
  const AppCategoryBadge({super.key, required this.label, this.type = AppBadgeType.category});

  final String label;
  final AppBadgeType type;

  @override
  Widget build(BuildContext context) {
    final strong = type == AppBadgeType.popular;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFE7E9E8) : const Color(0xFFF0F1F0),
        border: Border.all(color: const Color(0xFFE0E3E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: AppV2Tokens.fontFamily, fontSize: 10, fontWeight: FontWeight.w700,
          color: const Color(0xFF37413C))),
    );
  }
}
