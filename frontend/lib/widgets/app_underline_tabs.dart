import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AppUnderlineTabs extends StatelessWidget {
  const AppUnderlineTabs({super.key, required this.items, required this.selectedIndex, required this.onChanged});
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 24),
      itemBuilder: (_, index) => InkWell(
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: index == selectedIndex ? AppColors.primary : Colors.transparent, width: 2))),
          alignment: Alignment.center,
          child: Text(items[index], style: TextStyle(color: index == selectedIndex ? AppColors.text : AppColors.textSecondary, fontWeight: index == selectedIndex ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    ),
  );
}
