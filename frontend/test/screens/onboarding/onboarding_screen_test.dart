import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('first pet onboarding has shared title without back', (
    tester,
  ) async {
    await _pump(tester, PetEntryMode.firstPet);

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.text('반려동물 등록'), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
  });

  testWidgets('additional pet onboarding back dismisses and falls back to my', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/pets/new',
      routes: [
        GoRoute(
          path: '/my',
          builder: (context, state) => const Scaffold(body: Text('my-root')),
        ),
        GoRoute(
          path: '/pets/new',
          builder: (context, state) =>
              const OnboardingScreen(mode: PetEntryMode.additionalPet),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith((ref) => PetNotifier.test(_state())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBackButton), findsOneWidget);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('my-root'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, PetEntryMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
      ],
      child: MaterialApp(home: OnboardingScreen(mode: mode)),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _state() => const PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [
    Pet(
      id: '1',
      name: 'Pet 1',
      species: 'dog',
      birthDate: '2022-03-15',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
  ],
  activePetId: '1',
  records: [],
  routines: [],
  todayRoutineItems: [],
  routineCompletions: {},
  quickTypeIds: [],
);
