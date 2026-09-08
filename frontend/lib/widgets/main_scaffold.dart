import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/keyboard_utils.dart';
import '../core/visuals/app_visual_id.dart';
import 'app_visual.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    var currentIndex = 0;
    if (location.startsWith('/community')) currentIndex = 1;
    if (location.startsWith('/my')) currentIndex = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.muted,
          elevation: 0,
          onTap: (i) async {
            await dismissKeyboardBeforeTransition(context);
            if (!context.mounted) return;

            switch (i) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/community');
              case 2:
                context.go('/my');
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: AppVisual(
                id: AppVisualId.navHome,
                size: 24,
                color: currentIndex == 0 ? AppColors.primary : AppColors.muted,
              ),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: AppVisual(
                id: AppVisualId.navCommunity,
                size: 24,
                color: currentIndex == 1 ? AppColors.primary : AppColors.muted,
              ),
              label: '커뮤니티',
            ),
            BottomNavigationBarItem(
              icon: AppVisual(
                id: AppVisualId.navMy,
                size: 24,
                color: currentIndex == 2 ? AppColors.primary : AppColors.muted,
              ),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
