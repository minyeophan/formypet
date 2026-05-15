import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/community')) currentIndex = 1;
    if (location.startsWith('/my')) currentIndex = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/community');
            case 2:
              context.go('/my');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined), label: '커뮤니티'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined), label: '마이'),
        ],
      ),
    );
  }
}
