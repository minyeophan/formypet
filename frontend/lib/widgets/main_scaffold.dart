import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/keyboard_utils.dart';
import '../core/visuals/app_visual_id.dart';
import 'app_visual.dart';
import 'app_ink_well.dart';
import 'draft_exit_guard.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _draftExit = DraftExitController();
  bool _switchingTab = false;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    var currentIndex = 0;
    if (location.startsWith('/community')) currentIndex = 1;
    if (location.startsWith('/my')) currentIndex = 2;

    return Scaffold(
      body: DraftExitScope(controller: _draftExit, child: widget.child),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: AppColors.primary.withValues(alpha: .10),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.muted,
            elevation: 0,
            onTap: (i) async {
              if (_switchingTab) return;
              final target = const ['/home', '/community', '/my'][i];
              if (location == target) return;
              final router = GoRouter.of(context);
              final originalRoute = router.routeInformationProvider.value;
              bool routeUnchanged() =>
                  mounted &&
                  identical(
                    router.routeInformationProvider.value,
                    originalRoute,
                  );
              _switchingTab = true;
              var navigated = false;
              try {
                if (!await _draftExit.confirmExit() ||
                    !routeUnchanged() ||
                    !context.mounted) {
                  return;
                }
                await dismissKeyboardBeforeTransition(context);
                if (!routeUnchanged()) return;
                router.go(target);
                navigated = true;
              } finally {
                if (!navigated) _draftExit.cancelExit();
                _switchingTab = false;
              }
            },
            items: [
              BottomNavigationBarItem(
                icon: _NavigationIcon(
                  id: AppVisualId.navHome,
                  size: 24,
                  color: currentIndex == 0
                      ? AppColors.primary
                      : AppColors.muted,
                ),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: _NavigationIcon(
                  id: AppVisualId.navCommunity,
                  size: 24,
                  color: currentIndex == 1
                      ? AppColors.primary
                      : AppColors.muted,
                ),
                label: '커뮤니티',
              ),
              BottomNavigationBarItem(
                icon: _NavigationIcon(
                  id: AppVisualId.navMy,
                  size: 24,
                  color: currentIndex == 2
                      ? AppColors.primary
                      : AppColors.muted,
                ),
                label: '마이',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses the BottomNavigationBar's existing InkResponse focus node. The ring
/// overflows the icon without changing its layout or adding a traversal stop.
class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.id,
    required this.size,
    required this.color,
  });

  final AppVisualId id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      AppVisual(id: id, size: size, color: color),
      Positioned(
        top: -4,
        bottom: -4,
        left: -4,
        right: -4,
        child: IgnorePointer(
          child: AppFocusRing(
            focused: Focus.of(context).hasPrimaryFocus,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}
